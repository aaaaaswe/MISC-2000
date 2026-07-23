// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0

module tb_alu;

    // -------------------------------------------------------------------------
    // Parameters / Localparams
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 10;   // 10 ns clock period

    // Data width encodings
    localparam logic [2:0] DW_B = 3'd0;  // 8-bit Byte
    localparam logic [2:0] DW_W = 3'd1;  // 16-bit Word
    localparam logic [2:0] DW_D = 3'd2;  // 32-bit Double-word
    localparam logic [2:0] DW_Q = 3'd3;  // 64-bit Quad-word

    // ALU opcodes
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

    // Data width masks
    localparam logic [63:0] MASK_B = 64'h00000000000000FF;
    localparam logic [63:0] MASK_W = 64'h000000000000FFFF;
    localparam logic [63:0] MASK_D = 64'h00000000FFFFFFFF;
    localparam logic [63:0] MASK_Q = 64'hFFFFFFFFFFFFFFFF;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk;
    logic [63:0] op_a;
    logic [63:0] op_b;
    logic [ 5:0] alu_op;
    logic [ 2:0] data_width;
    logic [63:0] result;
    logic        zero;
    logic        negative;
    logic        overflow;
    logic        carry;

    // -------------------------------------------------------------------------
    // Test infrastructure
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    misc_alu u_dut (
        .op_a_i      (op_a),
        .op_b_i      (op_b),
        .alu_op_i    (alu_op),
        .data_width_i(data_width),
        .result_o    (result),
        .zero_o      (zero),
        .negative_o  (negative),
        .overflow_o  (overflow),
        .carry_o     (carry)
    );

    // -------------------------------------------------------------------------
    // Helper: get data mask for a given data width
    // -------------------------------------------------------------------------
    function automatic logic [63:0] get_mask(input logic [2:0] dw);
        case (dw)
            DW_B: get_mask = MASK_B;
            DW_W: get_mask = MASK_W;
            DW_D: get_mask = MASK_D;
            default: get_mask = MASK_Q;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // Helper: get MSB position for a given data width
    // -------------------------------------------------------------------------
    function automatic int get_msb(input logic [2:0] dw);
        case (dw)
            DW_B: get_msb = 7;
            DW_W: get_msb = 15;
            DW_D: get_msb = 31;
            default: get_msb = 63;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // Apply stimulus and wait one clock cycle
    // -------------------------------------------------------------------------
    task automatic apply_op(
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [ 5:0] op,
        input logic [ 2:0] dw
    );
        op_a       <= a;
        op_b       <= b;
        alu_op     <= op;
        data_width <= dw;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Check result and flags; report pass/fail
    // 'chk_flags' is a 4-bit mask: {chk_zero, chk_neg, chk_ovf, chk_carry}
    // When a bit is 1, the corresponding flag is verified against expected.
    // When a bit is 0, that flag is not checked (don't-care).
    // -------------------------------------------------------------------------
    task automatic check(
        input string      test_name,
        input logic [63:0] exp_result,
        input logic [3:0] chk_flags,
        input logic        exp_zero,
        input logic        exp_neg,
        input logic        exp_ovf,
        input logic        exp_carry
    );
        logic pass;
        pass = 1'b1;

        if (result !== exp_result) begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       op_a=0x%016h  op_b=0x%016h  op=%02h  dw=%0d",
                     op_a, op_b, alu_op, data_width);
            $display("       Result:  expected 0x%016h, got 0x%016h",
                     exp_result, result);
            pass = 1'b0;
        end

        if (chk_flags[3] && (zero !== exp_zero)) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       zero_o:  expected %b, got %b", exp_zero, zero);
            pass = 1'b0;
        end

        if (chk_flags[2] && (negative !== exp_neg)) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       negative_o:  expected %b, got %b", exp_neg, negative);
            pass = 1'b0;
        end

        if (chk_flags[1] && (overflow !== exp_ovf)) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       overflow_o:  expected %b, got %b", exp_ovf, overflow);
            pass = 1'b0;
        end

        if (chk_flags[0] && (carry !== exp_carry)) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       carry_o:  expected %b, got %b", exp_carry, carry);
            pass = 1'b0;
        end

        if (pass) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
        end

        test_num = test_num + 1;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Shorthand: check all 4 flags
    // -------------------------------------------------------------------------
    task automatic check_all(
        input string      test_name,
        input logic [63:0] exp_result,
        input logic        exp_zero,
        input logic        exp_neg,
        input logic        exp_ovf,
        input logic        exp_carry
    );
        check(test_name, exp_result, 4'b1111, exp_zero, exp_neg, exp_ovf, exp_carry);
    endtask

    // -------------------------------------------------------------------------
    // Shorthand: check result only (flags don't-care)
    // -------------------------------------------------------------------------
    task automatic check_result_only(
        input string      test_name,
        input logic [63:0] exp_result
    );
        check(test_name, exp_result, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b0);
    endtask

    // -------------------------------------------------------------------------
    // Combined: apply_op + check_all
    // -------------------------------------------------------------------------
    task automatic test_op(
        input string      test_name,
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [ 5:0] op,
        input logic [ 2:0] dw,
        input logic [63:0] exp_result,
        input logic        exp_zero,
        input logic        exp_neg,
        input logic        exp_ovf,
        input logic        exp_carry
    );
        apply_op(a, b, op, dw);
        check_all(test_name, exp_result, exp_zero, exp_neg, exp_ovf, exp_carry);
    endtask

    // -------------------------------------------------------------------------
    // Combined: apply_op + check_result_only
    // -------------------------------------------------------------------------
    task automatic test_op_result(
        input string      test_name,
        input logic [63:0] a,
        input logic [63:0] b,
        input logic [ 5:0] op,
        input logic [ 2:0] dw,
        input logic [63:0] exp_result
    );
        apply_op(a, b, op, dw);
        check_result_only(test_name, exp_result);
    endtask

    // =====================================================================
    // MAIN TEST SEQUENCE
    // =====================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        $display("============================================================");
        $display(" MISC-2000 ALU Testbench");
        $display("============================================================");

        // Wait for reset / initialization
        @(posedge clk);
        @(posedge clk);

        // -----------------------------------------------------------------
        // ADD tests
        // -----------------------------------------------------------------
        $display("\n--- ADD Tests ---");

        // ADD: 0x42 + 0x13 = 0x55 (all widths)
        test_op("ADD 0x42+0x13 (B)", 64'h42, 64'h13, OP_ADD, DW_B,
                64'h55, 1'b0, 1'b0, 1'b0, 1'b0);
        test_op("ADD 0x42+0x13 (W)", 64'h42, 64'h13, OP_ADD, DW_W,
                64'h55, 1'b0, 1'b0, 1'b0, 1'b0);
        test_op("ADD 0x42+0x13 (D)", 64'h42, 64'h13, OP_ADD, DW_D,
                64'h55, 1'b0, 1'b0, 1'b0, 1'b0);
        test_op("ADD 0x42+0x13 (Q)", 64'h42, 64'h13, OP_ADD, DW_Q,
                64'h55, 1'b0, 1'b0, 1'b0, 1'b0);

        // ADD: 0xFFFFFFFF + 0x1 = carry (D/32-bit width)
        test_op("ADD 0xFFFFFFFF+0x1 carry (D)", 64'hFFFFFFFF, 64'h1, OP_ADD, DW_D,
                (64'hFFFFFFFF + 64'h1) & MASK_D,  // 0x00000000
                1'b1, 1'b0, 1'b0, 1'b1);

        // ADD: 0xFFFFFFFF + 0x1 (Q/64-bit width)
        test_op("ADD 0xFFFFFFFF+0x1 (Q)", 64'hFFFFFFFF, 64'h1, OP_ADD, DW_Q,
                64'h100000000, 1'b0, 1'b0, 1'b0, 1'b0);

        // ADD: negative + positive
        test_op("ADD -5 + 3 (D)", 64'hFFFFFFFB, 64'h3, OP_ADD, DW_D,
                (64'hFFFFFFFB + 64'h3) & MASK_D, 1'b0, 1'b1, 1'b0, 1'b0);

        // ADD: 0x80 + 0x80 = 0x00 with overflow (B/8-bit signed)
        test_op("ADD 0x80+0x80 overflow (B)", 64'h80, 64'h80, OP_ADD, DW_B,
                64'h00, 1'b1, 1'b0, 1'b1, 1'b1);

        // ADD: 0x7FFF + 0x1 = 0x8000 overflow (W/16-bit)
        test_op("ADD 0x7FFF+0x1 overflow (W)", 64'h7FFF, 64'h1, OP_ADD, DW_W,
                64'h8000, 1'b0, 1'b1, 1'b1, 1'b0);

        // ADD: produces zero
        test_op("ADD -1 + 1 = 0 (D)", 64'hFFFFFFFF, 64'h1, OP_ADD, DW_D,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b1);

        // -----------------------------------------------------------------
        // SUB tests
        // -----------------------------------------------------------------
        $display("\n--- SUB Tests ---");

        // SUB: 0x55 - 0x13 = 0x42
        test_op("SUB 0x55-0x13 (D)", 64'h55, 64'h13, OP_SUB, DW_D,
                64'h42, 1'b0, 1'b0, 1'b0, 1'b1);

        // SUB: 0x0 - 0x1 = underflow (borrow)
        // With 32-bit width: 0 - 1 = 0xFFFFFFFF, carry(borrow)=0
        test_op("SUB 0-1 underflow (D)", 64'h0, 64'h1, OP_SUB, DW_D,
                (64'h0 - 64'h1) & MASK_D, 1'b0, 1'b1, 1'b0, 1'b0);

        // SUB: produces zero
        test_op("SUB 0x42-0x42 = 0 (D)", 64'h42, 64'h42, OP_SUB, DW_D,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b1);

        // SUB: signed overflow (positive - negative with sign change)
        test_op("SUB 0x7FFFFFFF - (-1) overflow (D)",
                64'h000000007FFFFFFF, 64'h00000000FFFFFFFF, OP_SUB, DW_D,
                (64'h7FFFFFFF - 64'hFFFFFFFF) & MASK_D, 1'b0, 1'b1, 1'b1, 1'b0);

        // SUB: 0x80000000 - 0x1 = 0x7FFFFFFF overflow (D)
        test_op("SUB 0x80000000-1 overflow (D)",
                64'h0000000080000000, 64'h1, OP_SUB, DW_D,
                64'h000000007FFFFFFF, 1'b0, 1'b0, 1'b1, 1'b1);

        // -----------------------------------------------------------------
        // MUL tests
        // -----------------------------------------------------------------
        $display("\n--- MUL Tests ---");

        // MUL: 0x6 * 0x7 = 0x2A
        apply_op(64'h6, 64'h7, OP_MUL, DW_Q);
        check_result_only("MUL 0x6*0x7=0x2A (Q)", 64'h2A);

        // MUL: 0x10000 * 0x10000 = 0x100000000
        apply_op(64'h10000, 64'h10000, OP_MUL, DW_Q);
        check_all("MUL 0x10000*0x10000=0x100000000 (Q)",
                  64'h100000000, 1'b0, 1'b0, 1'b0, 1'b0);

        // MUL: overflow (product > 64 bits)
        apply_op(64'h100000000, 64'h100000000, OP_MUL, DW_Q);
        check_all("MUL overflow (Q)", (64'h100000000 * 64'h100000000),
                  1'b1, 1'b0, 1'b1, 1'b0);

        // MUL: zero result
        test_op("MUL 0*0x100 = 0 (Q)", 64'h0, 64'h100, OP_MUL, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // MUL: with data width D
        apply_op(64'h3, 64'h5, OP_MUL, DW_D);
        check_result_only("MUL 3*5=15 (D)", 64'hF);

        // MUL: with data width B
        apply_op(64'h4, 64'h4, OP_MUL, DW_B);
        check_result_only("MUL 4*4=16 (B)", 64'h10);

        // -----------------------------------------------------------------
        // DIV tests
        // -----------------------------------------------------------------
        $display("\n--- DIV Tests ---");

        // DIV: 0x64 / 0xA = 0xA
        test_op("DIV 0x64/0xA=0xA (Q)", 64'h64, 64'hA, OP_DIV, DW_Q,
                64'hA, 1'b0, 1'b0, 1'b0, 1'b0);

        // DIV: division by zero -> result = 0
        test_op("DIV by zero (Q)", 64'h100, 64'h0, OP_DIV, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // DIV: 0xFFFFFFFF / 0x2 (D width)
        apply_op(64'hFFFFFFFF, 64'h2, OP_DIV, DW_D);
        check_result_only("DIV 0xFFFFFFFF/2 (D)", (64'hFFFFFFFF / 64'h2) & MASK_D);

        // DIV: result = 0 (numerator smaller than denominator)
        test_op("DIV 0x1/0xA = 0 (Q)", 64'h1, 64'hA, OP_DIV, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // DIV: negative division
        apply_op(64'hFFFFFFFFFFFFFFF6, 64'h2, OP_DIV, DW_Q);
        check_result_only("DIV -10/2 (Q)", 64'hFFFFFFFFFFFFFFF6 / 64'h2);

        // -----------------------------------------------------------------
        // MOD tests
        // -----------------------------------------------------------------
        $display("\n--- MOD Tests ---");

        // MOD: 0x64 % 0xA = 0x0
        test_op("MOD 0x64%%0xA=0 (Q)", 64'h64, 64'hA, OP_MOD, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // MOD: modulo by zero -> result = 0
        test_op("MOD by zero (Q)", 64'h100, 64'h0, OP_MOD, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // MOD: 0x64 % 0x7 = 0x2
        apply_op(64'h64, 64'h7, OP_MOD, DW_Q);
        check_result_only("MOD 0x64%%7=2 (Q)", 64'h2);

        // MOD: 0xFFFFFFFF % 0x10 (D width)
        apply_op(64'hFFFFFFFF, 64'h10, OP_MOD, DW_D);
        check_result_only("MOD 0xFFFFFFFF%%0x10 (D)", (64'hFFFFFFFF % 64'h10) & MASK_D);

        // MOD: negative modulo
        apply_op(64'hFFFFFFFFFFFFFFF6, 64'h3, OP_MOD, DW_Q);
        check_result_only("MOD -10%%3 (Q)", 64'hFFFFFFFFFFFFFFF6 % 64'h3);

        // -----------------------------------------------------------------
        // AND tests
        // -----------------------------------------------------------------
        $display("\n--- AND Tests ---");

        test_op("AND 0xFF & 0x0F = 0x0F (Q)", 64'hFF, 64'h0F, OP_AND, DW_Q,
                64'h0F, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("AND 0xF0 & 0x0F = 0 (Q)", 64'hF0, 64'h0F, OP_AND, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        test_op("AND 0xAA & 0x55 = 0 (Q)", 64'hAA, 64'h55, OP_AND, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        test_op("AND 0xFF & 0xFF = 0xFF (B)", 64'hFF, 64'hFF, OP_AND, DW_B,
                64'hFF, 1'b0, 1'b1, 1'b0, 1'b0);

        // -----------------------------------------------------------------
        // OR tests
        // -----------------------------------------------------------------
        $display("\n--- OR Tests ---");

        test_op("OR 0xF0 | 0x0F = 0xFF (Q)", 64'hF0, 64'h0F, OP_OR, DW_Q,
                64'hFF, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("OR 0x0 | 0x0 = 0 (Q)", 64'h0, 64'h0, OP_OR, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        test_op("OR 0x8000 | 0x0 = 0x8000 (W)", 64'h8000, 64'h0, OP_OR, DW_W,
                64'h8000, 1'b0, 1'b1, 1'b0, 1'b0);

        // -----------------------------------------------------------------
        // XOR tests
        // -----------------------------------------------------------------
        $display("\n--- XOR Tests ---");

        test_op("XOR 0xFF ^ 0x0F = 0xF0 (Q)", 64'hFF, 64'h0F, OP_XOR, DW_Q,
                64'hF0, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("XOR 0xAA ^ 0xAA = 0 (Q)", 64'hAA, 64'hAA, OP_XOR, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        test_op("XOR 0x0 ^ 0x0 = 0 (Q)", 64'h0, 64'h0, OP_XOR, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // -----------------------------------------------------------------
        // NOT tests
        // -----------------------------------------------------------------
        $display("\n--- NOT Tests ---");

        apply_op(64'hFFFFFFFF00000000, 64'h0, OP_NOT, DW_Q);
        check_result_only("NOT 0xFFFFFFFF00000000 (Q)", ~64'hFFFFFFFF00000000);

        apply_op(64'h0, 64'h0, OP_NOT, DW_Q);
        check_all("NOT 0 = 0xFFFFFFFFFFFFFFFF (Q)", ~64'h0, 1'b0, 1'b1, 1'b0, 1'b0);

        apply_op(64'hAA, 64'h0, OP_NOT, DW_B);
        check_result_only("NOT 0xAA (B)", (~64'hAA) & MASK_B);

        // -----------------------------------------------------------------
        // SHL tests
        // -----------------------------------------------------------------
        $display("\n--- SHL Tests ---");

        test_op("SHL 0x1 << 4 = 0x10 (Q)", 64'h1, 64'h4, OP_SHL, DW_Q,
                64'h10, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("SHL 0x1 << 0 = 0x1 (Q)", 64'h1, 64'h0, OP_SHL, DW_Q,
                64'h1, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("SHL 0x1 << 63 (Q)", 64'h1, 64'd63, OP_SHL, DW_Q,
                64'h8000000000000000, 1'b0, 1'b1, 1'b0, 1'b0);

        // SHL with B width: 0x01 << 5 = 0x20
        test_op("SHL 0x1 << 5 (B)", 64'h1, 64'h5, OP_SHL, DW_B,
                64'h20, 1'b0, 1'b0, 1'b0, 1'b0);

        // SHL with B width: shift past boundary gets masked
        test_op("SHL 0x1 << 7 (B)", 64'h1, 64'h7, OP_SHL, DW_B,
                64'h80, 1'b0, 1'b1, 1'b0, 1'b0);

        // SHL: shift amount larger than width, B width
        apply_op(64'h1, 64'h10, OP_SHL, DW_B);
        check_result_only("SHL 0x1 << 16 (B, shift amount masked)", 64'h1);

        // -----------------------------------------------------------------
        // SHR tests
        // -----------------------------------------------------------------
        $display("\n--- SHR Tests ---");

        test_op("SHR 0x80 >> 4 = 0x08 (Q)", 64'h80, 64'h4, OP_SHR, DW_Q,
                64'h8, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("SHR 0x8000 >> 8 = 0x80 (W)", 64'h8000, 64'h8, OP_SHR, DW_W,
                64'h80, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("SHR 0x1 >> 1 = 0 (Q)", 64'h1, 64'h1, OP_SHR, DW_Q,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // -----------------------------------------------------------------
        // SAR tests (arithmetic shift right)
        // -----------------------------------------------------------------
        $display("\n--- SAR Tests ---");

        // SAR: sign extends from MSB of data width
        test_op("SAR 0x80 >> 4 = 0xF8 (B)", 64'h80, 64'h4, OP_SAR, DW_B,
                ({{56{1'b1}}, 8'h80} >> 4) & MASK_B, 1'b0, 1'b1, 1'b0, 1'b0);

        test_op("SAR 0x40 >> 2 = 0x10 (B)", 64'h40, 64'h2, OP_SAR, DW_B,
                ({{56{1'b0}}, 8'h40} >> 2) & MASK_B, 1'b0, 1'b0, 1'b0, 1'b0);

        // SAR: positive value in 64-bit
        apply_op(64'h4000000000000000, 64'd32, OP_SAR, DW_Q);
        check_result_only("SAR 0x400...0 >> 32 (Q)", $signed(64'h4000000000000000) >>> 32);

        // SAR: negative value in 64-bit
        apply_op(64'h8000000000000000, 64'd4, OP_SAR, DW_Q);
        check_result_only("SAR 0x800...0 >> 4 (Q)", $signed(64'h8000000000000000) >>> 4);

        // -----------------------------------------------------------------
        // ROL tests
        // -----------------------------------------------------------------
        $display("\n--- ROL Tests ---");

        // ROL: B width (8-bit), 0x01 <<< 1 = 0x02
        apply_op(64'h01, 64'h1, OP_ROL, DW_B);
        check_result_only("ROL 0x01 <<< 1 (B)", 64'h02);

        // ROL: B width, 0x80 <<< 1 = 0x01 (wraps around)
        apply_op(64'h80, 64'h1, OP_ROL, DW_B);
        check_result_only("ROL 0x80 <<< 1 (B, wrap)", 64'h01);

        // ROL: Q width, 0x8000000000000000 <<< 1 = 0x1
        apply_op(64'h8000000000000000, 64'h1, OP_ROL, DW_Q);
        check_result_only("ROL 0x800...0 <<< 1 (Q, wrap)", 64'h1);

        // ROL: W width
        apply_op(64'h0001, 64'h1, OP_ROL, DW_W);
        check_result_only("ROL 0x0001 <<< 1 (W)", 64'h0002);

        // ROL: W width wrap
        apply_op(64'h8000, 64'h1, OP_ROL, DW_W);
        check_result_only("ROL 0x8000 <<< 1 (W, wrap)", 64'h0001);

        // -----------------------------------------------------------------
        // ROR tests
        // -----------------------------------------------------------------
        $display("\n--- ROR Tests ---");

        // ROR: B width, 0x01 >>> 1 = 0x80
        apply_op(64'h01, 64'h1, OP_ROR, DW_B);
        check_result_only("ROR 0x01 >>> 1 (B, wrap)", 64'h80);

        // ROR: B width, 0x02 >>> 1 = 0x01
        apply_op(64'h02, 64'h1, OP_ROR, DW_B);
        check_result_only("ROR 0x02 >>> 1 (B)", 64'h01);

        // ROR: Q width
        apply_op(64'h1, 64'h1, OP_ROR, DW_Q);
        check_result_only("ROR 0x1 >>> 1 (Q, wrap)", 64'h8000000000000000);

        // -----------------------------------------------------------------
        // INC tests
        // -----------------------------------------------------------------
        $display("\n--- INC Tests ---");

        test_op("INC 0x41 = 0x42 (Q)", 64'h41, 64'h0, OP_INC, DW_Q,
                64'h42, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("INC 0xFFFFFFFF = 0x0 (D, carry)", 64'hFFFFFFFF, 64'h0, OP_INC, DW_D,
                64'h0, 1'b1, 1'b0, 1'b0, 1'b1);

        test_op("INC 0xFF = 0x00 (B, carry)", 64'hFF, 64'h0, OP_INC, DW_B,
                64'h00, 1'b1, 1'b0, 1'b0, 1'b1);

        test_op("INC 0x7F = 0x80 (B, overflow)", 64'h7F, 64'h0, OP_INC, DW_B,
                64'h80, 1'b0, 1'b1, 1'b1, 1'b0);

        // -----------------------------------------------------------------
        // DEC tests
        // -----------------------------------------------------------------
        $display("\n--- DEC Tests ---");

        test_op("DEC 0x43 = 0x42 (Q)", 64'h43, 64'h0, OP_DEC, DW_Q,
                64'h42, 1'b0, 1'b0, 1'b0, 1'b0);

        test_op("DEC 0x0 = 0xFFFFFFFF (D, borrow)", 64'h0, 64'h0, OP_DEC, DW_D,
                (64'h0 - 64'h1) & MASK_D, 1'b0, 1'b1, 1'b0, 1'b1);

        test_op("DEC 0x0 = 0xFF (B, borrow)", 64'h0, 64'h0, OP_DEC, DW_B,
                64'hFF, 1'b0, 1'b1, 1'b0, 1'b1);

        test_op("DEC 0x80 = 0x7F (B, overflow)", 64'h80, 64'h0, OP_DEC, DW_B,
                64'h7F, 1'b0, 1'b0, 1'b1, 1'b0);

        // -----------------------------------------------------------------
        // NEG tests
        // -----------------------------------------------------------------
        $display("\n--- NEG Tests ---");

        apply_op(64'h5, 64'h0, OP_NEG, DW_Q);
        check_result_only("NEG 5 = -5 (Q)", 64'hFFFFFFFFFFFFFFFB);

        apply_op(64'hFFFFFFFFFFFFFFFB, 64'h0, OP_NEG, DW_Q);
        check_result_only("NEG -5 = 5 (Q)", 64'h5);

        apply_op(64'h0, 64'h0, OP_NEG, DW_Q);
        check_all("NEG 0 = 0 (Q)", 64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // NEG: most negative 8-bit value (-128) overflow
        apply_op(64'h80, 64'h0, OP_NEG, DW_B);
        // -128 negated in 8-bit is still 0x80 (with overflow)
        check_all("NEG 0x80 overflow (B)", 64'h80, 1'b0, 1'b1, 1'b1, 1'b0);

        // -----------------------------------------------------------------
        // ABS tests
        // -----------------------------------------------------------------
        $display("\n--- ABS Tests ---");

        apply_op(64'h5, 64'h0, OP_ABS, DW_Q);
        check_result_only("ABS 5 = 5 (Q)", 64'h5);

        apply_op(64'hFFFFFFFFFFFFFFFB, 64'h0, OP_ABS, DW_Q);
        check_result_only("ABS -5 = 5 (Q)", 64'h5);

        apply_op(64'h0, 64'h0, OP_ABS, DW_Q);
        check_all("ABS 0 = 0 (Q)", 64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // ABS: most negative 8-bit value (-128) overflow
        apply_op(64'h80, 64'h0, OP_ABS, DW_B);
        check_all("ABS 0x80 overflow (B)", 64'h80, 1'b0, 1'b1, 1'b1, 1'b0);

        // -----------------------------------------------------------------
        // CMP tests (result is always 0, flags come from subtraction)
        // -----------------------------------------------------------------
        $display("\n--- CMP Tests ---");

        // CMP: equal -> zero flag set
        apply_op(64'h42, 64'h42, OP_CMP, DW_Q);
        check_all("CMP 0x42 == 0x42 (Q)", 64'h0, 1'b1, 1'b0, 1'b0, 1'b1);

        // CMP: a > b -> no flags
        apply_op(64'h43, 64'h42, OP_CMP, DW_Q);
        check_all("CMP 0x43 > 0x42 (Q)", 64'h0, 1'b0, 1'b0, 1'b0, 1'b1);

        // CMP: a < b -> negative flag set
        apply_op(64'h41, 64'h42, OP_CMP, DW_Q);
        check_all("CMP 0x41 < 0x42 (Q)", 64'h0, 1'b0, 1'b1, 1'b0, 1'b0);

        // CMP: signed comparison, -1 < 0
        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_CMP, DW_Q);
        check_all("CMP -1 < 0 (Q)", 64'h0, 1'b0, 1'b1, 1'b0, 1'b1);

        // CMP: signed comparison, 0 > -1
        apply_op(64'h0, 64'hFFFFFFFFFFFFFFFF, OP_CMP, DW_Q);
        check_all("CMP 0 > -1 (Q)", 64'h0, 1'b0, 1'b0, 1'b0, 1'b0);

        // CMP: B width
        apply_op(64'h7F, 64'h80, OP_CMP, DW_B);
        // 0x7F (127) vs 0x80 (-128 signed): 127 - (-128) overflows to -1 in 8-bit
        check_all("CMP 127 > -128 (B)", 64'h0, 1'b0, 1'b1, 1'b1, 1'b0);

        // -----------------------------------------------------------------
        // TEST tests (result is always 0, flags from AND)
        // -----------------------------------------------------------------
        $display("\n--- TEST Tests ---");

        // TEST: all bits match -> negative depends on AND result bit
        apply_op(64'hFF, 64'hFF, OP_TEST, DW_B);
        check_all("TEST 0xFF & 0xFF (B)", 64'h0, 1'b0, 1'b1, 1'b0, 1'b0);

        // TEST: no bits in common -> zero
        apply_op(64'hF0, 64'h0F, OP_TEST, DW_Q);
        check_all("TEST 0xF0 & 0x0F (Q)", 64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // TEST: some bits in common, not all
        apply_op(64'hAA, 64'hA0, OP_TEST, DW_B);
        check_all("TEST 0xAA & 0xA0 (B)", 64'h0, 1'b0, 1'b1, 1'b0, 1'b0);

        // TEST: MSB set in both operands -> negative
        apply_op(64'h8000000000000000, 64'h8000000000000000, OP_TEST, DW_Q);
        check_all("TEST MSB (Q)", 64'h0, 1'b0, 1'b1, 1'b0, 1'b0);

        // TEST: W width
        apply_op(64'h0000, 64'hFFFF, OP_TEST, DW_W);
        check_all("TEST 0x0000 & 0xFFFF (W)", 64'h0, 1'b1, 1'b0, 1'b0, 1'b0);

        // -----------------------------------------------------------------
        // MIN tests (signed)
        // -----------------------------------------------------------------
        $display("\n--- MIN Tests ---");

        apply_op(64'h5, 64'hA, OP_MIN, DW_Q);
        check_result_only("MIN signed 5,10 = 5 (Q)", 64'h5);

        apply_op(64'hA, 64'h5, OP_MIN, DW_Q);
        check_result_only("MIN signed 10,5 = 5 (Q)", 64'h5);

        apply_op(64'hFFFFFFFFFFFFFFFB, 64'h5, OP_MIN, DW_Q);  // -5 vs 5
        check_result_only("MIN signed -5,5 = -5 (Q)", 64'hFFFFFFFFFFFFFFFB);

        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_MIN, DW_Q);  // -1 vs 0
        check_result_only("MIN signed -1,0 = -1 (Q)", 64'hFFFFFFFFFFFFFFFF);

        // MIN: B width, 0x80 (-128) vs 0x7F (127)
        apply_op(64'h80, 64'h7F, OP_MIN, DW_B);
        check_result_only("MIN signed -128,127 = -128 (B)", 64'h80);

        // -----------------------------------------------------------------
        // MAX tests (signed)
        // -----------------------------------------------------------------
        $display("\n--- MAX Tests ---");

        apply_op(64'h5, 64'hA, OP_MAX, DW_Q);
        check_result_only("MAX signed 5,10 = 10 (Q)", 64'hA);

        apply_op(64'hA, 64'h5, OP_MAX, DW_Q);
        check_result_only("MAX signed 10,5 = 10 (Q)", 64'hA);

        apply_op(64'hFFFFFFFFFFFFFFFB, 64'h5, OP_MAX, DW_Q);  // -5 vs 5
        check_result_only("MAX signed -5,5 = 5 (Q)", 64'h5);

        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_MAX, DW_Q);  // -1 vs 0
        check_result_only("MAX signed -1,0 = 0 (Q)", 64'h0);

        // -----------------------------------------------------------------
        // MINU tests (unsigned)
        // -----------------------------------------------------------------
        $display("\n--- MINU Tests ---");

        apply_op(64'h5, 64'hA, OP_MINU, DW_Q);
        check_result_only("MINU 5,10 = 5 (Q)", 64'h5);

        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_MINU, DW_Q);
        check_result_only("MINU MAX,0 = 0 (Q)", 64'h0);

        apply_op(64'hFF, 64'h7F, OP_MINU, DW_B);
        check_result_only("MINU 255,127 = 127 (B)", 64'h7F);

        // -----------------------------------------------------------------
        // MAXU tests (unsigned)
        // -----------------------------------------------------------------
        $display("\n--- MAXU Tests ---");

        apply_op(64'h5, 64'hA, OP_MAXU, DW_Q);
        check_result_only("MAXU 5,10 = 10 (Q)", 64'hA);

        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_MAXU, DW_Q);
        check_result_only("MAXU MAX,0 = MAX (Q)", 64'hFFFFFFFFFFFFFFFF);

        apply_op(64'hFF, 64'h7F, OP_MAXU, DW_B);
        check_result_only("MAXU 255,127 = 255 (B)", 64'hFF);

        // -----------------------------------------------------------------
        // CLZ tests (count leading zeros)
        // -----------------------------------------------------------------
        $display("\n--- CLZ Tests ---");

        // CLZ: B width, 0x01 = 7 leading zeros in 8-bit
        apply_op(64'h01, 64'h0, OP_CLZ, DW_B);
        check_result_only("CLZ 0x01 (B) = 7", 64'd7);

        // CLZ: B width, 0x80 = 0 leading zeros
        apply_op(64'h80, 64'h0, OP_CLZ, DW_B);
        check_result_only("CLZ 0x80 (B) = 0", 64'd0);

        // CLZ: B width, 0x00 = 8 leading zeros
        apply_op(64'h00, 64'h0, OP_CLZ, DW_B);
        check_result_only("CLZ 0x00 (B) = 8", 64'd8);

        // CLZ: Q width
        apply_op(64'h1, 64'h0, OP_CLZ, DW_Q);
        check_result_only("CLZ 0x1 (Q) = 63", 64'd63);

        // CLZ: Q width, 0x8000000000000000 = 0
        apply_op(64'h8000000000000000, 64'h0, OP_CLZ, DW_Q);
        check_result_only("CLZ 0x800...0 (Q) = 0", 64'd0);

        // CLZ: Q width, all zeros
        apply_op(64'h0, 64'h0, OP_CLZ, DW_Q);
        check_result_only("CLZ 0x0 (Q) = 64", 64'd64);

        // CLZ: W width, 0x0001 = 15
        apply_op(64'h0001, 64'h0, OP_CLZ, DW_W);
        check_result_only("CLZ 0x0001 (W) = 15", 64'd15);

        // -----------------------------------------------------------------
        // CTZ tests (count trailing zeros)
        // -----------------------------------------------------------------
        $display("\n--- CTZ Tests ---");

        // CTZ: B width, 0x80 = 7 trailing zeros
        apply_op(64'h80, 64'h0, OP_CTZ, DW_B);
        check_result_only("CTZ 0x80 (B) = 7", 64'd7);

        // CTZ: B width, 0x01 = 0 trailing zeros
        apply_op(64'h01, 64'h0, OP_CTZ, DW_B);
        check_result_only("CTZ 0x01 (B) = 0", 64'd0);

        // CTZ: B width, 0x00 = 8 trailing zeros
        apply_op(64'h00, 64'h0, OP_CTZ, DW_B);
        check_result_only("CTZ 0x00 (B) = 8", 64'd8);

        // CTZ: Q width
        apply_op(64'h8000000000000000, 64'h0, OP_CTZ, DW_Q);
        check_result_only("CTZ 0x800...0 (Q) = 63", 64'd63);

        // CTZ: Q width, 0x1 = 0
        apply_op(64'h1, 64'h0, OP_CTZ, DW_Q);
        check_result_only("CTZ 0x1 (Q) = 0", 64'd0);

        // CTZ: D width, 0x00000010 = 4
        apply_op(64'h00000010, 64'h0, OP_CTZ, DW_D);
        check_result_only("CTZ 0x10 (D) = 4", 64'd4);

        // -----------------------------------------------------------------
        // POPCNT tests (population count)
        // -----------------------------------------------------------------
        $display("\n--- POPCNT Tests ---");

        // POPCNT: B width, 0xFF = 8 bits set
        apply_op(64'hFF, 64'h0, OP_POPCNT, DW_B);
        check_result_only("POPCNT 0xFF (B) = 8", 64'd8);

        // POPCNT: B width, 0x00 = 0
        apply_op(64'h00, 64'h0, OP_POPCNT, DW_B);
        check_result_only("POPCNT 0x00 (B) = 0", 64'd0);

        // POPCNT: Q width, 0xAAAAAAAAAAAAAAAA = 32
        apply_op(64'hAAAAAAAAAAAAAAAA, 64'h0, OP_POPCNT, DW_Q);
        check_result_only("POPCNT 0xAA... (Q) = 32", 64'd32);

        // POPCNT: Q width, 0xFFFFFFFFFFFFFFFF = 64
        apply_op(64'hFFFFFFFFFFFFFFFF, 64'h0, OP_POPCNT, DW_Q);
        check_result_only("POPCNT 0xFF... (Q) = 64", 64'd64);

        // POPCNT: D width, 0x0000FFFF = 16
        apply_op(64'h0000FFFF, 64'h0, OP_POPCNT, DW_D);
        check_result_only("POPCNT 0x0000FFFF (D) = 16", 64'd16);

        // -----------------------------------------------------------------
        // BSWAP tests (byte swap)
        // -----------------------------------------------------------------
        $display("\n--- BSWAP Tests ---");

        // BSWAP: B width, just returns the same byte (single byte)
        apply_op(64'hAB, 64'h0, OP_BSWAP, DW_B);
        check_result_only("BSWAP 0xAB (B)", 64'hAB);

        // BSWAP: W width, 0xABCD -> 0xCDAB
        apply_op(64'hABCD, 64'h0, OP_BSWAP, DW_W);
        check_result_only("BSWAP 0xABCD (W)", 64'hCDAB);

        // BSWAP: D width, 0x01234567 -> 0x67452301
        apply_op(64'h01234567, 64'h0, OP_BSWAP, DW_D);
        check_result_only("BSWAP 0x01234567 (D)", 64'h67452301);

        // BSWAP: Q width, 0x0123456789ABCDEF -> 0xEFCDAB8967452301
        apply_op(64'h0123456789ABCDEF, 64'h0, OP_BSWAP, DW_Q);
        check_result_only("BSWAP 0x0123456789ABCDEF (Q)", 64'hEFCDAB8967452301);

        // BSWAP: 0
        apply_op(64'h0, 64'h0, OP_BSWAP, DW_Q);
        check_result_only("BSWAP 0 (Q)", 64'h0);

        // -----------------------------------------------------------------
        // BITREV tests (bit reverse)
        // -----------------------------------------------------------------
        $display("\n--- BITREV Tests ---");

        // BITREV: B width, 0x01 (00000001) -> 0x80 (10000000)
        apply_op(64'h01, 64'h0, OP_BITREV, DW_B);
        check_result_only("BITREV 0x01 (B) = 0x80", 64'h80);

        // BITREV: B width, 0x80 -> 0x01
        apply_op(64'h80, 64'h0, OP_BITREV, DW_B);
        check_result_only("BITREV 0x80 (B) = 0x01", 64'h01);

        // BITREV: B width, 0xAA (10101010) -> 0x55 (01010101)
        apply_op(64'hAA, 64'h0, OP_BITREV, DW_B);
        check_result_only("BITREV 0xAA (B) = 0x55", 64'h55);

        // BITREV: D width, 0x00000001 -> 0x80000000
        apply_op(64'h00000001, 64'h0, OP_BITREV, DW_D);
        check_result_only("BITREV 0x00000001 (D) = 0x80000000", 64'h80000000);

        // BITREV: 0
        apply_op(64'h0, 64'h0, OP_BITREV, DW_Q);
        check_result_only("BITREV 0 (Q) = 0", 64'h0);

        // -----------------------------------------------------------------
        // SEXT_B tests (sign-extend byte)
        // -----------------------------------------------------------------
        $display("\n--- SEXT_B Tests ---");

        // SEXT_B: 0x7F -> sign bit 0, extend to 64-bit positive
        apply_op(64'h7F, 64'h0, OP_SEXT_B, DW_Q);
        check_result_only("SEXT_B 0x7F (positive)", 64'h000000000000007F);

        // SEXT_B: 0x80 -> sign bit 1, extend to 64-bit negative
        apply_op(64'h80, 64'h0, OP_SEXT_B, DW_Q);
        check_result_only("SEXT_B 0x80 (negative)", 64'hFFFFFFFFFFFFFF80);

        // SEXT_B: 0x00 -> zero
        apply_op(64'h00, 64'h0, OP_SEXT_B, DW_Q);
        check_result_only("SEXT_B 0x00 (zero)", 64'h0);

        // SEXT_B: 0xFF -> -1 as signed byte
        apply_op(64'hFF, 64'h0, OP_SEXT_B, DW_Q);
        check_result_only("SEXT_B 0xFF (-1)", 64'hFFFFFFFFFFFFFFFF);

        // -----------------------------------------------------------------
        // SEXT_W tests (sign-extend word/16-bit)
        // -----------------------------------------------------------------
        $display("\n--- SEXT_W Tests ---");

        // SEXT_W: 0x7FFF -> positive
        apply_op(64'h7FFF, 64'h0, OP_SEXT_W, DW_Q);
        check_result_only("SEXT_W 0x7FFF (positive)", 64'h0000000000007FFF);

        // SEXT_W: 0x8000 -> negative
        apply_op(64'h8000, 64'h0, OP_SEXT_W, DW_Q);
        check_result_only("SEXT_W 0x8000 (negative)", 64'hFFFFFFFFFFFF8000);

        // SEXT_W: 0x0000 -> zero
        apply_op(64'h0000, 64'h0, OP_SEXT_W, DW_Q);
        check_result_only("SEXT_W 0x0000 (zero)", 64'h0);

        // SEXT_W: 0xFFFF -> -1
        apply_op(64'hFFFF, 64'h0, OP_SEXT_W, DW_Q);
        check_result_only("SEXT_W 0xFFFF (-1)", 64'hFFFFFFFFFFFFFFFF);

        // -----------------------------------------------------------------
        // ZEXT_B tests (zero-extend byte)
        // -----------------------------------------------------------------
        $display("\n--- ZEXT_B Tests ---");

        apply_op(64'h7F, 64'h0, OP_ZEXT_B, DW_Q);
        check_result_only("ZEXT_B 0x7F", 64'h000000000000007F);

        apply_op(64'h80, 64'h0, OP_ZEXT_B, DW_Q);
        check_result_only("ZEXT_B 0x80", 64'h0000000000000080);

        apply_op(64'hFF, 64'h0, OP_ZEXT_B, DW_Q);
        check_result_only("ZEXT_B 0xFF", 64'h00000000000000FF);

        apply_op(64'h00, 64'h0, OP_ZEXT_B, DW_Q);
        check_result_only("ZEXT_B 0x00", 64'h0);

        // -----------------------------------------------------------------
        // ZEXT_W tests (zero-extend word/16-bit)
        // -----------------------------------------------------------------
        $display("\n--- ZEXT_W Tests ---");

        apply_op(64'h7FFF, 64'h0, OP_ZEXT_W, DW_Q);
        check_result_only("ZEXT_W 0x7FFF", 64'h0000000000007FFF);

        apply_op(64'h8000, 64'h0, OP_ZEXT_W, DW_Q);
        check_result_only("ZEXT_W 0x8000", 64'h0000000000008000);

        apply_op(64'hFFFF, 64'h0, OP_ZEXT_W, DW_Q);
        check_result_only("ZEXT_W 0xFFFF", 64'h000000000000FFFF);

        apply_op(64'h0000, 64'h0, OP_ZEXT_W, DW_Q);
        check_result_only("ZEXT_W 0x0000", 64'h0);

        // =================================================================
        // SUMMARY
        // =================================================================
        $display("\n============================================================");
        $display(" TEST SUMMARY");
        $display("============================================================");
        $display("  Total tests: %0d", test_num - 1);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  SOME TESTS FAILED!");
            $display("  Failures: %0d", fail_count);
        end
        $display("============================================================\n");

        $finish;
    end

endmodule