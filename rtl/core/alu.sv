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
//
// NOTE: this module intentionally avoids variable part-selects that depend
// on a run-time signal (`data_width_i`) because not every Verilog simulator
// supports them inside `always_comb` blocks.  All width-dependent masking
// is performed with explicit `case` statements on `data_width_i`.

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
    // Operation encodings
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
    // Data-width helper: produce a 64-bit mask for the active data width and
    // a 6-bit "msb position" (7 / 15 / 31 / 63).  Implemented as a
    // combinational case rather than a parameter so callers can change the
    // width at run-time.
    // -------------------------------------------------------------------------
    logic [63:0] data_mask;
    logic [ 5:0] msb_pos;

    always_comb begin
        case (data_width_i)
            3'd0:   begin data_mask = 64'h00000000_000000FF; msb_pos = 6'd7;  end
            3'd1:   begin data_mask = 64'h00000000_0000FFFF; msb_pos = 6'd15; end
            3'd2:   begin data_mask = 64'h00000000_FFFFFFFF; msb_pos = 6'd31; end
            default:begin data_mask = 64'hFFFFFFFF_FFFFFFFF; msb_pos = 6'd63; end
        endcase
    end

    // Zero-extend helpers: truncate `val` to the active data width.  We
    // compute these with explicit muxes (instead of `val & data_mask`) so
    // that add_ext/sub_ext propagate the carry flag correctly for widths
    // smaller than 64 bits.
    function automatic logic [63:0] zext_dw(input [63:0] val, input [2:0] dw);
        case (dw)
            3'd0:    zext_dw = {56'd0, val[7:0]};
            3'd1:    zext_dw = {48'd0, val[15:0]};
            3'd2:    zext_dw = {32'd0, val[31:0]};
            default: zext_dw = val;
        endcase
    endfunction

    // Zero-masked operands: op_a_i/op_b_i truncated to the active width.
    logic [63:0] op_a_m;
    logic [63:0] op_b_m;
    assign op_a_m = zext_dw(op_a_i, data_width_i);
    assign op_b_m = zext_dw(op_b_i, data_width_i);

    // Signed-extend operands.  Used for SAR, signed compare (MIN/MAX),
    // NEG, ABS.
    logic [63:0] op_a_sext;
    logic [63:0] op_b_sext;
    always_comb begin
        case (data_width_i)
            3'd0:    begin op_a_sext = {{56{op_a_i[7]}},  op_a_i[7:0]};
                              op_b_sext = {{56{op_b_i[7]}},  op_b_i[7:0]}; end
            3'd1:    begin op_a_sext = {{48{op_a_i[15]}}, op_a_i[15:0]};
                              op_b_sext = {{48{op_b_i[15]}}, op_b_i[15:0]}; end
            3'd2:    begin op_a_sext = {{32{op_a_i[31]}}, op_a_i[31:0]};
                              op_b_sext = {{32{op_b_i[31]}}, op_b_i[31:0]}; end
            default: begin op_a_sext = op_a_i;
                              op_b_sext = op_b_i; end
        endcase
    end

    // Shift amount, clamped to 0..msb_pos.  iverilog does not allow a
    // variable part-select indexed by `msb_pos`, so we use an explicit
    // `case` over `data_width_i`.
    logic [5:0] shift_amt;
    always_comb begin
        case (data_width_i)
            3'd0:    shift_amt = {3'd0, op_b_i[2:0]};
            3'd1:    shift_amt = {2'd0, op_b_i[3:0]};
            3'd2:    shift_amt = {1'd0, op_b_i[4:0]};
            default: shift_amt = op_b_i[5:0];
        endcase
    end

    // -------------------------------------------------------------------------
    // Arithmetic helpers
    //
    // Compute addition / subtraction with one extra bit of precision at each
    // sub-width so the sampled bit is the true carry / borrow flag.
    // raw_carry / raw_overflow below sample carry_bit_of from the active
    // data-width extension.
    // -------------------------------------------------------------------------
    logic [8:0] add_b;       // 8b  + 8b  (B)
    logic [16:0] add_w;      // 16b + 16b (W)
    logic [32:0] add_d;      // 32b + 32b (D)
    logic [64:0] add_q;      // 64b + 64b (Q)
    logic [8:0] sub_b;
    logic [16:0] sub_w;
    logic [32:0] sub_d;
    logic [64:0] sub_q;

    assign add_b = {1'b0, op_a_m[7:0]}   + {1'b0, op_b_m[7:0]};
    assign add_w = {1'b0, op_a_m[15:0]}  + {1'b0, op_b_m[15:0]};
    assign add_d = {1'b0, op_a_m[31:0]}  + {1'b0, op_b_m[31:0]};
    assign add_q = {1'b0, op_a_m}         + {1'b0, op_b_m};

    assign sub_b = {1'b0, op_a_m[7:0]}   - {1'b0, op_b_m[7:0]};
    assign sub_w = {1'b0, op_a_m[15:0]}  - {1'b0, op_b_m[15:0]};
    assign sub_d = {1'b0, op_a_m[31:0]}  - {1'b0, op_b_m[31:0]};
    assign sub_q = {1'b0, op_a_m}         - {1'b0, op_b_m};

    // Pick the right add/sub extension given the active data width.
    logic [64:0] add_ext;
    logic [64:0] sub_ext;
    always_comb begin
        case (data_width_i)
            3'd0:    add_ext = {56'd0, add_b};
            3'd1:    add_ext = {48'd0, add_w};
            3'd2:    add_ext = {32'd0, add_d};
            default: add_ext = add_q;
        endcase
    end
    always_comb begin
        case (data_width_i)
            3'd0:    sub_ext = {56'd0, sub_b};
            3'd1:    sub_ext = {48'd0, sub_w};
            3'd2:    sub_ext = {32'd0, sub_d};
            default: sub_ext = sub_q;
        endcase
    end

    function automatic logic carry_bit_of(input [64:0] ext, input [2:0] dw);
        case (dw)
            3'd0:    carry_bit_of = ext[8];
            3'd1:    carry_bit_of = ext[16];
            3'd2:    carry_bit_of = ext[32];
            default: carry_bit_of = ext[64];
        endcase
    endfunction

    logic [127:0] mul_full;
    assign mul_full = op_a_m * op_b_m;

    logic [63:0] div_quotient;
    logic [63:0] div_remainder;
    assign div_quotient  = (op_b_m == 64'd0) ? 64'd0 : (op_a_m / op_b_m);
    assign div_remainder = (op_b_m == 64'd0) ? 64'd0 : (op_a_m % op_b_m);

    // -------------------------------------------------------------------------
    // Count-leading-zeros helper.  Implemented as a priority encoder over
    // explicit fixed-width slices so it synthesises cleanly and does not
    // rely on variable part-selects.
    // -------------------------------------------------------------------------
    function automatic [63:0] clz_func(input [63:0] val, input [2:0] dw);
        logic [6:0] cnt;
        logic       done;
        int top;
        cnt  = 7'd0;
        done = 1'b0;
        case (dw)
            3'd0: top = 7;
            3'd1: top = 15;
            3'd2: top = 31;
            default: top = 63;
        endcase
        for (int i = 0; i <= 63; i = i + 1) begin
            if ((!done) && (top - i) >= 0) begin
                if (val[top - i] == 1'b0) cnt = cnt + 7'd1;
                else                        done = 1'b1;
            end
        end
        clz_func = {57'd0, cnt};
    endfunction

    function automatic [63:0] ctz_func(input [63:0] val, input [2:0] dw);
        logic [6:0] cnt;
        logic       done;
        int top;
        cnt  = 7'd0;
        done = 1'b0;
        case (dw)
            3'd0: top = 7;
            3'd1: top = 15;
            3'd2: top = 31;
            default: top = 63;
        endcase
        for (int i = 0; i <= top; i = i + 1) begin
            if (!done) begin
                if (val[i] == 1'b0) cnt = cnt + 7'd1;
                else                done = 1'b1;
            end
        end
        ctz_func = {57'd0, cnt};
    endfunction

    function automatic [63:0] popcnt_func(input [63:0] val, input [2:0] dw);
        logic [6:0] cnt;
        int top;
        cnt = 7'd0;
        case (dw)
            3'd0: top = 7;
            3'd1: top = 15;
            3'd2: top = 31;
            default: top = 63;
        endcase
        for (int i = 0; i <= top; i = i + 1) begin
            if (val[i]) cnt = cnt + 7'd1;
        end
        popcnt_func = {57'd0, cnt};
    endfunction

    // Byte-swap within the active data width (big-endian <-> little-endian).
    function automatic [63:0] bswap_func(input [63:0] val, input [2:0] dw);
        logic [63:0] out;
        out = 64'd0;
        case (dw)
            3'd0: out = val;
            3'd1: out = {48'd0, val[7:0], val[15:8]};
            3'd2: out = {32'd0, val[7:0], val[15:8], val[23:16], val[31:24]};
            default: begin
                out = {val[7:0], val[15:8], val[23:16], val[31:24],
                       val[39:32], val[47:40], val[55:48], val[63:56]};
            end
        endcase
        bswap_func = out;
    endfunction

    function automatic [63:0] bitrev_func(input [63:0] val, input [2:0] dw);
        logic [63:0] out;
        int top;
        out = 64'd0;
        case (dw)
            3'd0: top = 7;
            3'd1: top = 15;
            3'd2: top = 31;
            default: top = 63;
        endcase
        for (int i = 0; i <= 63; i = i + 1) begin
            if (i <= top) out[i] = val[top - i];
        end
        bitrev_func = out;
    endfunction

    // -------------------------------------------------------------------------
    // Rotate helpers: rotate `val` left/right by `amt` bits within the
    // active data width.  Each supported width is computed separately
    // because iverilog does not allow variable-width selects inside
    // always_comb.
    // -------------------------------------------------------------------------
    function automatic logic [63:0] rol_func(input [63:0] val,
                                              input [ 5:0] amt,
                                              input [ 2:0] dw);
        logic [63:0] out;
        logic [5:0]  n;
        out = 64'd0;
        case (dw)
            3'd0: begin
                n = amt[2:0];
                for (int i = 0; i <= 7; i = i + 1)
                    out[i] = val[(i - n + 8) % 8];
            end
            3'd1: begin
                n = amt[3:0];
                for (int i = 0; i <= 15; i = i + 1)
                    out[i] = val[(i - n + 16) % 16];
            end
            3'd2: begin
                n = amt[4:0];
                for (int i = 0; i <= 31; i = i + 1)
                    out[i] = val[(i - n + 32) % 32];
            end
            default: begin
                n = amt[5:0];
                for (int i = 0; i <= 63; i = i + 1)
                    out[i] = val[(i - n + 64) % 64];
            end
        endcase
        rol_func = out;
    endfunction

    function automatic logic [63:0] ror_func(input [63:0] val,
                                              input [ 5:0] amt,
                                              input [ 2:0] dw);
        logic [63:0] out;
        logic [5:0]  n;
        out = 64'd0;
        case (dw)
            3'd0: begin
                n = amt[2:0];
                for (int i = 0; i <= 7; i = i + 1)
                    out[i] = val[(i + n) % 8];
            end
            3'd1: begin
                n = amt[3:0];
                for (int i = 0; i <= 15; i = i + 1)
                    out[i] = val[(i + n) % 16];
            end
            3'd2: begin
                n = amt[4:0];
                for (int i = 0; i <= 31; i = i + 1)
                    out[i] = val[(i + n) % 32];
            end
            default: begin
                n = amt[5:0];
                for (int i = 0; i <= 63; i = i + 1)
                    out[i] = val[(i + n) % 64];
            end
        endcase
        ror_func = out;
    endfunction

    // -------------------------------------------------------------------------
    // Shift helpers.  Implemented as explicit bit-level permutations
    // because iverilog mishandles >>> for signed 64-bit values, and to
    // ensure sub-word shifts (SHL/SAR with data_width < 64) correctly
    // zero / sign-extend outside the active data width.
    // -------------------------------------------------------------------------
    function automatic logic [63:0] shl_func(input [63:0] val,
                                              input [ 5:0] amt,
                                              input [ 2:0] dw);
        logic [63:0] out;
        logic [ 5:0] n;
        int          top;
        out = 64'd0;
        case (dw)
            3'd0:    begin n = {3'd0, amt[2:0]}; top = 7;  end
            3'd1:    begin n = {2'd0, amt[3:0]}; top = 15; end
            3'd2:    begin n = {1'd0, amt[4:0]}; top = 31; end
            default: begin n =        amt[5:0];  top = 63; end
        endcase
        // Shift left only within [0, top]; shift past the boundary zero
        // out the entire active width.
        if (int'(amt) > top) out = 64'd0;
        else begin
            for (int i = 0; i <= top; i = i + 1)
                if (i >= int'(n)) out[i] = val[i - int'(n)];
        end
        shl_func = out;
    endfunction

    function automatic logic [63:0] shr_func(input [63:0] val,
                                              input [ 5:0] amt,
                                              input [ 2:0] dw);
        logic [63:0] out;
        logic [ 5:0] n;
        int          top;
        out = 64'd0;
        case (dw)
            3'd0:    begin n = {3'd0, amt[2:0]}; top = 7;  end
            3'd1:    begin n = {2'd0, amt[3:0]}; top = 15; end
            3'd2:    begin n = {1'd0, amt[4:0]}; top = 31; end
            default: begin n =        amt[5:0];  top = 63; end
        endcase
        if (int'(amt) > top) out = 64'd0;
        else begin
            for (int i = 0; i <= top; i = i + 1)
                if (i + int'(n) <= top) out[i] = val[i + int'(n)];
        end
        shr_func = out;
    endfunction

    function automatic logic [63:0] sar_func(input [63:0] val,
                                              input [ 5:0] amt,
                                              input [ 2:0] dw);
        logic [63:0] out;
        logic [ 5:0] n;
        logic        sign;
        int          top;
        out = 64'd0;
        case (dw)
            3'd0:    begin n = {3'd0, amt[2:0]}; top = 7;  sign = val[7];  end
            3'd1:    begin n = {2'd0, amt[3:0]}; top = 15; sign = val[15]; end
            3'd2:    begin n = {1'd0, amt[4:0]}; top = 31; sign = val[31]; end
            default: begin n =        amt[5:0];  top = 63; sign = val[63]; end
        endcase
        for (int i = 0; i <= top; i = i + 1) begin
            if (i + int'(n) <= top) out[i] = val[i + int'(n)];
            else                     out[i] = sign;
        end
        sar_func = out;
    endfunction

    // -------------------------------------------------------------------------
    // Sign-bit helper: return the sign bit of the value as interpreted under
    // the active data width.
    // -------------------------------------------------------------------------
    function automatic logic msb_of(input [63:0] val, input [2:0] dw);
        case (dw)
            3'd0:    msb_of = val[7];
            3'd1:    msb_of = val[15];
            3'd2:    msb_of = val[31];
            default: msb_of = val[63];
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // Main ALU operation
    // -------------------------------------------------------------------------
    logic [63:0] raw_result;
    logic        raw_overflow;
    logic        raw_carry;

    always_comb begin
        raw_result   = 64'd0;
        raw_overflow = 1'b0;
        raw_carry    = 1'b0;

        case (alu_op_i)
            OP_ADD: begin
                raw_result = add_ext[63:0];
                raw_carry  = carry_bit_of(add_ext, data_width_i);
                raw_overflow = (msb_of(op_a_m, data_width_i) == msb_of(op_b_m, data_width_i))
                             && (msb_of(raw_result, data_width_i) != msb_of(op_a_m, data_width_i));
            end

            OP_SUB: begin
                raw_result = sub_ext[63:0];
                raw_carry  = ~carry_bit_of(sub_ext, data_width_i);
                raw_overflow = (msb_of(op_a_m, data_width_i) != msb_of(op_b_m, data_width_i))
                             && (msb_of(raw_result, data_width_i) != msb_of(op_a_m, data_width_i));
            end

            OP_MUL: begin
                raw_result = mul_full[63:0];
                raw_overflow = |mul_full[127:64];
            end

            OP_DIV: raw_result = div_quotient;
            OP_MOD: raw_result = div_remainder;

            OP_AND: raw_result = op_a_m & op_b_m;
            OP_OR:  raw_result = op_a_m | op_b_m;
            OP_XOR: raw_result = op_a_m ^ op_b_m;
            OP_NOT: raw_result = ~op_a_m;

            OP_SHL: raw_result = shl_func(op_a_m, shift_amt, data_width_i);
            OP_SHR: raw_result = shr_func(op_a_m, shift_amt, data_width_i);
            OP_SAR: raw_result = sar_func(op_a_m, shift_amt, data_width_i);
            OP_ROL: raw_result = rol_func(op_a_m, shift_amt, data_width_i);
            OP_ROR: raw_result = ror_func(op_a_m, shift_amt, data_width_i);

            OP_INC: begin
                raw_result = op_a_m + 64'd1;
                raw_carry  = (op_a_m == data_mask);
                raw_overflow = (msb_of(op_a_m, data_width_i) == 1'b0)
                             && (msb_of(raw_result, data_width_i) == 1'b1);
            end

            OP_DEC: begin
                raw_result = op_a_m - 64'd1;
                raw_carry  = (op_a_m == 64'd0);
                raw_overflow = (msb_of(op_a_m, data_width_i) == 1'b1)
                             && (msb_of(raw_result, data_width_i) == 1'b0);
            end

            OP_NEG: begin
                raw_result = 64'd0 - op_a_sext;
                raw_overflow = (msb_of(op_a_m, data_width_i) == 1'b1)
                             && (msb_of(raw_result, data_width_i) == 1'b1);
            end

            OP_ABS: begin
                if (msb_of(op_a_m, data_width_i))
                    raw_result = 64'd0 - op_a_sext;
                else
                    raw_result = op_a_m;
                raw_overflow = (msb_of(op_a_m, data_width_i) == 1'b1)
                             && (msb_of(raw_result, data_width_i) == 1'b1);
            end

            OP_CMP: begin
                raw_result = sub_ext[63:0];
                raw_carry  = ~carry_bit_of(sub_ext, data_width_i);
                raw_overflow = (msb_of(op_a_m, data_width_i) != msb_of(op_b_m, data_width_i))
                             && (msb_of(raw_result, data_width_i) != msb_of(op_a_m, data_width_i));
            end

            OP_TEST: begin
                raw_result = op_a_m & op_b_m;
            end

            OP_MIN:  raw_result = (op_a_sext <  op_b_sext) ? op_a_i : op_b_i;
            OP_MAX:  raw_result = (op_a_sext >  op_b_sext) ? op_a_i : op_b_i;
            OP_MINU: raw_result = (op_a_m    <  op_b_m)    ? op_a_i : op_b_i;
            OP_MAXU: raw_result = (op_a_m    >  op_b_m)    ? op_a_i : op_b_i;

            OP_CLZ:    raw_result = clz_func(op_a_m, data_width_i);
            OP_CTZ:    raw_result = ctz_func(op_a_m, data_width_i);
            OP_POPCNT: raw_result = popcnt_func(op_a_m, data_width_i);
            OP_BSWAP:  raw_result = bswap_func(op_a_m, data_width_i);
            OP_BITREV: raw_result = bitrev_func(op_a_m, data_width_i);

            OP_SEXT_B: raw_result = {{56{op_a_i[7]}}, op_a_i[7:0]};
            OP_SEXT_W: raw_result = {{48{op_a_i[15]}}, op_a_i[15:0]};
            OP_ZEXT_B: raw_result = {56'd0, op_a_i[7:0]};
            OP_ZEXT_W: raw_result = {48'd0, op_a_i[15:0]};

            default: raw_result = 64'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Output masking and flag generation
    // -------------------------------------------------------------------------
    logic [63:0] masked_result;
    assign masked_result = raw_result & data_mask;
    assign result_o      = masked_result;

    // zero / negative / overflow / carry flags.
    // Implemented with simple assigns to avoid always_comb sensitivity
    // issues in iverilog.
    assign zero_o = (masked_result == 64'd0);

    // Negative flag: MSB of current-width result.  For CMP, it's the MSB
    // of the subtract; for TEST, the MSB of the AND; else the result MSB.
    logic [63:0] cmp_and_result;
    assign cmp_and_result = (alu_op_i == 6'h12) ? sub_ext[63:0]
                          : (alu_op_i == 6'h13) ? (op_a_m & op_b_m)
                          : masked_result;

    assign negative_o = (data_width_i == 3'd0) ? cmp_and_result[7]
                      : (data_width_i == 3'd1) ? cmp_and_result[15]
                      : (data_width_i == 3'd2) ? cmp_and_result[31]
                      : cmp_and_result[63];

    assign overflow_o = raw_overflow;
    assign carry_o    = raw_carry;

endmodule
