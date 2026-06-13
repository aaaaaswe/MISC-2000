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
// MISC-2000 Instruction Decoder Testbench
// =============================================================================
// Comprehensive testbench for misc_decoder covering all instruction classes,
// boundary conditions, special opcodes, and invalid opcodes.

`include "../rtl/core/decoder.sv"

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

        test_opcode("Vendor[0x00]",
            11'h000, 4'd7, 3'd0, 3'd0, 8'h00, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0x01] uADD",
            11'h001, 4'd7, 3'd0, 3'd0, 8'h01, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0x7F]",
            11'h07F, 4'd7, 3'd0, 3'd0, 8'h7F, 1'b1, 1'b0, 1'b1);

        test_opcode("Vendor[0xFF]",
            11'h0FF, 4'd7, 3'd0, 3'd0, 8'hFF, 1'b1, 1'b0, 1'b1);

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

        // Special single-opcode instructions always use IMM addressing
        test_opcode("MOV.R2M  (0x132) special",
            11'h132, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.M2R  (0x133) special",
            11'h133, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MOV.M2M  (0x134) special",
            11'h134, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("MEMBAR   (0x15D) special",
            11'h15D, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        test_opcode("FENCE    (0x15E) special",
            11'h15E, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // Boundary: last Data Transfer opcode (offset=0xFF=255, 255%5=0 → IMM)
        test_opcode("DataXfer boundary (0x1FF)",
            11'h1FF, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

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
        // AND.B.IMM at 0x408: offset=8, addr=3(IDX), type=0(B)
        test_opcode("AND.B.IMM  (0x408) first-logic",
            11'h408, 4'd2, 3'd3, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // OR.W.REG: offset=0x49=73, addr=3(IDX), type=1(W)
        test_opcode("OR.W.REG   (0x449)",
            11'h449, 4'd2, 3'd3, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // XOR.D.STK: offset=0xAE=174, addr=4(STK), type=2(D)
        test_opcode("XOR.D.STK  (0x4AE)",
            11'h4AE, 4'd2, 3'd4, 3'd2, 8'd0, 1'b0, 1'b1, 1'b1);

        // Last valid Logic opcode: offset=0xEF=239, addr=4(STK), type=3(Q)
        test_opcode("Logic last (0x4EF)",
            11'h4EF, 4'd2, 3'd4, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // First invalid after Logic range
        test_opcode("post-logic  (0x4F0) invalid",
            11'h4F0, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b0);

        // =====================================================================
        // 5. Float: 0x500 – 0x62B
        //    data_type values: 0=F16, 1=F32, 2=F64, 3=F128
        // =====================================================================
        $display("--- Float (0x500–0x62B) ---");

        // FADD.F16.IMM: offset=0, addr=0(IMM), type=0(F16)
        test_opcode("FADD.F16.IMM (0x500)",
            11'h500, 4'd3, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // FADD.F16.REG: offset=1, addr=1(REG), type=0(F16)
        test_opcode("FADD.F16.REG (0x501)",
            11'h501, 4'd3, 3'd1, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // FSUB.F16.IDX: offset=23, addr=3(IDX), type=0(F16)
        test_opcode("FSUB.F16.IDX (0x517)",
            11'h517, 4'd3, 3'd3, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // FMUL.F16.STK: offset=44, addr=4(STK), type=0(F16)
        test_opcode("FMUL.F16.STK (0x52C)",
            11'h52C, 4'd3, 3'd4, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // Float mid: offset=0x95=149, addr=4(STK), type=1(F32)
        test_opcode("Float mid   (0x595)",
            11'h595, 4'd3, 3'd4, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // Last valid Float opcode: offset=0x12B=299, addr=4(STK), type=3(F128)
        test_opcode("Float last  (0x62B)",
            11'h62B, 4'd3, 3'd4, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 6. Program Control: 0x62C – 0x6FF
        //    addr_mode = (opcode - 0x600) % 5
        //    BKPT(0x669), TRACE(0x66A), WATCHDOG(0x66B) override to IMM
        // =====================================================================
        $display("--- Program Control (0x62C–0x6FF) ---");

        // First PC opcode after Float: offset=0x2C=44, addr=4(STK)
        test_opcode("PC first    (0x62C)",
            11'h62C, 4'd4, 3'd4, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // JMP.IMM: offset=0x40=64, addr=4(STK)
        test_opcode("JMP.IMM     (0x640)",
            11'h640, 4'd4, 3'd4, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // BKPT: special, addr=0(IMM)
        test_opcode("BKPT        (0x669) special",
            11'h669, 4'd4, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // TRACE: special, addr=0(IMM)
        test_opcode("TRACE       (0x66A) special",
            11'h66A, 4'd4, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // WATCHDOG: special, addr=0(IMM)
        test_opcode("WATCHDOG    (0x66B) special",
            11'h66B, 4'd4, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // PC boundary: last Program Control opcode (offset=0xFF=255, 255%5=0 → IMM)
        test_opcode("PC boundary (0x6FF)",
            11'h6FF, 4'd4, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 7. SIMD Vector: 0x700–0x7BF & 0x7D0–0x7FF
        //    data_type = (opcode - 0x700) % 5
        //    System late entries (0x7C0–0x7CF) take priority over SIMD
        // =====================================================================
        $display("--- SIMD Vector (0x700–0x7BF, 0x7D0–0x7FF) ---");

        // VADD.I8:  offset=0, dtype=0
        test_opcode("VADD.I8     (0x700)",
            11'h700, 4'd5, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.I16: offset=1, dtype=1
        test_opcode("VADD.I16    (0x701)",
            11'h701, 4'd5, 3'd0, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.I64: offset=3, dtype=3
        test_opcode("VADD.I64    (0x703)",
            11'h703, 4'd5, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // VADD.F64: offset=4, dtype=4
        test_opcode("VADD.F64    (0x704)",
            11'h704, 4'd5, 3'd0, 3'd4, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD lower boundary last valid before System gap
        // offset=0xBF=191, 191%5=1
        test_opcode("SIMD pre-gap (0x7BF)",
            11'h7BF, 4'd5, 3'd0, 3'd1, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD upper range start (after System gap)
        // offset=0xD0=208, 208%5=3
        test_opcode("SIMD post-gap (0x7D0)",
            11'h7D0, 4'd5, 3'd0, 3'd3, 8'd0, 1'b0, 1'b1, 1'b1);

        // SIMD last valid (offset=0xFF=255, 255%5=0)
        test_opcode("SIMD last   (0x7FF)",
            11'h7FF, 4'd5, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 8. System (late entries): 0x7C0 – 0x7CF
        //    These appear inside the SIMD numeric range but decode as System.
        //    They are the last "standard" instructions.
        // =====================================================================
        $display("--- System Late (0x7C0–0x7CF) ---");

        // SYS_EOI.IMM: first System late entry
        test_opcode("SYS_EOI.IMM (0x7C0)",
            11'h7C0, 4'd6, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // SYS_SHUTDOWN.STK: last System late = last standard instruction
        test_opcode("SYS_SHUTDOWN.STK (0x7CF) last-std",
            11'h7CF, 4'd6, 3'd0, 3'd0, 8'd0, 1'b0, 1'b1, 1'b1);

        // =====================================================================
        // 9. System (main): 0x800 – 0x9FF
        //    is_standard_o stays 0 for this range
        // =====================================================================
        $display("--- System Main (0x800–0x9FF) ---");

        test_opcode("SYS (0x800)",
            11'h800, 4'd6, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b1);

        test_opcode("SYS (0x880)",
            11'h880, 4'd6, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b1);

        test_opcode("SYS last (0x9FF)",
            11'h9FF, 4'd6, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b1);

        // =====================================================================
        // 10. Invalid Opcodes
        // =====================================================================
        $display("--- Invalid Opcodes ---");

        // 0xA00: outside all defined ranges
        test_opcode("0xA00 invalid",
            11'hA00, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b0);

        // 0xFFF: maximum 11-bit value, outside all ranges
        test_opcode("0xFFF invalid",
            11'hFFF, 4'd0, 3'd0, 3'd0, 8'd0, 1'b0, 1'b0, 1'b0);

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