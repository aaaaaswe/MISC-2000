// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 Atomic Instruction Support — LL.D, SC.D, CAS.D (opcodes 0x040, 0x041, 0x144–0x148), FENCE (0x15E).
// State: IDLE → READ → CHECK_MONITOR → WRITE → DONE.
// LL sets 64-byte aligned monitor; SC succeeds only if monitor_valid; CAS compares and swaps.

module misc_atomic #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 64
) (
    // ---- Clock & Reset ------------------------------------------------
    input  logic                         clk_i,
    input  logic                         rst_n_i,

    // ---- Instruction decode inputs ------------------------------------
    input  logic [10:0]                  opcode_i,
    input  logic [4:0]                   rd_addr_i,
    input  logic [4:0]                   rs1_addr_i,
    input  logic [4:0]                   rs2_addr_i,
    input  logic [4:0]                   rs3_addr_i,
    input  logic [DATA_WIDTH-1:0]        rs1_data_i,
    input  logic [DATA_WIDTH-1:0]        rs2_data_i,
    input  logic [DATA_WIDTH-1:0]        rs3_data_i,
    input  logic [ADDR_WIDTH-1:0]        inst_addr_i,
    input  logic                         instr_valid_i,

    // ---- Memory interface (to LSU) ------------------------------------
    output logic [ADDR_WIDTH-1:0]        mem_addr_o,
    output logic [DATA_WIDTH-1:0]        mem_wdata_o,
    output logic                         mem_read_o,
    output logic                         mem_write_o,
    input  logic [DATA_WIDTH-1:0]        mem_rdata_i,
    input  logic                         mem_ready_i,
    input  logic                         mem_page_fault_i,

    // ---- Monitor interface (to CSR) -----------------------------------
    output logic                         ll_exec_o,
    output logic [ADDR_WIDTH-1:0]        ll_addr_o,
    output logic                         sc_exec_o,
    input  logic                         sc_success_i,
    input  logic                         monitor_clear_i,

    // ---- Exception interface ------------------------------------------
    output logic                         exception_o,
    output logic [ADDR_WIDTH-1:0]        exception_addr_o,

    // ---- Result interface ---------------------------------------------
    output logic [DATA_WIDTH-1:0]        result_o,
    output logic                         result_valid_o,
    output logic                         busy_o,

    // ---- FENCE interface ----------------------------------------------
    output logic                         fence_exec_o
);

    // =========================================================================
    // Opcode definitions
    // =========================================================================
    localparam logic [10:0] OP_LL_D      = 11'h040;
    localparam logic [10:0] OP_SC_D      = 11'h041;
    localparam logic [10:0] OP_CAS_IMM   = 11'h144;
    localparam logic [10:0] OP_CAS_REG   = 11'h145;
    localparam logic [10:0] OP_CAS_DIR   = 11'h146;
    localparam logic [10:0] OP_CAS_IDX   = 11'h147;
    localparam logic [10:0] OP_CAS_STK   = 11'h148;
    localparam logic [10:0] OP_FENCE     = 11'h15E;

    // =========================================================================
    // State machine definitions
    // =========================================================================
    typedef enum logic [2:0] {
        STATE_IDLE          = 3'd0,
        STATE_READ          = 3'd1,
        STATE_CHECK_MONITOR = 3'd2,
        STATE_WRITE         = 3'd3,
        STATE_DONE          = 3'd4
    } state_t;

    state_t state_q, state_d;

    // =========================================================================
    // Instruction type decoding
    // =========================================================================
    logic is_ll;
    logic is_sc;
    logic is_cas;
    logic is_fence;
    logic is_atomic;

    assign is_ll    = (opcode_i == OP_LL_D);
    assign is_sc    = (opcode_i == OP_SC_D);
    assign is_cas   = (opcode_i == OP_CAS_IMM) ||
                      (opcode_i == OP_CAS_REG) ||
                      (opcode_i == OP_CAS_DIR) ||
                      (opcode_i == OP_CAS_IDX) ||
                      (opcode_i == OP_CAS_STK);
    assign is_fence = (opcode_i == OP_FENCE);
    assign is_atomic = is_ll || is_sc || is_cas || is_fence;

    // =========================================================================
    // Cross-page detection
    //   All atomic instructions are 4-byte fixed-length.
    //   Cross-page condition: (inst_addr_i[11:0] + 4) > 4095
    //   Use 13-bit addition to avoid overflow
    // =========================================================================
    logic cross_page;

    assign cross_page = ({1'b0, inst_addr_i[11:0]} + 13'd4) > 13'h1000;

    // =========================================================================
    // Internal registers
    // =========================================================================
    logic [DATA_WIDTH-1:0]   read_data_q;      // data read from memory (LL / CAS)
    logic [ADDR_WIDTH-1:0]   addr_q;           // latched memory address
    logic [DATA_WIDTH-1:0]   wdata_q;          // latched write data (SC)
    logic [DATA_WIDTH-1:0]   cas_new_val_q;    // latched new value for CAS
    logic                    is_ll_q;          // current operation is LL
    logic                    is_sc_q;          // current operation is SC
    logic                    is_cas_q;         // current operation is CAS
    logic [DATA_WIDTH-1:0]   result_q;         // latched result
    logic                    result_valid_q;   // latched result valid
    logic                    exception_q;      // latched exception flag
    logic [ADDR_WIDTH-1:0]   exception_addr_q; // latched exception address

    // =========================================================================
    // State machine — sequential
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_q          <= STATE_IDLE;
            read_data_q      <= {DATA_WIDTH{1'b0}};
            addr_q           <= {ADDR_WIDTH{1'b0}};
            wdata_q          <= {DATA_WIDTH{1'b0}};
            cas_new_val_q    <= {DATA_WIDTH{1'b0}};
            is_ll_q          <= 1'b0;
            is_sc_q          <= 1'b0;
            is_cas_q         <= 1'b0;
            result_q         <= {DATA_WIDTH{1'b0}};
            result_valid_q   <= 1'b0;
            exception_q      <= 1'b0;
            exception_addr_q <= {ADDR_WIDTH{1'b0}};
        end else begin
            state_q          <= state_d;
            result_valid_q   <= (state_d == STATE_DONE);

            if (state_q == STATE_IDLE && instr_valid_i && is_atomic && !is_fence && !cross_page) begin
                addr_q     <= rs1_data_i[ADDR_WIDTH-1:0];
                wdata_q    <= rs2_data_i;
                if (is_cas) begin
                    cas_new_val_q <= rs3_data_i;
                end
                is_ll_q    <= is_ll;
                is_sc_q    <= is_sc;
                is_cas_q   <= is_cas;
            end

            if (state_q == STATE_READ && mem_ready_i && !mem_page_fault_i) begin
                read_data_q <= mem_rdata_i;
            end

            // Latch exception and result when entering DONE state
            if (state_d == STATE_DONE) begin
                if (state_q == STATE_IDLE && cross_page) begin
                    exception_q      <= 1'b1;
                    exception_addr_q <= inst_addr_i;
                end else if (state_q == STATE_READ && mem_page_fault_i) begin
                    exception_q      <= 1'b1;
                    exception_addr_q <= addr_q;
                end else if (state_q == STATE_WRITE && mem_page_fault_i) begin
                    exception_q      <= 1'b1;
                    exception_addr_q <= addr_q;
                end else begin
                    exception_q      <= 1'b0;
                end
            end else begin
                exception_q      <= 1'b0;
                exception_addr_q <= {ADDR_WIDTH{1'b0}};
            end

            // Latch result when entering DONE state
            if (state_d == STATE_DONE) begin
                if (state_q == STATE_READ && is_ll_q && mem_ready_i && !mem_page_fault_i) begin
                    result_q <= mem_rdata_i;
                end else if (state_q == STATE_READ && is_cas_q && mem_ready_i && !mem_page_fault_i && (mem_rdata_i != wdata_q)) begin
                    result_q <= mem_rdata_i;
                end else if (state_q == STATE_CHECK_MONITOR && !sc_success_i) begin
                    result_q <= {{(DATA_WIDTH-1){1'b0}}, 1'b1};
                end else if (state_q == STATE_WRITE && mem_ready_i && !mem_page_fault_i) begin
                    if (is_sc_q)
                        result_q <= {DATA_WIDTH{1'b0}};
                    else if (is_cas_q)
                        result_q <= read_data_q;
                end
            end
        end
    end

    // =========================================================================
    // State machine — combinatorial next-state and outputs
    // =========================================================================
    always_comb begin
        // Default outputs
        state_d           = state_q;
        mem_addr_o        = addr_q;
        mem_wdata_o       = wdata_q;
        mem_read_o        = 1'b0;
        mem_write_o       = 1'b0;
        ll_exec_o         = 1'b0;
        ll_addr_o         = {ADDR_WIDTH{1'b0}};
        sc_exec_o         = 1'b0;
        exception_o       = exception_q;
        exception_addr_o  = exception_addr_q;
        result_o          = result_q;
        result_valid_o    = result_valid_q;
        busy_o            = 1'b0;
        fence_exec_o      = 1'b0;

        // ----- Main state machine -----------------------------------------
        unique case (state_q)

            // ===============================================================
            // IDLE — wait for valid atomic instruction
            // ===============================================================
            STATE_IDLE: begin
                if (instr_valid_i && is_atomic) begin
                    if (cross_page) begin
                        state_d = STATE_DONE;
                    end else if (is_fence) begin
                        fence_exec_o = 1'b1;
                        state_d = STATE_DONE;
                    end else if (is_ll || is_cas) begin
                        mem_addr_o = rs1_data_i[ADDR_WIDTH-1:0];
                        mem_read_o = 1'b1;
                        state_d    = STATE_READ;
                    end else if (is_sc) begin
                        state_d    = STATE_CHECK_MONITOR;
                    end
                end
            end

            // ===============================================================
            // READ — issue memory read and wait for response
            // ===============================================================
            STATE_READ: begin
                busy_o     = 1'b1;
                mem_read_o = 1'b1;

                if (mem_ready_i) begin
                    mem_read_o = 1'b0;
                    if (mem_page_fault_i) begin
                        state_d = STATE_DONE;
                    end else begin
                        if (is_ll_q) begin
                            ll_exec_o = 1'b1;
                            ll_addr_o = addr_q;
                            state_d   = STATE_DONE;
                        end else if (is_cas_q) begin
                            if (mem_rdata_i == wdata_q) begin
                                mem_wdata_o = wdata_q;
                                mem_write_o = 1'b1;
                                state_d     = STATE_WRITE;
                            end else begin
                                state_d = STATE_DONE;
                            end
                        end else begin
                            state_d = STATE_IDLE;
                        end
                    end
                end
            end

            // ===============================================================
            // CHECK_MONITOR — check if exclusive monitor is still valid (SC)
            // ===============================================================
            STATE_CHECK_MONITOR: begin
                busy_o    = 1'b1;
                sc_exec_o = 1'b1;

                if (sc_success_i) begin
                    mem_wdata_o = wdata_q;
                    mem_write_o = 1'b1;
                    state_d     = STATE_WRITE;
                end else begin
                    state_d = STATE_DONE;
                end
            end

            // ===============================================================
            // WRITE — issue memory write and wait for response
            // ===============================================================
            STATE_WRITE: begin
                busy_o      = 1'b1;
                mem_write_o = 1'b1;

                if (mem_ready_i) begin
                    mem_write_o = 1'b0;
                    if (mem_page_fault_i) begin
                        state_d = STATE_DONE;
                    end else begin
                        state_d = STATE_DONE;
                    end
                end
            end

            // ===============================================================
            // DONE — output result valid for one cycle, then return to IDLE
            // ===============================================================
            STATE_DONE: begin
                state_d = STATE_IDLE;
            end

            default: begin
                state_d = STATE_IDLE;
            end

        endcase
    end

    // =========================================================================
    // Assertions (synthesis off) — simplified for broader tool compatibility
    // =========================================================================
    // synthesis translate_off
    `ifndef SYNTHESIS
    // Check that we don't drive read and write simultaneously
    always_comb begin
        if (rst_n_i && mem_read_o && mem_write_o) begin
            $display("ERROR: Atomic: mem_read_o and mem_write_o both asserted at time %0t", $time);
        end
    end
    `endif
    // synthesis translate_on

endmodule
