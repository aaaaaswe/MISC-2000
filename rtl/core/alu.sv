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
// MISC-2000 Arithmetic Logic Unit (ALU)
// =============================================================================
// Supports 64-bit operations with configurable data width (8/16/32/64-bit).
// Generates zero, negative, overflow, and carry flags.

module misc_alu (
    input  logic [63:0] op_a_i,
    input  logic [63:0] op_b_i,
    input  logic [ 5:0] alu_op_i,
    input  logic [ 2:0] data_width_i,
    output logic [63:0] result_o,
    output logic        zero_o,
    output logic        negative_o,
    output logic        overflow_o,
    output logic        carry_o
);

    // -------------------------------------------------------------------------
    // Operation encoding (one-hot / direct mapping for readability)
    // -------------------------------------------------------------------------
    localparam logic [5:0] OP_ADD    = 6'h00;
    localparam logic [5:0] OP_SUB    = 6'h01;
    localparam logic [5:0] OP_MUL    = 6'h02;
    localparam logic [5:0] OP_DIV    = 6'h03;
    localparam logic [5:0] OP_MOD    = 6'h04;
    localparam logic [5:0] OP_AND    = 6'h05;
    localparam logic [5:0] OP_OR     = 6'h06;
    localparam logic [5:0] OP_XOR    = 6'h07;
    localparam logic [5:0] OP_NOT    = 6'h08;
    localparam logic [5:0] OP_SHL    = 6'h09;
    localparam logic [5:0] OP_SHR    = 6'h0A;
    localparam logic [5:0] OP_SAR    = 6'h0B;
    localparam logic [5:0] OP_ROL    = 6'h0C;
    localparam logic [5:0] OP_ROR    = 6'h0D;
    localparam logic [5:0] OP_INC    = 6'h0E;
    localparam logic [5:0] OP_DEC    = 6'h0F;
    localparam logic [5:0] OP_NEG    = 6'h10;
    localparam logic [5:0] OP_ABS    = 6'h11;
    localparam logic [5:0] OP_CMP    = 6'h12;
    localparam logic [5:0] OP_TEST   = 6'h13;
    localparam logic [5:0] OP_MIN    = 6'h14;
    localparam logic [5:0] OP_MAX    = 6'h15;
    localparam logic [5:0] OP_MINU   = 6'h16;
    localparam logic [5:0] OP_MAXU   = 6'h17;
    localparam logic [5:0] OP_CLZ    = 6'h18;
    localparam logic [5:0] OP_CTZ    = 6'h19;
    localparam logic [5:0] OP_POPCNT = 6'h1A;
    localparam logic [5:0] OP_BSWAP  = 6'h1B;
    localparam logic [5:0] OP_BITREV = 6'h1C;
    localparam logic [5:0] OP_SEXT_B = 6'h1D;
    localparam logic [5:0] OP_SEXT_W = 6'h1E;
    localparam logic [5:0] OP_ZEXT_B = 6'h1F;
    localparam logic [5:0] OP_ZEXT_W = 6'h20;

    // -------------------------------------------------------------------------
    // Data width helpers
    // data_width_i:  0 ->  8-bit (B), 1 -> 16-bit (W),
    //                2 -> 32-bit (D), 3 -> 64-bit (Q)
    // -------------------------------------------------------------------------
    logic [63:0] data_mask;        // bitmask for active data width
    logic [ 5:0] msb_pos;          // index of the MSB for the active data width
    logic [ 5:0] shift_amt;        // limited shift amount (0..63)

    always_comb begin
        case (data_width_i)
            3'd0: begin  // Byte
                data_mask = 64'h0000_0000_0000_00FF;
                msb_pos   = 6'd7;
            end
            3'd1: begin  // Word (16-bit)
                data_mask = 64'h0000_0000_0000_FFFF;
                msb_pos   = 6'd15;
            end
            3'd2: begin  // Double-word (32-bit)
                data_mask = 64'h0000_0000_FFFF_FFFF;
                msb_pos   = 6'd31;
            end
            default: begin  // Quad-word (64-bit)
                data_mask = 64'hFFFF_FFFF_FFFF_FFFF;
                msb_pos   = 6'd63;
            end
        endcase
    end

    // Limit shift amount to the data width
    assign shift_amt = op_b_i[5:0] & {6{1'b1}};  // raw shift amount (0..63)

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [63:0] raw_result;
    logic [63:0] masked_result;
    logic        raw_overflow;
    logic        raw_carry;

    logic [127:0] mul_full;           // full 128-bit multiply product
    logic [ 63:0] div_quotient;       // division quotient
    logic [ 63:0] div_remainder;      // division remainder (modulo)

    // Signed / unsigned extended operands for comparison / arithmetic flag computation
    logic signed [63:0] op_a_signed;
    logic signed [63:0] op_b_signed;

    assign op_a_signed = $signed(op_a_i);
    assign op_b_signed = $signed(op_b_i);

    // Extended add/sub for carry/borrow detection
    logic [64:0] add_ext;   // 65-bit add with carry
    logic [64:0] sub_ext;   // 65-bit sub with borrow

    // -------------------------------------------------------------------------
    // Arithmetic helpers
    // -------------------------------------------------------------------------
    // Full 128-bit multiply
    assign mul_full = op_a_i * op_b_i;

    // Division by zero protection
    assign div_quotient  = (op_b_i == 64'd0) ? 64'd0 : (op_a_i / op_b_i);
    assign div_remainder = (op_b_i == 64'd0) ? 64'd0 : (op_a_i % op_b_i);

    // 65-bit addition / subtraction for carry flag
    assign add_ext = {1'b0, op_a_i} + {1'b0, op_b_i};
    assign sub_ext = {1'b0, op_a_i} - {1'b0, op_b_i};

    // -------------------------------------------------------------------------
    // CLZ / CTZ / POPCNT / BSWAP / BITREV macro functions
    // -------------------------------------------------------------------------
    function automatic logic [63:0] clz_func(input logic [63:0] val);
        integer i;
        clz_func = 64'd0;
        for (i = msb_pos; i >= 0; i--) begin
            if (val[i]) begin
                clz_func = 64'(msb_pos - i);
                return;
            end
        end
        clz_func = 64'(msb_pos + 1);
    endfunction

    function automatic logic [63:0] ctz_func(input logic [63:0] val);
        integer i;
        ctz_func = 64'd0;
        for (i = 0; i <= msb_pos; i++) begin
            if (val[i]) begin
                ctz_func = 64'(i);
                return;
            end
        end
        ctz_func = 64'(msb_pos + 1);
    endfunction

    function automatic logic [63:0] popcnt_func(input logic [63:0] val);
        integer i;
        popcnt_func = 64'd0;
        for (i = 0; i <= msb_pos; i++) begin
            if (val[i]) popcnt_func = popcnt_func + 64'd1;
        end
    endfunction

    function automatic logic [63:0] bswap_func(input logic [63:0] val);
        logic [63:0] swapped;
        integer i;
        swapped = 64'd0;
        // Byte swap within the active data width: byte 0 <-> msb_byte, byte 1 <-> msb_byte-1, ...
        for (i = 0; i < 8; i++) begin
            if (i <= (msb_pos >> 3))
                swapped[i*8 +: 8] = val[((msb_pos >> 3) - i) * 8 +: 8];
        end
        return swapped;
    endfunction

    function automatic logic [63:0] bitrev_func(input logic [63:0] val);
        integer i;
        bitrev_func = 64'd0;
        for (i = 0; i <= msb_pos; i++) begin
            bitrev_func[msb_pos - i] = val[i];
        end
    endfunction

    // -------------------------------------------------------------------------
    // Main ALU operation
    // -------------------------------------------------------------------------
    always_comb begin
        raw_result   = 64'd0;
        raw_overflow = 1'b0;
        raw_carry    = 1'b0;

        unique case (alu_op_i)
            // ---- Arithmetic ----
            OP_ADD: begin
                raw_result   = add_ext[63:0];
                raw_carry    = add_ext[64];
                // Signed overflow: same sign operands, result sign differs
                raw_overflow = (op_a_i[msb_pos] == op_b_i[msb_pos]) &&
                               (raw_result[msb_pos] != op_a_i[msb_pos]);
            end

            OP_SUB: begin
                raw_result   = sub_ext[63:0];
                raw_carry    = ~sub_ext[64];  // borrow flag (inverted carry)
                // Signed overflow: opposite sign operands, result sign differs from op_a
                raw_overflow = (op_a_i[msb_pos] != op_b_i[msb_pos]) &&
                               (raw_result[msb_pos] != op_a_i[msb_pos]);
            end

            OP_MUL: begin
                raw_result = mul_full[63:0];
                // Overflow: upper 64 bits of 128-bit product are non-zero
                raw_overflow = |mul_full[127:64];
            end

            OP_DIV: begin
                raw_result = div_quotient;
            end

            OP_MOD: begin
                raw_result = div_remainder;
            end

            // ---- Logical ----
            OP_AND: begin
                raw_result = op_a_i & op_b_i;
            end

            OP_OR: begin
                raw_result = op_a_i | op_b_i;
            end

            OP_XOR: begin
                raw_result = op_a_i ^ op_b_i;
            end

            OP_NOT: begin
                raw_result = ~op_a_i;
            end

            // ---- Shifts & Rotates ----
            OP_SHL: begin
                raw_result = op_a_i << shift_amt;
            end

            OP_SHR: begin
                raw_result = op_a_i >> shift_amt;
            end

            OP_SAR: begin
                // Use signed shift within the data width
                case (data_width_i)
                    3'd0: raw_result = {{56{op_a_i[7]}},  op_a_i[7:0]}  >> shift_amt;
                    3'd1: raw_result = {{48{op_a_i[15]}}, op_a_i[15:0]} >> shift_amt;
                    3'd2: raw_result = {{32{op_a_i[31]}}, op_a_i[31:0]} >> shift_amt;
                    default: raw_result = $signed(op_a_i) >>> shift_amt;
                endcase
            end

            OP_ROL: begin
                logic [5:0] rot_amt;
                rot_amt = shift_amt % (msb_pos + 6'd1);
                raw_result = (op_a_i << rot_amt) | (op_a_i >> ((msb_pos + 6'd1) - rot_amt));
            end

            OP_ROR: begin
                logic [5:0] rot_amt;
                rot_amt = shift_amt % (msb_pos + 6'd1);
                raw_result = (op_a_i >> rot_amt) | (op_a_i << ((msb_pos + 6'd1) - rot_amt));
            end

            // ---- Unary Arithmetic ----
            OP_INC: begin
                raw_result   = op_a_i + 64'd1;
                raw_carry    = (op_a_i == data_mask);   // carry out when wrapping
                raw_overflow = (op_a_i[msb_pos] == 1'b0) && (raw_result[msb_pos] == 1'b1);
            end

            OP_DEC: begin
                raw_result   = op_a_i - 64'd1;
                raw_carry    = (op_a_i == 64'd0);       // borrow when wrapping from 0
                raw_overflow = (op_a_i[msb_pos] == 1'b1) && (raw_result[msb_pos] == 1'b0);
            end

            OP_NEG: begin
                raw_result   = -op_a_signed;
                // Overflow: negating the most negative signed value
                raw_overflow = (op_a_i[msb_pos] == 1'b1) && (raw_result[msb_pos] == 1'b1);
            end

            OP_ABS: begin
                if (op_a_signed < 0)
                    raw_result = -op_a_signed;
                else
                    raw_result = op_a_i;
                // Overflow: ABS of most negative value
                raw_overflow = (op_a_signed < 0) && (raw_result[msb_pos] == 1'b1);
            end

            // ---- Compare & Test (flags only) ----
            OP_CMP: begin
                raw_result = 64'd0;  // result is always 0 for CMP
            end

            OP_TEST: begin
                raw_result = 64'd0;  // result is always 0 for TEST
            end

            // ---- MIN / MAX (signed) ----
            OP_MIN: begin
                raw_result = (op_a_signed < op_b_signed) ? op_a_i : op_b_i;
            end

            OP_MAX: begin
                raw_result = (op_a_signed > op_b_signed) ? op_a_i : op_b_i;
            end

            // ---- MIN / MAX (unsigned) ----
            OP_MINU: begin
                raw_result = (op_a_i < op_b_i) ? op_a_i : op_b_i;
            end

            OP_MAXU: begin
                raw_result = (op_a_i > op_b_i) ? op_a_i : op_b_i;
            end

            // ---- Bit Manipulation ----
            OP_CLZ: begin
                raw_result = clz_func(op_a_i);
            end

            OP_CTZ: begin
                raw_result = ctz_func(op_a_i);
            end

            OP_POPCNT: begin
                raw_result = popcnt_func(op_a_i);
            end

            OP_BSWAP: begin
                raw_result = bswap_func(op_a_i);
            end

            OP_BITREV: begin
                raw_result = bitrev_func(op_a_i);
            end

            // ---- Sign / Zero Extension ----
            OP_SEXT_B: begin
                raw_result = {{56{op_a_i[7]}}, op_a_i[7:0]};
            end

            OP_SEXT_W: begin
                raw_result = {{48{op_a_i[15]}}, op_a_i[15:0]};
            end

            OP_ZEXT_B: begin
                raw_result = {56'd0, op_a_i[7:0]};
            end

            OP_ZEXT_W: begin
                raw_result = {48'd0, op_a_i[15:0]};
            end

            default: begin
                raw_result = 64'd0;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Data width masking
    // -------------------------------------------------------------------------
    assign masked_result = raw_result & data_mask;

    // -------------------------------------------------------------------------
    // Output assignment
    // -------------------------------------------------------------------------
    assign result_o = masked_result;

    // -------------------------------------------------------------------------
    // Flag generation
    // -------------------------------------------------------------------------
    // For CMP: compare op_a and op_b (subtraction flags)
    // For TEST: AND op_a and op_b, then check flags
    logic [63:0] cmp_result_masked;
    assign cmp_result_masked = (alu_op_i == OP_CMP) ? (sub_ext[63:0] & data_mask) :
                               (alu_op_i == OP_TEST) ? ((op_a_i & op_b_i) & data_mask) :
                               masked_result;

    assign zero_o = (cmp_result_masked == 64'd0);

    // negative flag: MSB of the result within the current data width
    assign negative_o = (alu_op_i == OP_CMP) ? sub_ext[msb_pos] :
                        (alu_op_i == OP_TEST) ? (op_a_i[msb_pos] & op_b_i[msb_pos]) :
                        masked_result[msb_pos];

    // overflow flag
    assign overflow_o = raw_overflow;

    // carry flag
    assign carry_o = raw_carry;

endmodule