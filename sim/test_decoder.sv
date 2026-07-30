// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0
// Decoder Testbench: all instruction classes, boundaries, special opcodes,
// invalid opcodes, priority encoding.

module tb_decoder;

    // =========================================================================
    // Signals
    // =========================================================================
    logic [10:0] opcode_i;
    logic [3:0]  inst_class_o;
    logic [2:0]  addr_mode_o;
    logic [2:0]  data_type_o;
    logic [7:0]  uop_code_o;
    logic        is_vendor_o;
    logic        is_standard_o;
    logic        is_valid_o;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    misc_decoder dut (
        .opcode_i      (opcode_i),
        .inst_class_o  (inst_class_o),
        .addr_mode_o   (addr_mode_o),
        .data_type_o   (data_type_o),
        .uop_code_o    (uop_code_o),
        .is_vendor_o   (is_vendor_o),
        .is_standard_o (is_standard_o),
        .is_valid_o    (is_valid_o)
    );

    // =========================================================================
    // Test Infrastructure
    // =========================================================================
    integer pass_cnt, fail_cnt;
    integer test_num;

    // -------------------------------------------------------------------------
    // Helper: check all decoder outputs against expected values
    // -------------------------------------------------------------------------
    task automatic check(
        input string       name,
        input logic [10:0] exp_opcode,
        input logic [3:0]  exp_class,
        input logic [2:0]  exp_addr,
        input logic [2:0]  exp_dtype,
        input logic [7:0]  exp_uop,
        input logic        exp_vendor,
        input logic        exp_std,
        input logic        exp_valid
    );
        begin
            #1;  // allow combinational logic to settle
            if (inst_class_o  !== exp_class  ||
                addr_mode_o   !== exp_addr   ||
                data_type_o   !== exp_dtype  ||
                uop_code_o    !== exp_uop    ||
                is_vendor_o   !== exp_vendor ||
                is_standard_o !== exp_std    ||
                is_valid_o    !== exp_valid) begin
                $display("[FAIL] Test %0d: %s (opcode=0x%03X)", test_num, name, exp_opcode);
                $display("       Expected: class=%0d addr=%0d dtype=%0d uop=0x%02X vendor=%0d std=%0d valid=%0d",
                         exp_class, exp_addr, exp_dtype, exp_uop, exp_vendor, exp_std, exp_valid);
                $display("       Got:      class=%0d addr=%0d dtype=%0d uop=0x%02X vendor=%0d std=%0d valid=%0d",
                         inst_class_o, addr_mode_o, data_type_o, uop_code_o, is_vendor_o, is_standard_o, is_valid_o);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[PASS] Test %0d: %s (opcode=0x%03X)", test_num, name, exp_opcode);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Shorthand: drive opcode then check
    // -------------------------------------------------------------------------
    task automatic test_opcode(
        input string       name,
        input logic [10:0] opcode,
        input logic [3:0]  exp_class,
        input logic [2:0]  exp_addr,
        input logic [2:0]  exp_dtype,
        input logic [7:0]  exp_uop,
        input logic        exp_vendor,
        input logic        exp_std,
        input logic        exp_valid
    );
        begin
            test_num  = test_num + 1;
            opcode_i  = opcode;
            check(name, opcode, exp_class, exp_addr, exp_dtype, exp_uop,
                  exp_vendor, exp_std, exp_valid);
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        test_num = 0;
        opcode_i = 11'h000;

        $display("============================================================");
        $display(" MISC-2000 Decoder Testbench");
        $display("============================================================");

        // =====================================================================
        // 1. Vendor Zone: 0x000 – 0x0FF
        // =====================================================================
        $display("--- Vendor Zone (0x000–0x0FF) ---");

        // Vendor zone: data_type defaults to Q(3), addr_mode defaults to IMM(0)
        test_opcode("Vendor[0x00]",
            11'h000, 4'd7, 3'd0, 3'd3, 8'h00, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0x01] uADD",
            11'h001, 4'd7, 3'd0, 3'd3, 8'h01, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0x7F]",
            11'h07F, 4'd7, 3'd0, 3'd3, 8'h7F, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0xFF]",
            11'h0FF, 4'd7, 3'd0, 3'd3, 8'hFF, 1'b1, 1'b0, 1'b1);

        // =====================================================================
        // 2. Data Transfer: 0x100 – 0x1FF
        // =====================================================================
        $display("--- Data Transfer (0x100–0x1FF) ---");

        // Standard addressing: addr_mode = (opcode - 0x100) % 5
        test_opcode("MOV.IMM  (0x100)",
            11'h100, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.REG  (0x101)",
            11'h101, 4'd0, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.DIR  (0x102)",
            11'h102, 4'd0, 3'd2, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.IDX  (0x103)",
            11'h103, 4'd0, 3'd3, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.STK  (0x104)",
            11'h104, 4'd0, 3'd4, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // Special single-opcode instructions: addr forced to IMM, dtype per offset
        // 0x132: off=0x32=50, dtype=(50%20)/5=2(D)
        test_opcode("MOV.R2M  (0x132) special",
            11'h132, 4'd0, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x133: off=0x33=51, dtype=(51%20)/5=2(D)
        test_opcode("MOV.M2R  (0x133) special",
            11'h133, 4'd0, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x134: off=0x34=52, dtype=(52%20)/5=2(D)
        test_opcode("MOV.M2M  (0x134) special",
            11'h134, 4'd0, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x15D: off=0x5D=93, dtype=(93%20)/5=2(D)
        test_opcode("MEMBAR   (0x15D) special",
            11'h15D, 4'd0, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x15E: off=0x5E=94, dtype=(94%20)/5=2(D)
        test_opcode("FENCE    (0x15E) special",
            11'h15E, 4'd0, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // Boundary: last Data Transfer opcode
        // off=0xFF=255, addr=255%5=0(IMM), dtype=(255%20)/5=15/5=3(Q)
        test_opcode("DataXfer boundary (0x1FF)",
            11'h1FF, 4'd0, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 3. Integer Arithmetic: 0x200 – 0x407
        //    addr_mode = (opcode - 0x200) % 5
        //    data_type = ((opcode - 0x200) % 20) / 5
        // =====================================================================
        $display("--- Integer Arithmetic (0x200–0x407) ---");

        // ADD.B.IMM:  offset=0,   addr=0(IMM), type=0(B)
        test_opcode("ADD.B.IMM  (0x200)",
            11'h200, 4'd1, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // ADD.W.IMM:  offset=5,   addr=0(IMM), type=1(W)
        test_opcode("ADD.W.IMM  (0x205)",
            11'h205, 4'd1, 3'd0, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // ADD.D.IMM:  offset=10,  addr=0(IMM), type=2(D)
        test_opcode("ADD.D.IMM  (0x20A)",
            11'h20A, 4'd1, 3'd0, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // ADD.Q.IMM:  offset=15,  addr=0(IMM), type=3(Q)
        test_opcode("ADD.Q.IMM  (0x20F)",
            11'h20F, 4'd1, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // ADD.B.REG:  offset=1,   addr=1(REG), type=0(B)
        test_opcode("ADD.B.REG  (0x201)",
            11'h201, 4'd1, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // SUB.B.IMM:  offset=20 (0x14), addr=0(IMM), type=0(B)
        test_opcode("SUB.B.IMM  (0x214)",
            11'h214, 4'd1, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // MUL.B.REG:  offset=41 (0x29), addr=1(REG), type=0(B)
        test_opcode("MUL.B.REG  (0x229)",
            11'h229, 4'd1, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // DIV.D.STK:  offset=74 (0x4A), addr=4(STK), type=2(D)
        test_opcode("DIV.D.STK  (0x24A)",
            11'h24A, 4'd1, 3'd4, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // POPCNT.B.IMM: offset=500 (0x1F4), addr=0(IMM), type=0(B)
        test_opcode("POPCNT.B.IMM (0x3F4)",
            11'h3F4, 4'd1, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // POPCNT.Q.STK: offset=519 (0x207), addr=4(STK), type=3(Q)
        // Last valid integer arithmetic opcode
        test_opcode("POPCNT.Q.STK (0x407) last",
            11'h407, 4'd1, 3'd4, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 4. Logic: 0x400 – 0x4EF
        //    addr_mode = (opcode - 0x400) % 5
        //    data_type = ((opcode - 0x400) % 20) / 5
        //
        //    IMPORTANT: 0x400–0x407 overlap with Integer Arithmetic (0x200–0x407).
        //    Because Integer Arithmetic is checked FIRST in the priority chain,
        //    0x400–0x407 decode as Integer Arithmetic (class=1), not Logic.
        //    Below we test 0x400 to verify this priority behaviour.
        // =====================================================================
        $display("--- Logic (0x400–0x4EF) ---");
        $display("    (NOTE: 0x400–0x407 decode as Integer Arithmetic due to priority)");

        // 0x400: falls in Integer Arithmetic zone due to priority
        // offset=0x200=512, addr=2(DIR), type=2(D), class=1
        test_opcode("0x400 (priority: IntArith, not Logic)",
            11'h400, 4'd1, 3'd2, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x401: also Integer Arithmetic (offset=0x201=513, addr=3(IDX), type=2(D))
        test_opcode("0x401 (also IntArith)",
            11'h401, 4'd1, 3'd3, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // 0x408 is the first purely-Logic opcode
        // AND.B.IMM at 0x408: off=0, addr=0%5=0(IMM), dtype=(0%20)/5=0(B)
        test_opcode("AND.B.IMM  (0x408) first-logic",
            11'h408, 4'd2, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // OR.W.IMM: off=0x41=65, addr=65%5=0(IMM), dtype=(65%20)/5=5/5=1(W)
        test_opcode("OR.W.IMM   (0x449)",
            11'h449, 4'd2, 3'd0, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // XOR.W.REG: off=0xA6=166, addr=166%5=1(REG), dtype=(166%20)/5=6/5=1(W)
        test_opcode("XOR.W.REG  (0x4AE)",
            11'h4AE, 4'd2, 3'd1, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // Last valid Logic opcode: off=0xE7=231, addr=231%5=1(REG), dtype=(231%20)/5=11/5=2(D)
        test_opcode("Logic last (0x4EF)",
            11'h4EF, 4'd2, 3'd1, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // First invalid after Logic range: defaults apply
        test_opcode("post-logic  (0x4F0) invalid",
            11'h4F0, 4'd0, 3'd0, 3'd3, 8'd0, 1'b0, 1'b0, 1'b0);

        // =====================================================================
        // 5. Float: 0x500 – 0x62B
        //    dtype encoding: 4=F16, 5=F32, 6=F64, 7=F128 (offset +4 from base)
        // =====================================================================
        $display("--- Float (0x500–0x62B) ---");

        // FADD.F16.IMM: off=0, addr=0(IMM), dtype=4+(0/5)=4(F16)
        test_opcode("FADD.F16.IMM (0x500)",
            11'h500, 4'd3, 3'd0, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // FADD.F16.REG: off=1, addr=1(REG), dtype=4+(1/5)=4(F16)
        test_opcode("FADD.F16.REG (0x501)",
            11'h501, 4'd3, 3'd1, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // FSUB.F16.IDX: off=0x17=23, addr=23%5=3(IDX), dtype=4+((23%20)/5)=4(F16)
        test_opcode("FSUB.F16.IDX (0x517)",
            11'h517, 4'd3, 3'd3, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // FMUL.F16.STK: off=0x2C=44, addr=44%5=4(STK), dtype=4+((44%20)/5)=4(F16)
        test_opcode("FMUL.F16.STK (0x52C)",
            11'h52C, 4'd3, 3'd4, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // Float mid: off=0x95=149, addr=149%5=4(STK), dtype=4+((149%20)/5)=5(F32)
        test_opcode("Float mid   (0x595)",
            11'h595, 4'd3, 3'd4, 3'd5, 8'd0, 1'b0, 1'b1, 1'b1);

        // Last valid Float opcode: off=0x12B=299, addr=299%5=4(STK), dtype=4+((299%20)/5)=7(F128)
        test_opcode("Float last  (0x62B)",
            11'h62B, 4'd3, 3'd4, 3'd7, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 6. Program Control: 0x62C – 0x6FF
        //    addr_mode = (opcode - 0x62C) % 5
        //    BKPT(0x695), TRACE(0x696), WATCHDOG(0x697) override to IMM
        // =====================================================================
        $display("--- Program Control (0x62C–0x6FF) ---");

        // JMP.IMM: first PC opcode, offset=0, addr=0(IMM)
        test_opcode("JMP.IMM     (0x62C)",
            11'h62C, 4'd4, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // IRET.IMM: offset=0x14=20, addr=0(IMM)
        test_opcode("IRET.IMM    (0x640)",
            11'h640, 4'd4, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // JB.REG: offset=0x3D=61, addr=1(REG) — no longer overridden as BKPT
        test_opcode("JB.REG      (0x669)",
            11'h669, 4'd4, 3'd1, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // JB.DIR: offset=0x3E=62, addr=2(DIR)
        test_opcode("JB.DIR      (0x66A)",
            11'h66A, 4'd4, 3'd2, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // JB.IDX: offset=0x3F=63, addr=3(IDX)
        test_opcode("JB.IDX      (0x66B)",
            11'h66B, 4'd4, 3'd3, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // BKPT: special, addr=0(IMM)
        test_opcode("BKPT        (0x695) special",
            11'h695, 4'd4, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // TRACE: special, addr=0(IMM)
        test_opcode("TRACE       (0x696) special",
            11'h696, 4'd4, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // WATCHDOG: special, addr=0(IMM)
        test_opcode("WATCHDOG    (0x697) special",
            11'h697, 4'd4, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // PC boundary: last Program Control opcode (offset=0xD3=211, 211%5=1 → REG)
        test_opcode("PC boundary (0x6FF)",
            11'h6FF, 4'd4, 3'd1, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 7. SIMD Vector: 0x700–0x7BF & 0x7D0–0x7FF
        //    addr_mode always REG(1), data_type = (opcode - 0x700) % 5
        //    System late entries (0x7C0–0x7CF) take priority over SIMD
        // =====================================================================
        $display("--- SIMD Vector (0x700–0x7BF, 0x7D0–0x7FF) ---");

        // VADD.I8:  offset=0, dtype=0, addr=1(REG)
        test_opcode("VADD.I8     (0x700)",
            11'h700, 4'd5, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.I16: offset=1, dtype=1
        test_opcode("VADD.I16    (0x701)",
            11'h701, 4'd5, 3'd1, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.I64: offset=3, dtype=3
        test_opcode("VADD.I64    (0x703)",
            11'h703, 4'd5, 3'd1, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.F64: offset=4, dtype=4
        test_opcode("VADD.F64    (0x704)",
            11'h704, 4'd5, 3'd1, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD lower boundary last valid before System gap
        // offset=0xBF=191, 191%5=1
        test_opcode("SIMD pre-gap (0x7BF)",
            11'h7BF, 4'd5, 3'd1, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD upper range start (after System gap)
        // offset=0xD0=208, 208%5=3
        test_opcode("SIMD post-gap (0x7D0)",
            11'h7D0, 4'd5, 3'd1, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD last valid (offset=0xFF=255, 255%5=0)
        test_opcode("SIMD last   (0x7FF)",
            11'h7FF, 4'd5, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 8. System (late entries): 0x7C0 – 0x7CF
        //    These appear inside the SIMD numeric range but decode as System.
        //    They are the last "standard" instructions.
        //    data_type defaults to Q(3).
        // =====================================================================
        $display("--- System Late (0x7C0–0x7CF) ---");

        // SYS_EOI.IMM: first System late entry
        test_opcode("SYS_EOI.IMM (0x7C0)",
            11'h7C0, 4'd6, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // SYS_SHUTDOWN: last System late = last standard instruction
        test_opcode("SYS_SHUTDOWN (0x7CF) last-std",
            11'h7CF, 4'd6, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 9. System (main): 0x800 – 0x9FF
        //    NOTE: These opcodes require >11 bits and are unreachable with the
        //    current 11-bit opcode width. This is a known limitation.
        //    With 11-bit opcodes, 0x800 truncates to 0x000 (vendor zone).
        // =====================================================================
        $display("--- System Main (0x800–0x9FF): skipped (opcode width limitation) ---");

        // =====================================================================
        // 10. Invalid Opcodes (within 11-bit range)
        // =====================================================================
        $display("--- Invalid Opcodes ---");

        // 0x4F0 already tested as post-logic invalid above

        // =====================================================================
        // Summary
        // =====================================================================
        $display("============================================================");
        $display(" Test Summary: %0d passed, %0d failed, %0d total",
                 pass_cnt, fail_cnt, test_num);
        $display("============================================================");
        if (fail_cnt == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED");

        $stop;
    end

endmodule
