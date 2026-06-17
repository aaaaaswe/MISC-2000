// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// =============================================================================
// MISC-2000 GETILEN (Get Instruction Length) Auxiliary Instruction Module
// =============================================================================
// GETILEN is an auxiliary instruction (opcode 0x14F) that reads the first byte
// of the target address and returns the instruction length (2, 4, 6, or 8 bytes)
// to the destination register, WITHOUT executing the target instruction.
//
// Format: GETILEN.IMM Rd, [address]
//
// The first byte of the target instruction encodes the length in bit[7:6]:
//   00 -> 2 bytes, 01 -> 4 bytes, 10 -> 6 bytes, 11 -> 8 bytes
//
// On memory page fault, exception_o is asserted with exception_addr_o set to
// the GETILEN operand address (target_addr_i).

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

    // -------------------------------------------------------------------------
    // Local parameters
    // -------------------------------------------------------------------------
    localparam logic [10:0] OPCODE_GETILEN = 11'h14F;

    // State encoding
    typedef enum logic [1:0] {
        ST_IDLE      = 2'b00,
        ST_READ_BYTE = 2'b01,
        ST_WAIT_READ = 2'b10,
        ST_DONE      = 2'b11
    } state_t;

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    state_t state_q, state_next;

    logic                   is_getilen;         // Decoded GETILEN instruction
    logic [1:0]             instr_len_enc;      // Instruction length encoding from bit[7:6]
    logic [DATA_WIDTH-1:0]  length_result;      // Decoded instruction length (2/4/6/8)

    // -------------------------------------------------------------------------
    // GETILEN instruction detection
    // -------------------------------------------------------------------------
    assign is_getilen = (opcode_i == OPCODE_GETILEN) && instr_valid_i;

    // -------------------------------------------------------------------------
    // Instruction length decoding from the first byte bit[7:6]
    // -------------------------------------------------------------------------
    assign instr_len_enc = mem_rdata_i[7:6];

    always_comb begin
        unique case (instr_len_enc)
            2'b00:   length_result = { {(DATA_WIDTH-2){1'b0}}, 2'd2 };
            2'b01:   length_result = { {(DATA_WIDTH-3){1'b0}}, 3'd4 };
            2'b10:   length_result = { {(DATA_WIDTH-3){1'b0}}, 3'd6 };
            2'b11:   length_result = { {(DATA_WIDTH-4){1'b0}}, 4'd8 };
            default: length_result = { {(DATA_WIDTH-2){1'b0}}, 2'd2 };
        endcase
    end

    // -------------------------------------------------------------------------
    // State machine: sequential logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_q <= ST_IDLE;
        end else begin
            state_q <= state_next;
        end
    end

    // -------------------------------------------------------------------------
    // State machine: next-state logic (combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        state_next = state_q;
        unique case (state_q)
            ST_IDLE: begin
                if (is_getilen)
                    state_next = ST_READ_BYTE;
            end

            ST_READ_BYTE: begin
                state_next = ST_WAIT_READ;
            end

            ST_WAIT_READ: begin
                if (mem_ready_i | mem_page_fault_i)
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

    // -------------------------------------------------------------------------
    // Memory interface outputs
    // -------------------------------------------------------------------------
    assign mem_addr_o = target_addr_i;
    assign mem_read_o = (state_q == ST_READ_BYTE);

    // -------------------------------------------------------------------------
    // Exception outputs
    //
    // On page fault, assert exception_o. The exception address is always the
    // GETILEN operand address (target_addr_i), not any instruction address.
    // -------------------------------------------------------------------------
    assign exception_o      = (state_q == ST_WAIT_READ) && mem_page_fault_i;
    assign exception_addr_o = target_addr_i;

    // -------------------------------------------------------------------------
    // Result outputs
    // -------------------------------------------------------------------------
    assign result_o       = length_result;
    assign result_valid_o = (state_q == ST_DONE) && !mem_page_fault_i;

    // -------------------------------------------------------------------------
    // Busy output
    // -------------------------------------------------------------------------
    assign busy_o = (state_q != ST_IDLE);

endmodule