// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 Instruction Fetch Unit — variable-length CISC (2/4/6/8 bytes by bit[7:6]).
// Reads in 2-byte chunks; cross-page faults report instruction start address.
// Atomic opcodes 0x144–0x148 are 4-byte fixed-length and must not cross pages.

module misc_ifu #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 64
) (
    // ---- Clock & Reset ------------------------------------------------
    input  logic                     clk_i,
    input  logic                     rst_n_i,

    // ---- Pipeline control ---------------------------------------------
    input  logic                     stall_i,
    input  logic                     flush_i,

    // ---- Next-PC / Branch interface -----------------------------------
    input  logic [ADDR_WIDTH-1:0]   pc_i,
    input  logic                     branch_taken_i,
    input  logic [ADDR_WIDTH-1:0]   branch_target_i,

    // ---- Memory read interface (2-byte chunks) ------------------------
    input  logic [15:0]             mem_rdata_i,
    input  logic                     mem_ready_i,
    input  logic                     mem_page_fault_i,

    // ---- Fetch request to memory --------------------------------------
    output logic [ADDR_WIDTH-1:0]   fetch_addr_o,
    output logic                     fetch_req_o,

    // ---- Instruction output to decode stage ---------------------------
    output logic [DATA_WIDTH-1:0]   instr_o,
    output logic                     instr_valid_o,
    output logic [ 2:0]             instr_len_o,

    // ---- Exception reporting ------------------------------------------
    output logic                     exception_o,
    output logic [ 1:0]             exception_cause_o,
    output logic [ADDR_WIDTH-1:0]   exception_addr_o,

    // ---- Next-PC output -----------------------------------------------
    output logic [ADDR_WIDTH-1:0]   next_pc_o
);

    // ---- Local parameters ----
    localparam int PAGE_SHIFT  = 12;                // 4 KB page
    localparam int PAGE_SIZE   = 13'h1000;
    localparam int PAGE_MASK   = 12'hFFF;

    // Exception cause encoding
    localparam logic [1:0] EXC_PAGE_FAULT       = 2'b00;
    localparam logic [1:0] EXC_ILLEGAL_INSTR    = 2'b01;
    localparam logic [1:0] EXC_ATOMIC_CROSS_PAGE = 2'b10;

    // Instruction-length encoding (output)
    localparam logic [2:0] LEN_2B = 3'd0;
    localparam logic [2:0] LEN_4B = 3'd1;
    localparam logic [2:0] LEN_6B = 3'd2;
    localparam logic [2:0] LEN_8B = 3'd3;

    // ---- State machine definition ----
    typedef enum logic [1:0] {
        IDLE            = 2'b00,
        FETCH_FIRST     = 2'b01,
        FETCH_REMAINING = 2'b10,
        DONE            = 2'b11
    } state_t;

    state_t state;

    // ---- Internal registers ----

    // Current fetch address driven to memory
    logic [ADDR_WIDTH-1:0] fetch_addr_reg;

    // Original instruction start address — used for exception reporting
    // and for computing next_pc at DONE.
    logic [ADDR_WIDTH-1:0] instr_start_addr;

    // Accumulated instruction bytes (up to 8 bytes = 64 bits).
    // Byte ordering: byte at addr+0 → [7:0], addr+1 → [15:8], …
    logic [63:0] instr_buffer;

    // Decoded instruction-length encoding (from first byte bit[7:6])
    logic [1:0] instr_len_enc;      // 0,1,2,3 → 2,4,6,8 bytes

    // How many bytes have been fetched into the buffer so far
    logic [3:0] bytes_fetched;

    // Total bytes needed for this instruction (2, 4, 6, or 8)
    logic [3:0] total_bytes_needed;

    // ---- Combinational helpers ----

    // True while a memory read request is outstanding
    logic fetching_active;
    assign fetching_active = (state == FETCH_FIRST) || (state == FETCH_REMAINING);

    // ---- State machine + registers (single-process) ----
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            // Asynchronous active-low reset
            state            <= IDLE;
            fetch_addr_reg   <= '0;
            instr_start_addr <= '0;
            instr_buffer     <= '0;
            instr_len_enc    <= 2'b00;
            bytes_fetched    <= 4'd0;
            total_bytes_needed <= 4'd0;

            // Output registers
            fetch_req_o        <= 1'b0;
            instr_valid_o      <= 1'b0;
            instr_o            <= '0;
            instr_len_o        <= LEN_2B;
            next_pc_o          <= '0;
            exception_o        <= 1'b0;
            exception_cause_o  <= EXC_PAGE_FAULT;
            exception_addr_o   <= '0;

        end else if (flush_i || branch_taken_i) begin
            // Pipeline flush / taken branch — discard current fetch,
            // redirect to branch target if branch_taken, else return to IDLE.
            state            <= IDLE;
            fetch_addr_reg   <= branch_taken_i ? branch_target_i : '0;
            instr_start_addr <= branch_taken_i ? branch_target_i : '0;
            instr_buffer     <= '0;
            instr_len_enc    <= 2'b00;
            bytes_fetched    <= 4'd0;
            total_bytes_needed <= 4'd0;

            fetch_req_o        <= 1'b0;
            instr_valid_o      <= 1'b0;
            exception_o        <= 1'b0;

        end else begin
            // Default: de-assert single-cycle pulses
            exception_o <= 1'b0;

            // State-specific behaviour
            unique case (state)

                // IDLE — wait for a fetch request (stall prevents new fetches)
                IDLE: begin
                    instr_valid_o <= 1'b0;

                    if (!stall_i) begin
                        // Issue the first 2-byte read for the new instruction
                        fetch_req_o      <= 1'b1;
                        fetch_addr_reg   <= pc_i;
                        instr_start_addr <= pc_i;
                        instr_buffer     <= '0;
                        bytes_fetched    <= 4'd0;
                        total_bytes_needed <= 4'd0;
                        instr_len_enc    <= 2'b00;
                        state            <= FETCH_FIRST;
                    end else begin
                        fetch_req_o <= 1'b0;
                    end
                end

                // FETCH_FIRST — wait for the first 2 bytes from memory
                FETCH_FIRST: begin
                    fetch_req_o   <= 1'b1;     // request still active
                    instr_valid_o <= 1'b0;

                    if (mem_ready_i) begin

                        if (mem_page_fault_i) begin
                            // Page fault on first halfword — report with
                            // the original instruction start address.
                            // Instruction length is unknown, default to 2 bytes.
                            exception_o        <= 1'b1;
                            exception_cause_o  <= EXC_PAGE_FAULT;
                            exception_addr_o   <= instr_start_addr;
                            instr_len_o        <= LEN_2B;
                            fetch_req_o        <= 1'b0;
                            state              <= IDLE;

                        end else begin
                            // ---- Latch first 2 bytes ----
                            instr_buffer[15:0] <= mem_rdata_i;
                            bytes_fetched      <= 4'd2;

                            // ---- Decode instruction length from first byte ----
                            // first-byte bit[7:6] → length encoding
                            unique case (mem_rdata_i[7:6])
                                2'b00: instr_len_enc <= 2'b00;   //  2 bytes
                                2'b01: instr_len_enc <= 2'b01;   //  4 bytes
                                2'b10: instr_len_enc <= 2'b10;   //  6 bytes
                                2'b11: instr_len_enc <= 2'b11;   //  8 bytes
                            endcase

                            // total_bytes_needed = 2 + (instr_len_enc << 1)
                            total_bytes_needed <= 4'd2 + {2'b00, mem_rdata_i[7:6], 1'b0};

                            // ---- Atomic cross-page check ----
                            // Atomic opcodes are 4-byte fixed-length and MUST
                            // NOT cross a 4 KB page boundary.  The 11-bit
                            // opcode sits in mem_rdata_i[10:0]; upper bits
                            // may carry register / immediate fields and must
                            // be ignored for opcode matching.
                            //   - LL.D (0x040), SC.D (0x041) — vendor zone
                            //   - CAS.* (0x144–0x148) — standard zone
                            if ((mem_rdata_i[7:6] == 2'b01) &&
                                ((mem_rdata_i[10:0] == 11'h040) ||
                                 (mem_rdata_i[10:0] == 11'h041) ||
                                 ((mem_rdata_i[10:0] >= 11'h144) &&
                                  (mem_rdata_i[10:0] <= 11'h148)))) begin

                                // Check cross-page: (start_addr[11:0] + 4) > 4096
                                if ((instr_start_addr[11:0] + 13'd4) >= PAGE_SIZE) begin
                                    exception_o        <= 1'b1;
                                    exception_cause_o  <= EXC_ATOMIC_CROSS_PAGE;
                                    exception_addr_o   <= instr_start_addr;
                                    instr_len_o        <= LEN_4B;
                                    fetch_req_o        <= 1'b0;
                                    state              <= IDLE;
                                end else begin
                                    fetch_addr_reg <= instr_start_addr + ADDR_WIDTH'(2);
                                    state          <= FETCH_REMAINING;
                                end

                            end else if (mem_rdata_i[7:6] == 2'b00) begin
                                // ---- 2-byte instruction: done ----
                                fetch_req_o <= 1'b0;
                                state       <= DONE;

                            end else begin
                                // ---- 4, 6, or 8-byte instruction: more to fetch ----
                                fetch_addr_reg <= instr_start_addr + ADDR_WIDTH'(2);
                                state          <= FETCH_REMAINING;
                            end
                        end
                    end
                end

                // FETCH_REMAINING — fetch the remaining bytes
                FETCH_REMAINING: begin
                    fetch_req_o   <= 1'b1;     // request still active
                    instr_valid_o <= 1'b0;

                    if (mem_ready_i) begin

                        if (mem_page_fault_i) begin
                            // Page fault on a subsequent halfword — the
                            // exception address MUST be the instruction
                            // start address, NOT the intermediate address.
                            exception_o        <= 1'b1;
                            exception_cause_o  <= EXC_PAGE_FAULT;
                            exception_addr_o   <= instr_start_addr;
                            instr_len_o        <= {1'b0, instr_len_enc};
                            fetch_req_o        <= 1'b0;
                            state              <= IDLE;

                        end else begin
                            // ---- Accumulate bytes at the correct offset ----
                            // bytes_fetched already holds the count *before*
                            // this data, so it is the correct byte offset.
                            unique case (bytes_fetched[2:0])
                                3'd2: instr_buffer[31:16] <= mem_rdata_i;
                                3'd4: instr_buffer[47:32] <= mem_rdata_i;
                                3'd6: instr_buffer[63:48] <= mem_rdata_i;
                                default: ;   // safety — should not occur
                            endcase

                            bytes_fetched <= bytes_fetched + 4'd2;

                            // ---- Check if this was the last chunk ----
                            if ((bytes_fetched + 4'd2) >= total_bytes_needed) begin
                                fetch_req_o <= 1'b0;
                                state       <= DONE;
                            end else begin
                                fetch_addr_reg <= fetch_addr_reg + ADDR_WIDTH'(2);
                            end
                        end
                    end
                end

                // DONE — present the complete instruction to the decode stage
                DONE: begin
                    fetch_req_o   <= 1'b0;
                    instr_valid_o <= 1'b1;
                    instr_o       <= instr_buffer;
                    instr_len_o   <= {1'b0, instr_len_enc};
                    next_pc_o     <= instr_start_addr + ADDR_WIDTH'({instr_len_enc, 1'b0} + 3'd2);

                    if (!stall_i) begin
                        // Instruction accepted — start next fetch
                        instr_valid_o    <= 1'b0;
                        fetch_req_o      <= 1'b1;
                        fetch_addr_reg   <= pc_i;
                        instr_start_addr <= pc_i;
                        instr_buffer     <= '0;
                        bytes_fetched    <= 4'd0;
                        total_bytes_needed <= 4'd0;
                        instr_len_enc    <= 2'b00;
                        state            <= FETCH_FIRST;
                    end
                    // else: stalled — hold outputs, stay in DONE
                end

                // Safety fallback
                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

    // ---- Continuous output assignments (fetch address is registered) ----
    assign fetch_addr_o = fetch_addr_reg;

endmodule