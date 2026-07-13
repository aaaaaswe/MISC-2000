// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// MISC-2000 Arithmetic Logic Unit — 64-bit ops with configurable data width (8/16/32/64-bit).
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
    //
    // The ALU always operates on a 64-bit datapath, but when the active data
    // width is narrower than 64 bits, the operands must be zero-extended into
    // that width (sign-extended for the sign bit of signed ops).  Otherwise
    // garbage in the upper bits (e.g. from an 8-bit load that left 56 bits
    // untouched) leaks into MUL / DIV / MOD / shifts / bit-count results.
    // -------------------------------------------------------------------------
    logic [63:0] data_mask;        // bitmask for active data width
    logic [ 5:0] msb_pos;          // index of the MSB for the active data width
    logic [ 5:0] shift_amt;        // limited shift amount (0..msb_pos)

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

    // Operands zero-masked to the active data width.  All ALU operations
    // should use these (not op_a_i / op_b_i directly) unless they explicitly
    // want to see the raw, un-truncated input (e.g. sign-extension ops).
    logic [63:0] op_a_m;
    logic [63:0] op_b_m;
    assign op_a_m = op_a_i & data_mask;
    assign op_b_m = op_b_i & data_mask;

    // Limit shift amount to the data width (0 .. msb_pos).
    // Values larger than msb_pos are wrapped to keep the result deterministic
    // and to avoid undefined behaviour when a user-supplied shift amount
    // exceeds the active data width.
    always_comb begin
        case (data_width_i)
            3'd0:    shift_amt = {3'd0, op_b_i[2:0]};
            3'd1:    shift_amt = {2'd0, op_b_i[3:0]};
            3'd2:    shift_amt = {1'd0, op_b_i[4:0]};
            default: shift_amt = op_b_i[5:0];
        endcase
    end

    // Sign-extended operand for signed comparisons / arithmetic.  Note that
    // the sign bit is the MSB of the *active* data width, not necessarily
    // bit 63.  This is used for OP_SAR, OP_MIN, OP_MAX, OP_NEG, OP_ABS.
    function automatic logic [63:0] sext_active(logic [63:0] val);
        logic [63:0] result;
        logic sign_bit;
        result = val & data_mask;
        unique case (data_width_i)
            3'd0: begin
                sign_bit = val[7];
                result[63:7] = {57{sign_bit}};
            end
            3'd1: begin
                sign_bit = val[15];
                result[63:15] = {49{sign_bit}};
            end
            3'd2: begin
                sign_bit = val[31];
                result[63:31] = {33{sign_bit}};
            end
            default: begin
                sign_bit = val[63];
                // Already 64-bit, no extension needed
            end
        endcase
        sext_active = result;
    endfunction

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    logic [63:0] raw_result;
    logic [63:0] masked_result;
    logic        raw_overflow;
    logic        raw_carry;

    logic [127:0] mul_full;           // full 128-bit multiply product (masked inputs)
    logic [ 63:0] div_quotient;       // division quotient
    logic [ 63:0] div_remainder;      // division remainder (modulo)

    // Sign-extended operand for signed comparisons / arithmetic.  Operates
    // on the masked (data-width-truncated) input so garbage above the MSB
    // cannot corrupt the sign.
    logic signed [63:0] op_a_sext;
    logic signed [63:0] op_b_sext;

    always_comb begin
        op_a_sext = $signed(sext_active(op_a_i));
        op_b_sext = $signed(sext_active(op_b_i));
    end

    // Extended add/sub for carry/borrow detection.  Uses the masked
    // operands so the carry out is computed from the active-width slice.
    logic [64:0] add_ext;   // 65-bit add with carry
    logic [64:0] sub_ext;   // 65-bit sub with borrow

    assign add_ext = {1'b0, op_a_m} + {1'b0, op_b_m};
    assign sub_ext = {1'b0, op_a_m} - {1'b0, op_b_m};

    // Per-width carry/borrow extraction
    logic add_carry;
    logic sub_borrow;
    always @(*) begin
        case (data_width_i)
            3'd0:    add_carry = add_ext[8];
            3'd1:    add_carry = add_ext[16];
            3'd2:    add_carry = add_ext[32];
            default: add_carry = add_ext[64];
        endcase
    end
    always @(*) begin
        case (data_width_i)
            3'd0:    sub_borrow = sub_ext[8];
            3'd1:    sub_borrow = sub_ext[16];
            3'd2:    sub_borrow = sub_ext[32];
            default: sub_borrow = sub_ext[64];
        endcase
    end

    // -------------------------------------------------------------------------
    // Arithmetic helpers
    // -------------------------------------------------------------------------
    // Full 128-bit multiply.  Only the masked inputs participate, so for
    // narrower widths the upper half of the product is guaranteed to be
    // zero when there is no overflow.
    assign mul_full = op_a_m * op_b_m;

    // Division by zero protection — produce 0 on both outputs to avoid
    // propagating X from an undefined division.
    assign div_quotient  = (op_b_m == 64'd0) ? 64'd0 : (op_a_m / op_b_m);
    assign div_remainder = (op_b_m == 64'd0) ? 64'd0 : (op_a_m % op_b_m);

    // -------------------------------------------------------------------------
    // CLZ / CTZ / POPCNT / BSWAP / BITREV helper functions
    //   All helpers operate on the zero-masked input so bits above the
    //   active data width cannot corrupt the result.
    // -------------------------------------------------------------------------
    function automatic logic [63:0] clz_func(input logic [63:0] val);
        logic [63:0] v;
        integer i;
        v = val & data_mask;
        clz_func = 64'(msb_pos + 1);
        for (i = msb_pos; i >= 0; i--) begin
            if (v[i]) begin
                clz_func = 64'(msb_pos - i);
                i = -1;
            end
        end
    endfunction

    function automatic logic [63:0] ctz_func(input logic [63:0] val);
        logic [63:0] v;
        integer i;
        v = val & data_mask;
        ctz_func = 64'(msb_pos + 1);
        for (i = 0; i <= msb_pos; i++) begin
            if (v[i]) begin
                ctz_func = 64'(i);
                i = msb_pos + 1;
            end
        end
    endfunction

    function automatic logic [63:0] popcnt_func(input logic [63:0] val);
        logic [63:0] v;
        integer i;
        v = val & data_mask;
        popcnt_func = 64'd0;
        for (i = 0; i <= msb_pos; i++) begin
            if (v[i]) popcnt_func = popcnt_func + 64'd1;
        end
    endfunction

    function automatic logic [63:0] bswap_func(input logic [63:0] val);
        logic [63:0] v;
        logic [63:0] swapped;
        integer i;
        integer top_byte;
        v = val & data_mask;
        swapped = 64'd0;
        top_byte = msb_pos >> 3;
        // Byte-swap within the active data width: 0 <-> top_byte, etc.
        for (i = 0; i <= top_byte; i++) begin
            swapped[i*8 +: 8] = v[(top_byte - i) * 8 +: 8];
        end
        bswap_func = swapped;
    endfunction

    function automatic logic [63:0] bitrev_func(input logic [63:0] val);
        logic [63:0] v;
        integer i;
        v = val & data_mask;
        bitrev_func = 64'd0;
        for (i = 0; i <= msb_pos; i++) begin
            bitrev_func[msb_pos - i] = v[i];
        end
    endfunction

    // -------------------------------------------------------------------------
    // Main ALU operation
    //   Rules:
    //   * Operands participating in arithmetic/logic/shift are op_a_m / op_b_m
    //     (zero-masked to the active data width) unless otherwise noted.
    //   * Signed operations use op_a_sext / op_b_sext (sign-extended from the
    //     active data width into bit 63) so narrower-width signed values are
    //     interpreted correctly.
    //   * raw_result is always truncated to the active data width at the
    //     output (masked_result), so it is fine if computation temporarily
    //     produces non-zero bits above msb_pos.
    // -------------------------------------------------------------------------
    always @(*) begin
        raw_result   = 64'd0;
        raw_overflow = 1'b0;
        raw_carry    = 1'b0;

        unique case (alu_op_i)
            // ---- Arithmetic ----
            OP_ADD: begin
                raw_result   = add_ext[63:0];
                raw_carry    = add_carry;
                // Signed overflow: same-sign operands produce opposite-sign result.
                raw_overflow = (op_a_m[msb_pos] == op_b_m[msb_pos]) &&
                               (raw_result[msb_pos] != op_a_m[msb_pos]);
            end

            OP_SUB: begin
                raw_result   = sub_ext[63:0];
                raw_carry    = ~sub_borrow;  // borrow flag (inverted carry)
                // Signed overflow: opposite-sign operands produce op_a's sign.
                raw_overflow = (op_a_m[msb_pos] != op_b_m[msb_pos]) &&
                               (raw_result[msb_pos] != op_a_m[msb_pos]);
            end

            OP_MUL: begin
                raw_result = mul_full[63:0];
                // Overflow: upper bits of 128-bit product beyond active width are non-zero.
                case (data_width_i)
                    3'd0:    raw_overflow = (|mul_full[15:8]);
                    3'd1:    raw_overflow = (|mul_full[31:16]);
                    3'd2:    raw_overflow = (|mul_full[63:32]);
                    default: raw_overflow = (|mul_full[127:64]);
                endcase
            end

            OP_DIV: begin
                raw_result = div_quotient;
            end

            OP_MOD: begin
                raw_result = div_remainder;
            end

            // ---- Logical ----
            OP_AND: begin
                raw_result = op_a_m & op_b_m;
            end

            OP_OR: begin
                raw_result = op_a_m | op_b_m;
            end

            OP_XOR: begin
                raw_result = op_a_m ^ op_b_m;
            end

            OP_NOT: begin
                raw_result = ~op_a_m;
            end

            // ---- Shifts & Rotates ----
            OP_SHL: begin
                raw_result = op_a_m << shift_amt;
            end

            OP_SHR: begin
                raw_result = op_a_m >> shift_amt;
            end

            OP_SAR: begin
                // Arithmetic right shift on the sign-extended value.
                // Using `>>>` on a signed operand replicates the sign bit.
                raw_result = op_a_sext >>> shift_amt;
            end

            OP_ROL: begin
                logic [6:0] rot_amt;
                rot_amt = shift_amt % (7'(msb_pos) + 7'd1);
                raw_result = (op_a_m << rot_amt) | (op_a_m >> ((7'(msb_pos) + 7'd1) - rot_amt));
            end

            OP_ROR: begin
                logic [6:0] rot_amt;
                rot_amt = shift_amt % (7'(msb_pos) + 7'd1);
                raw_result = (op_a_m >> rot_amt) | (op_a_m << ((7'(msb_pos) + 7'd1) - rot_amt));
            end

            // ---- Unary Arithmetic ----
            OP_INC: begin
                raw_result   = op_a_m + 64'd1;
                raw_carry    = (op_a_m == data_mask);   // carry out when wrapping
                raw_overflow = (op_a_m[msb_pos] == 1'b0) && (raw_result[msb_pos] == 1'b1);
            end

            OP_DEC: begin
                raw_result   = op_a_m - 64'd1;
                raw_carry    = (op_a_m == 64'd0);       // borrow when wrapping from 0
                raw_overflow = (op_a_m[msb_pos] == 1'b1) && (raw_result[msb_pos] == 1'b0);
            end

            OP_NEG: begin
                // Negate the sign-extended value so a 0x80 input at width=8
                // correctly overflows to -128 instead of being "computed"
                // from the raw 64-bit -0x80.
                raw_result   = 64'(-op_a_sext);
                // Overflow: negating the most negative signed value.
                raw_overflow = (op_a_m[msb_pos] == 1'b1) && (raw_result[msb_pos] == 1'b1);
            end

            OP_ABS: begin
                if (op_a_sext < 0)
                    raw_result = 64'(-op_a_sext);
                else
                    raw_result = op_a_m;
                // Overflow: ABS of the most negative value.
                raw_overflow = (op_a_sext < 0) && (raw_result[msb_pos] == 1'b1);
            end

            // ---- Compare & Test (flags only) ----
            //   raw_result is forced to 0 at the output for CMP/TEST so that
            //   consumers see "no result written back".  Flags are still
            //   computed from the real operands below.
            OP_CMP: begin
                raw_result = 64'd0;
                // Re-use subtract carry/borrow for flag generation.
                raw_carry    = ~sub_borrow;
                raw_overflow = (op_a_m[msb_pos] != op_b_m[msb_pos]) &&
                               (sub_ext[msb_pos] != op_a_m[msb_pos]);
            end

            OP_TEST: begin
                raw_result = 64'd0;
                // TEST does not produce a meaningful carry/overflow; flags
                // are derived from the AND result (zero / negative only).
            end

            // ---- MIN / MAX (signed) ----
            OP_MIN: begin
                raw_result = (op_a_sext < op_b_sext) ? op_a_m : op_b_m;
            end

            OP_MAX: begin
                raw_result = (op_a_sext > op_b_sext) ? op_a_m : op_b_m;
            end

            // ---- MIN / MAX (unsigned) ----
            OP_MINU: begin
                raw_result = (op_a_m < op_b_m) ? op_a_m : op_b_m;
            end

            OP_MAXU: begin
                raw_result = (op_a_m > op_b_m) ? op_a_m : op_b_m;
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
            //   These intentionally operate on the *raw* input so callers
            //   can transform a sub-word value sitting in the low bits
            //   without needing to have masked it first.
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
    //   CMP and TEST have raw_result forced to 0 above, so we re-derive their
    //   flags here from the actual comparison value.  All flags operate within
    //   the active data width.
    // -------------------------------------------------------------------------
    logic [63:0] cmp_result_masked;
    assign cmp_result_masked = (alu_op_i == OP_CMP) ? (sub_ext[63:0] & data_mask) :
                               (alu_op_i == OP_TEST) ? ((op_a_m & op_b_m) & data_mask) :
                               masked_result;

    assign zero_o = (cmp_result_masked == 64'd0);

    // negative flag: MSB of the result within the current data width
    logic neg_bit;
    always @(*) begin
        case (data_width_i)
            3'd0:    neg_bit = masked_result[7];
            3'd1:    neg_bit = masked_result[15];
            3'd2:    neg_bit = masked_result[31];
            default: neg_bit = masked_result[63];
        endcase
    end
    logic cmp_neg;
    always @(*) begin
        case (data_width_i)
            3'd0:    cmp_neg = sub_ext[7];
            3'd1:    cmp_neg = sub_ext[16];
            3'd2:    cmp_neg = sub_ext[32];
            default: cmp_neg = sub_ext[63];
        endcase
    end
    logic test_neg;
    always @(*) begin
        case (data_width_i)
            3'd0:    test_neg = op_a_m[7] & op_b_m[7];
            3'd1:    test_neg = op_a_m[15] & op_b_m[15];
            3'd2:    test_neg = op_a_m[31] & op_b_m[31];
            default: test_neg = op_a_m[63] & op_b_m[63];
        endcase
    end
    assign negative_o = (alu_op_i == OP_CMP) ? cmp_neg :
                        (alu_op_i == OP_TEST) ? test_neg :
                        neg_bit;

    // overflow flag
    assign overflow_o = raw_overflow;

    // carry flag
    assign carry_o = raw_carry;

endmodule