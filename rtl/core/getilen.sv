// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// GETILEN: opcode 0x14F, reads target byte bit[7:6] → length (2/4/6/8)
// Returns length to Rd without executing; page fault addr = operand address
module misc_getilen #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 64
) (
    // Clock and reset
    input  logic                         clk_i,
    input  logic                         rst_n_i,

    // Instruction decode interface
    input  logic [10:0]                  opcode_i,
    input  logic [4:0]                   rd_addr_i,
    input  logic [ADDR_WIDTH-1:0]        target_addr_i,
    input  logic                         instr_valid_i,

    // Memory interface (byte read)
    output logic [ADDR_WIDTH-1:0]        mem_addr_o,
    output logic                         mem_read_o,
    input  logic [7:0]                   mem_rdata_i,
    input  logic                         mem_ready_i,
    input  logic                         mem_page_fault_i,

    // Exception interface
    output logic                         exception_o,
    output logic [ADDR_WIDTH-1:0]        exception_addr_o,

    // Result interface
    output logic [DATA_WIDTH-1:0]        result_o,
    output logic                         result_valid_o,
    output logic                         busy_o
);

    // Local parameters
    localparam logic [10:0] OPCODE_GETILEN = 11'h14F;

    typedef enum logic [1:0] {
        ST_IDLE      = 2'b00,
        ST_WAIT_READ = 2'b01,
        ST_DONE      = 2'b10
    } state_t;

    // Internal signals
    state_t state_q, state_next;

    logic                       is_getilen;         // Decoded GETILEN instruction
    logic [ADDR_WIDTH-1:0]      addr_q;             // Registered memory address
    logic [DATA_WIDTH-1:0]      result_q;           // Registered result
    logic                       exception_q;        // Registered exception flag
    logic [ADDR_WIDTH-1:0]      exception_addr_q;   // Registered exception address
    logic                       result_valid_q;     // Registered result valid
    logic                       page_fault_q;       // Latched page-fault flag

    // GETILEN instruction detection
    assign is_getilen = (opcode_i == OPCODE_GETILEN) && instr_valid_i;

    // Instruction length decoding helper
    function automatic logic [DATA_WIDTH-1:0] decode_length(input logic [7:0] byte_val);
        unique case (byte_val[7:6])
            2'b00:   decode_length = {{(DATA_WIDTH-2){1'b0}}, 2'd2};
            2'b01:   decode_length = {{(DATA_WIDTH-3){1'b0}}, 3'd4};
            2'b10:   decode_length = {{(DATA_WIDTH-3){1'b0}}, 3'd6};
            2'b11:   decode_length = {{(DATA_WIDTH-4){1'b0}}, 4'd8};
            default: decode_length = {{(DATA_WIDTH-2){1'b0}}, 2'd2};
        endcase
    endfunction

    // State machine (sequential)
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_q          <= ST_IDLE;
            addr_q           <= {ADDR_WIDTH{1'b0}};
            result_q         <= {DATA_WIDTH{1'b0}};
            page_fault_q     <= 1'b0;
            exception_q      <= 1'b0;
            exception_addr_q <= {ADDR_WIDTH{1'b0}};
            result_valid_q   <= 1'b0;
        end else begin
            state_q          <= state_next;
            result_valid_q   <= (state_next == ST_DONE);

            if (state_q == ST_IDLE && is_getilen) begin
                addr_q       <= target_addr_i;
                page_fault_q <= 1'b0;
            end
            if (state_q == ST_WAIT_READ && mem_ready_i && !mem_page_fault_i) begin
                result_q <= decode_length(mem_rdata_i);
            end

            if (state_next == ST_DONE) begin
                if (state_q == ST_WAIT_READ && mem_page_fault_i) begin
                    exception_q      <= 1'b1;
                    exception_addr_q <= addr_q;
                end else begin
                    exception_q      <= 1'b0;
                end
            end else begin
                exception_q      <= 1'b0;
                exception_addr_q <= {ADDR_WIDTH{1'b0}};
            end
        end
    end

    always_comb begin
        state_next = state_q;
        unique case (state_q)
            ST_IDLE: begin
                if (is_getilen)
                    state_next = ST_WAIT_READ;
            end

            ST_WAIT_READ: begin
                if (mem_ready_i || mem_page_fault_i)
                    state_next = ST_DONE;
            end

            ST_DONE: begin
                state_next = ST_IDLE;
            end

            default: begin
                state_next = ST_IDLE;
            end
        endcase
    end

    assign mem_addr_o = addr_q;
    assign mem_read_o = (state_q == ST_WAIT_READ);

    assign exception_o      = exception_q;
    assign exception_addr_o = exception_addr_q;

    assign result_o       = result_q;
    assign result_valid_o = result_valid_q;

    // Busy output
    assign busy_o = (state_q != ST_IDLE);

endmodule