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
// MISC-2000 Exception & CSR Testbench
// =============================================================================
// Comprehensive self-checking testbench for misc_exception and misc_csr.
// Tests exception entry, priority encoding, ERET return-address calculation,
// CSR read/write, pipeline flush, exception-active state, and all-or-nothing
// semantics.


module tb_exception;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 10;          // 10 ns clock period
    localparam DATA_WIDTH = 64;
    localparam ADDR_WIDTH  = 64;

    // Exception causes
    localparam logic [3:0] EXC_CAUSE_INSTR_PAGE_FAULT = 4'hC;
    localparam logic [3:0] EXC_CAUSE_LDST_PAGE_FAULT  = 4'hD;
    localparam logic [3:0] EXC_CAUSE_ILLEGAL_INSTR    = 4'h2;

    // IFU / memory exception cause encodings
    localparam logic [1:0] IFU_CAUSE_PAGE_FAULT    = 2'b00;
    localparam logic [1:0] IFU_CAUSE_ILLEGAL_INSTR = 2'b01;
    localparam logic [1:0] MEM_CAUSE_PAGE_FAULT    = 2'b00;

    // CSR addresses
    localparam logic [11:0] CSR_EPC   = 12'h300;
    localparam logic [11:0] CSR_ILLEN = 12'h301;

    // Exception handler vector
    localparam logic [63:0] EXC_VECTOR = 64'h0000_0000_8000_0000;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    // -------------------------------------------------------------------------
    // misc_exception inputs
    // -------------------------------------------------------------------------
    logic                     ifu_exception_i;
    logic [1:0]               ifu_exception_cause_i;
    logic [ADDR_WIDTH-1:0]    ifu_exception_addr_i;
    logic [2:0]               ifu_instr_len_i;

    logic                     mem_exception_i;
    logic [1:0]               mem_exception_cause_i;
    logic [ADDR_WIDTH-1:0]    mem_exception_addr_i;
    logic [2:0]               mem_instr_len_i;

    logic                     decode_exception_i;
    logic [1:0]               decode_exception_cause_i;
    logic [ADDR_WIDTH-1:0]    decode_exception_addr_i;
    logic [2:0]               decode_instr_len_i;

    logic                     eret_exec_i;

    // misc_exception outputs
    logic                     exception_taken_o;
    logic [ADDR_WIDTH-1:0]    exception_pc_o;
    logic [2:0]               exception_ilen_o;
    logic [3:0]               exception_cause_o;
    logic                     flush_pipeline_o;
    logic [ADDR_WIDTH-1:0]    exception_target_pc_o;
    logic [ADDR_WIDTH-1:0]    eret_target_pc_o;
    logic                     exception_active_o;

    // CSR eret_target → exception csr_eret_target_i
    logic [ADDR_WIDTH-1:0]    csr_eret_target;

    // -------------------------------------------------------------------------
    // misc_csr interface
    // -------------------------------------------------------------------------
    logic                     csr_ren_i;
    logic                     csr_wen_i;
    logic [11:0]              csr_addr_i;
    logic [DATA_WIDTH-1:0]    csr_wdata_i;
    logic [DATA_WIDTH-1:0]    csr_rdata_o;
    logic                     sc_success_o;  // unused in these tests

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
    // DUT: misc_exception
    // -------------------------------------------------------------------------
    misc_exception #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_exception (
        .clk_i                (clk),
        .rst_n_i              (rst_n),
        .ifu_exception_i      (ifu_exception_i),
        .ifu_exception_cause_i(ifu_exception_cause_i),
        .ifu_exception_addr_i (ifu_exception_addr_i),
        .ifu_instr_len_i      (ifu_instr_len_i),
        .mem_exception_i      (mem_exception_i),
        .mem_exception_cause_i(mem_exception_cause_i),
        .mem_exception_addr_i (mem_exception_addr_i),
        .mem_instr_len_i      (mem_instr_len_i),
        .decode_exception_i   (decode_exception_i),
        .decode_exception_cause_i(decode_exception_cause_i),
        .decode_exception_addr_i (decode_exception_addr_i),
        .decode_instr_len_i   (decode_instr_len_i),
        .eret_exec_i          (eret_exec_i),
        .csr_eret_target_i    (csr_eret_target),
        .exception_taken_o    (exception_taken_o),
        .exception_pc_o       (exception_pc_o),
        .exception_ilen_o     (exception_ilen_o),
        .exception_cause_o    (exception_cause_o),
        .flush_pipeline_o     (flush_pipeline_o),
        .exception_target_pc_o(exception_target_pc_o),
        .eret_target_pc_o     (eret_target_pc_o),
        .exception_active_o   (exception_active_o)
    );

    // -------------------------------------------------------------------------
    // DUT: misc_csr
    // -------------------------------------------------------------------------
    misc_csr #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_csr (
        .clk_i             (clk),
        .rst_n_i           (rst_n),
        .csr_ren_i         (csr_ren_i),
        .csr_wen_i         (csr_wen_i),
        .csr_addr_i        (csr_addr_i),
        .csr_wdata_i       (csr_wdata_i),
        .csr_rdata_o       (csr_rdata_o),
        .exception_taken_i (exception_taken_o),
        .exception_pc_i    (exception_pc_o),
        .exception_ilen_i  (exception_ilen_o),
        .exception_cause_i (exception_cause_o),
        .eret_exec_i       (eret_exec_i),
        .eret_target_o     (csr_eret_target),
        .ll_exec_i         (1'b0),
        .ll_addr_i         ('0),
        .sc_exec_i         (1'b0),
        .sc_success_o      (sc_success_o),
        .monitor_clear_i   (1'b0)
    );

    // -------------------------------------------------------------------------
    // Helper: initialize all inputs to inactive
    // -------------------------------------------------------------------------
    task automatic init_inputs();
        ifu_exception_i        = 1'b0;
        ifu_exception_cause_i  = 2'b00;
        ifu_exception_addr_i   = '0;
        ifu_instr_len_i        = 3'd0;
        mem_exception_i        = 1'b0;
        mem_exception_cause_i  = 2'b00;
        mem_exception_addr_i   = '0;
        mem_instr_len_i        = 3'd0;
        decode_exception_i     = 1'b0;
        decode_exception_cause_i = 2'b00;
        decode_exception_addr_i  = '0;
        decode_instr_len_i     = 3'd0;
        eret_exec_i            = 1'b0;
        csr_ren_i              = 1'b0;
        csr_wen_i              = 1'b0;
        csr_addr_i             = 12'h000;
        csr_wdata_i            = '0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: wait N clock cycles
    // -------------------------------------------------------------------------
    task automatic wait_cycles(input integer n);
        repeat (n) @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Helper: CSR write — drives wen/addr/wdata for one cycle, then waits
    // -------------------------------------------------------------------------
    task automatic csr_write(
        input logic [11:0]          addr,
        input logic [DATA_WIDTH-1:0] data
    );
        csr_wen_i   = 1'b1;
        csr_addr_i  = addr;
        csr_wdata_i = data;
        @(posedge clk);
        csr_wen_i   = 1'b0;
        csr_addr_i  = 12'h000;
        csr_wdata_i = '0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: CSR read — returns rdata (combinational, sampled after settling)
    // -------------------------------------------------------------------------
    task automatic csr_read(
        input  logic [11:0]           addr,
        output logic [DATA_WIDTH-1:0] rdata
    );
        csr_ren_i  = 1'b1;
        csr_addr_i = addr;
        #1;
        rdata = csr_rdata_o;
        csr_ren_i  = 1'b0;
        csr_addr_i = 12'h000;
    endtask

    // -------------------------------------------------------------------------
    // Helper: execute ERET — pulses eret_exec_i for one cycle
    // -------------------------------------------------------------------------
    task automatic do_eret();
        eret_exec_i = 1'b1;
        @(posedge clk);
        eret_exec_i = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Helper: trigger exception and verify exception_taken
    // -------------------------------------------------------------------------
    task automatic trigger_and_verify_exception(
        input string                desc,
        input logic [3:0]           exp_cause,
        input logic [63:0]          exp_target_pc
    );
        // Drive exception inputs are already set by caller
        #1;
        if (exception_taken_o !== 1'b1) begin
            $display("[%0d] FAIL: %s — exception_taken_o expected 1, got %b",
                     test_num, desc, exception_taken_o);
            fail_count = fail_count + 1;
        end else begin
            $display("[%0d] PASS: %s — exception_taken_o asserted", test_num, desc);
            pass_count = pass_count + 1;
        end
        test_num = test_num + 1;

        // Also check flush_pipeline_o on the same cycle
        #0;
        if (flush_pipeline_o !== 1'b1) begin
            $display("[%0d] FAIL: %s — flush_pipeline_o expected 1, got %b",
                     test_num, desc, flush_pipeline_o);
            fail_count = fail_count + 1;
        end else begin
            $display("[%0d] PASS: %s — flush_pipeline_o asserted", test_num, desc);
            pass_count = pass_count + 1;
        end
        test_num = test_num + 1;

        // Check exception_target_pc_o on exception entry
        #0;
        if (exception_target_pc_o !== exp_target_pc) begin
            $display("[%0d] FAIL: %s — exception_target_pc_o expected 0x%016h, got 0x%016h",
                     test_num, desc, exp_target_pc, exception_target_pc_o);
            fail_count = fail_count + 1;
        end else begin
            $display("[%0d] PASS: %s — exception_target_pc_o = 0x%016h",
                     test_num, desc, exception_target_pc_o);
            pass_count = pass_count + 1;
        end
        test_num = test_num + 1;

        @(posedge clk);
        // Clear exception inputs after the edge
        init_inputs();
    endtask

    // -------------------------------------------------------------------------
    // Helper: pass/fail check with message
    // -------------------------------------------------------------------------
    task automatic check(
        input string  test_name,
        input logic   condition,
        input string  detail
    );
        if (condition) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            if (detail != "") $display("       %s", detail);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            if (detail != "") $display("       %s", detail);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;
    endtask

    // =====================================================================
    // MAIN TEST SEQUENCE
    // =====================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        $display("============================================================");
        $display(" MISC-2000 Exception & CSR Testbench");
        $display("============================================================");

        // -----------------------------------------------------------------
        // Reset sequence
        // -----------------------------------------------------------------
        init_inputs();
        rst_n = 1'b0;
        wait_cycles(3);
        rst_n = 1'b1;
        wait_cycles(2);

        $display("\n--- All inputs initialized, reset released ---\n");

        // =================================================================
        // TEST 1: CSR_EPC and CSR_ILLEN on IFU page-fault exception
        // =================================================================
        $display("\n========== Test 1: CSR_EPC and CSR_ILLEN on exception ==========");

        // Drive IFU page fault: ifu_exception_i=1, cause=page_fault(00),
        // ilen=1 (encoded=4B), addr=0x2000
        ifu_exception_i       = 1'b1;
        ifu_exception_cause_i = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i  = 64'h2000;
        ifu_instr_len_i       = 3'd1;   // encoded 1 → actual 4 bytes

        #1;
        check("Test 1a: exception_taken_o pulses",
              exception_taken_o === 1'b1,
              $sformatf("exception_taken_o = %b", exception_taken_o));

        check("Test 1b: flush_pipeline_o asserted",
              flush_pipeline_o === 1'b1,
              $sformatf("flush_pipeline_o = %b", flush_pipeline_o));

        check("Test 1c: exception_target_pc_o = exception vector",
              exception_target_pc_o === EXC_VECTOR,
              $sformatf("exception_target_pc_o = 0x%016h", exception_target_pc_o));

        @(posedge clk);
        init_inputs();

        // Now read CSR_EPC via CSR read interface (combinational)
        csr_ren_i  = 1'b1;
        csr_addr_i = CSR_EPC;
        #1;
        check("Test 1d: CSR_EPC = 0x2000",
              csr_rdata_o === 64'h2000,
              $sformatf("CSR_EPC = 0x%016h (expected 0x2000)", csr_rdata_o));
        csr_ren_i  = 1'b0;
        csr_addr_i = 12'h000;

        // Read CSR_ILLEN (should be 4, not encoded 1)
        csr_ren_i  = 1'b1;
        csr_addr_i = CSR_ILLEN;
        #1;
        check("Test 1e: CSR_ILLEN = 4 (actual bytes, not encoded 1)",
              csr_rdata_o === 64'd4,
              $sformatf("CSR_ILLEN = 0x%016h (expected 0x4)", csr_rdata_o));
        csr_ren_i  = 1'b0;
        csr_addr_i = 12'h000;

        // Clear exception state via ERET
        do_eret();
        wait_cycles(1);

        // =================================================================
        // TEST 2: ERET return address with 4-byte instruction
        // =================================================================
        $display("\n========== Test 2: ERET return address (4-byte instruction) ==========");

        csr_write(CSR_EPC,   64'h1000);
        csr_write(CSR_ILLEN, 64'd4);

        // Assert eret_exec_i
        eret_exec_i = 1'b1;
        #1;
        check("Test 2a: eret_target_o = 0x1004 (CSR_EPC+ILLEN = 0x1000+4)",
              csr_eret_target === 64'h1004,
              $sformatf("eret_target_o = 0x%016h", csr_eret_target));

        check("Test 2b: eret_target_pc_o = 0x1004",
              eret_target_pc_o === 64'h1004,
              $sformatf("eret_target_pc_o = 0x%016h", eret_target_pc_o));

        check("Test 2c: exception_target_pc_o = 0x1004 (ERET target)",
              exception_target_pc_o === 64'h1004,
              $sformatf("exception_target_pc_o = 0x%016h", exception_target_pc_o));

        @(posedge clk);
        eret_exec_i = 1'b0;
        wait_cycles(1);

        // =================================================================
        // TEST 3: ERET return address with 2-byte instruction
        // =================================================================
        $display("\n========== Test 3: ERET with 2-byte instruction ==========");

        csr_write(CSR_EPC,   64'h2000);
        csr_write(CSR_ILLEN, 64'd2);

        eret_exec_i = 1'b1;
        #1;
        check("Test 3a: eret_target_o = 0x2002 (CSR_EPC+ILLEN = 0x2000+2)",
              csr_eret_target === 64'h2002,
              $sformatf("eret_target_o = 0x%016h", csr_eret_target));

        @(posedge clk);
        eret_exec_i = 1'b0;
        wait_cycles(1);

        // =================================================================
        // TEST 4: ERET return address with 8-byte instruction
        // =================================================================
        $display("\n========== Test 4: ERET with 8-byte instruction ==========");

        csr_write(CSR_EPC,   64'h3000);
        csr_write(CSR_ILLEN, 64'd8);

        eret_exec_i = 1'b1;
        #1;
        check("Test 4a: eret_target_o = 0x3008 (CSR_EPC+ILLEN = 0x3000+8)",
              csr_eret_target === 64'h3008,
              $sformatf("eret_target_o = 0x%016h", csr_eret_target));

        @(posedge clk);
        eret_exec_i = 1'b0;
        wait_cycles(1);

        // =================================================================
        // TEST 5: Exception priority — IFU page fault over memory page fault
        // =================================================================
        $display("\n========== Test 5: Priority — IFU page fault over memory page fault ==========");

        // Assert both simultaneously
        ifu_exception_i        = 1'b1;
        ifu_exception_cause_i  = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i   = 64'h1000;
        ifu_instr_len_i        = 3'd1;

        mem_exception_i        = 1'b1;
        mem_exception_cause_i  = MEM_CAUSE_PAGE_FAULT;
        mem_exception_addr_i   = 64'h2000;
        mem_instr_len_i        = 3'd1;

        #1;
        check("Test 5a: exception_taken_o fires",
              exception_taken_o === 1'b1, "");
        @(posedge clk);
        init_inputs();

        // Check latched cause (IFU page fault = 0x0C wins over data page fault 0x0D)
        check("Test 5b: exception_cause_o = 0x0C (IFU page fault priority)",
              exception_cause_o === EXC_CAUSE_INSTR_PAGE_FAULT,
              $sformatf("exception_cause_o = 0x%0h, expected 0x0C", exception_cause_o));

        do_eret();
        wait_cycles(1);

        // =================================================================
        // TEST 6: Exception priority — page fault over illegal instruction
        // =================================================================
        $display("\n========== Test 6: Priority — page fault over illegal instruction ==========");

        // Assert IFU page fault AND decode illegal instruction simultaneously
        ifu_exception_i        = 1'b1;
        ifu_exception_cause_i  = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i   = 64'h4000;
        ifu_instr_len_i        = 3'd1;

        decode_exception_i     = 1'b1;
        decode_exception_cause_i = IFU_CAUSE_ILLEGAL_INSTR;
        decode_exception_addr_i  = 64'h4000;
        decode_instr_len_i     = 3'd1;

        #1;
        check("Test 6a: exception_taken_o fires",
              exception_taken_o === 1'b1, "");
        @(posedge clk);
        init_inputs();

        check("Test 6b: exception_cause_o = 0x0C (page fault beats illegal instr)",
              exception_cause_o === EXC_CAUSE_INSTR_PAGE_FAULT,
              $sformatf("exception_cause_o = 0x%0h, expected 0x0C", exception_cause_o));

        do_eret();
        wait_cycles(1);

        // =================================================================
        // TEST 7: Exception active state prevents new exceptions
        // =================================================================
        $display("\n========== Test 7: Exception active state prevents new exceptions ==========");

        // Trigger an exception
        ifu_exception_i       = 1'b1;
        ifu_exception_cause_i = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i  = 64'h5000;
        ifu_instr_len_i       = 3'd1;

        #1;
        check("Test 7a: exception_taken_o fires",
              exception_taken_o === 1'b1, "");
        @(posedge clk);
        init_inputs();

        // Verify exception_active_o is now set
        check("Test 7b: exception_active_o is set",
              exception_active_o === 1'b1,
              $sformatf("exception_active_o = %b", exception_active_o));

        // Now try to trigger another exception while active
        wait_cycles(1);
        ifu_exception_i       = 1'b1;
        ifu_exception_cause_i = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i  = 64'h6000;
        ifu_instr_len_i       = 3'd1;

        #1;
        check("Test 7c: exception_taken_o is NOT asserted (exception already active)",
              exception_taken_o === 1'b0,
              $sformatf("exception_taken_o = %b (expected 0)", exception_taken_o));
        @(posedge clk);
        init_inputs();

        // Execute ERET to clear exception state
        do_eret();
        wait_cycles(1);

        check("Test 7d: exception_active_o cleared after ERET",
              exception_active_o === 1'b0,
              $sformatf("exception_active_o = %b (expected 0)", exception_active_o));

        wait_cycles(1);

        // =================================================================
        // TEST 8: CSR read/write
        // =================================================================
        $display("\n========== Test 8: CSR read/write ==========");

        // Write 0xDEADBEEF to CSR_EPC
        csr_write(CSR_EPC, 64'hDEADBEEF);

        // Read back and verify
        csr_ren_i  = 1'b1;
        csr_addr_i = CSR_EPC;
        #1;
        check("Test 8a: CSR_EPC readback = 0xDEADBEEF",
              csr_rdata_o === 64'hDEADBEEF,
              $sformatf("CSR_EPC = 0x%016h", csr_rdata_o));
        csr_ren_i  = 1'b0;
        csr_addr_i = 12'h000;

        // Write 6 to CSR_ILLEN
        csr_write(CSR_ILLEN, 64'd6);

        // Read back and verify
        csr_ren_i  = 1'b1;
        csr_addr_i = CSR_ILLEN;
        #1;
        check("Test 8b: CSR_ILLEN readback = 6",
              csr_rdata_o === 64'd6,
              $sformatf("CSR_ILLEN = 0x%016h", csr_rdata_o));
        csr_ren_i  = 1'b0;
        csr_addr_i = 12'h000;

        wait_cycles(1);

        // =================================================================
        // TEST 9: Pipeline flush on exception
        // =================================================================
        $display("\n========== Test 9: Pipeline flush on exception ==========");

        // Trigger exception
        ifu_exception_i       = 1'b1;
        ifu_exception_cause_i = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i  = 64'h7000;
        ifu_instr_len_i       = 3'd1;

        #1;
        check("Test 9a: flush_pipeline_o asserted on exception",
              flush_pipeline_o === 1'b1,
              $sformatf("flush_pipeline_o = %b", flush_pipeline_o));

        check("Test 9b: exception_target_pc_o = 0x8000_0000 (exception vector)",
              exception_target_pc_o === EXC_VECTOR,
              $sformatf("exception_target_pc_o = 0x%016h", exception_target_pc_o));

        @(posedge clk);
        init_inputs();

        do_eret();
        wait_cycles(1);

        // =================================================================
        // TEST 10: All-or-nothing semantics — exception_active_o
        // =================================================================
        $display("\n========== Test 10: All-or-nothing semantics ==========");

        // Trigger an exception
        ifu_exception_i       = 1'b1;
        ifu_exception_cause_i = IFU_CAUSE_PAGE_FAULT;
        ifu_exception_addr_i  = 64'h8000;
        ifu_instr_len_i       = 3'd1;

        #1;
        @(posedge clk);
        init_inputs();

        // Verify exception_active_o is set -> memory operations should be blocked
        check("Test 10a: exception_active_o = 1 during exception handling",
              exception_active_o === 1'b1,
              $sformatf("exception_active_o = %b (memory side-effects should be blocked)", exception_active_o));

        // Clean up
        do_eret();
        wait_cycles(1);

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
            $display("============================================================\n");
        end else begin
            $display("  SOME TESTS FAILED!");
            $display("  Failures: %0d", fail_count);
            $display("============================================================\n");
        end

        $stop;
    end

endmodule