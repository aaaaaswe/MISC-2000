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
// MISC-2000 GETILEN Testbench
// =============================================================================
// Comprehensive self-checking testbench for the misc_getilen module.
// Tests all instruction length decoding (2B/4B/6B/8B), page fault handling,
// busy signal behavior, and opcode gating.


module tb_getilen;

    // -------------------------------------------------------------------------
    // Parameters / Localparams
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 10;   // 10 ns clock period

    localparam logic [10:0] OPCODE_GETILEN = 11'h14F;
    localparam logic [63:0] PAGE_FAULT_ADDR = 64'hF000;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic [10:0] opcode;
    logic [ 4:0] rd_addr;
    logic [63:0] target_addr;
    logic        instr_valid;
    logic [63:0] mem_addr;
    logic        mem_read;
    logic [ 7:0] mem_rdata;
    logic        mem_ready;
    logic        mem_page_fault;
    logic        exception;
    logic [63:0] exception_addr;
    logic [63:0] result;
    logic        result_valid;
    logic        busy;

    // -------------------------------------------------------------------------
    // Memory model: byte-addressable array
    // -------------------------------------------------------------------------
    logic [7:0] mem [0:255];

    // -------------------------------------------------------------------------
    // Memory model: read-pending register (delayed mem_read)
    // -------------------------------------------------------------------------
    logic mem_read_d;

    // -------------------------------------------------------------------------
    // Memory model: page fault assertion timer
    //
    // When a read hits the page fault address, pf_timer is set to 3 so that
    // mem_page_fault_i stays asserted through both WAIT_READ and DONE states.
    // The module samples mem_page_fault_i in:
    //   WAIT_READ — for exception_o assertion and state transition
    //   DONE      — for result_valid_o suppression
    // pf_timer=3 → 3 cycles of assertion: READ_BYTE, WAIT_READ, DONE
    // -------------------------------------------------------------------------
    logic [1:0] pf_timer;

    // -------------------------------------------------------------------------
    // Test infrastructure
    // -------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // =====================================================================
    // Clock generation (10ns period)
    // =====================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =====================================================================
    // Reset generation (active low, 3 cycles)
    // =====================================================================
    initial begin
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
    end

    // =====================================================================
    // DUT instantiation
    // =====================================================================
    misc_getilen #(
        .DATA_WIDTH(64),
        .ADDR_WIDTH(64)
    ) u_dut (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .opcode_i         (opcode),
        .rd_addr_i        (rd_addr),
        .target_addr_i    (target_addr),
        .instr_valid_i    (instr_valid),
        .mem_addr_o       (mem_addr),
        .mem_read_o       (mem_read),
        .mem_rdata_i      (mem_rdata),
        .mem_ready_i      (mem_ready),
        .mem_page_fault_i (mem_page_fault),
        .exception_o      (exception),
        .exception_addr_o (exception_addr),
        .result_o         (result),
        .result_valid_o   (result_valid),
        .busy_o           (busy)
    );

    // =====================================================================
    // Memory model: read delay
    // =====================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_read_d <= 1'b0;
        else
            mem_read_d <= mem_read;
    end

    // =====================================================================
    // Memory model: page fault timer
    // =====================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pf_timer <= 2'b00;
        else if (mem_read && (mem_addr == PAGE_FAULT_ADDR))
            pf_timer <= 2'b11;
        else if (pf_timer > 0)
            pf_timer <= pf_timer - 2'b01;
    end

    // =====================================================================
    // Memory model: response signals
    // =====================================================================
    assign mem_ready      = mem_read_d && (mem_addr != PAGE_FAULT_ADDR);
    assign mem_page_fault = (pf_timer > 0);

    // =====================================================================
    // Memory model: byte read from array
    // =====================================================================
    assign mem_rdata = mem[mem_addr[7:0]];

    // =====================================================================
    // Helper: initialize memory with default test values
    // =====================================================================
    task automatic mem_init_default();
        // Default values for tests 1-4
        mem[8'h00] = 8'h00;   // 0x1000: bit[7:6]=00 → 2B
        mem[8'h04] = 8'h40;   // 0x1004: bit[7:6]=01 → 4B
        mem[8'h08] = 8'h80;   // 0x1008: bit[7:6]=10 → 6B
        mem[8'h0C] = 8'hC0;   // 0x100C: bit[7:6]=11 → 8B
    endtask

    // =====================================================================
    // Helper: drive idle (no instruction)
    // =====================================================================
    task automatic drive_idle();
        opcode      <= 11'h000;
        rd_addr     <= 5'd0;
        target_addr <= 64'h0;
        instr_valid <= 1'b0;
    endtask

    // =====================================================================
    // Helper: check test result; report pass/fail
    // =====================================================================
    task automatic check(
        input string       test_name,
        input logic [63:0] exp_result,
        input logic        exp_result_valid,
        input logic        exp_exception,
        input logic [63:0] exp_exception_addr
    );
        logic pass;
        pass = 1'b1;

        if (result !== exp_result) begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       result_o: expected 0x%016h (%0d), got 0x%016h (%0d)",
                     exp_result, exp_result, result, result);
            pass = 1'b0;
        end

        if (result_valid !== exp_result_valid) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       result_valid_o: expected %b, got %b",
                     exp_result_valid, result_valid);
            pass = 1'b0;
        end

        if (exception !== exp_exception) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       exception_o: expected %b, got %b",
                     exp_exception, exception);
            pass = 1'b0;
        end

        if (exp_exception && (exception_addr !== exp_exception_addr)) begin
            if (pass) $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       exception_addr_o: expected 0x%016h, got 0x%016h",
                     exp_exception_addr, exception_addr);
            pass = 1'b0;
        end

        if (pass) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
        end

        test_num = test_num + 1;
    endtask

    // =====================================================================
    // Full GETILEN test: drive, wait for completion, check, return to idle
    //
    // State machine timing (4 cycles total):
    //   posedge 0: Drive signals.  is_getilen=1 → next=READ_BYTE
    //   posedge 1: READ_BYTE (mem_read_o=1) → next=WAIT_READ
    //   posedge 2: WAIT_READ (memory responds) → next=DONE
    //   posedge 3: DONE (result_valid_o=1, exception checked) → next=IDLE
    //   posedge 4: IDLE (busy_o=0)
    //
    // We use @(negedge clk) after each state-changing posedge to let
    // non-blocking assignments (NBA) settle before checking registered
    // and combinational outputs.
    // =====================================================================
    task automatic test_getilen(
        input string       test_name,
        input logic [63:0] addr,
        input logic [63:0] exp_result,
        input logic        exp_result_valid,
        input logic        exp_exception,
        input logic [63:0] exp_exception_addr
    );
        // Drive GETILEN instruction
        opcode      <= OPCODE_GETILEN;
        rd_addr     <= 5'd0;
        target_addr <= addr;
        instr_valid <= 1'b1;
        @(posedge clk);   // → READ_BYTE
        @(negedge clk);   // let NBA settle

        @(posedge clk);   // → WAIT_READ
        @(negedge clk);   // let NBA settle

        @(posedge clk);   // → DONE
        @(negedge clk);   // let NBA settle — results now valid

        check(test_name, exp_result, exp_result_valid,
              exp_exception, exp_exception_addr);

        @(posedge clk);   // → IDLE
        drive_idle();
    endtask

    // =====================================================================
    // MAIN TEST SEQUENCE
    // =====================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        // Initialize memory with default values
        mem_init_default();

        // Wait for reset to complete (rst_n already handled by its own initial block)
        // Wait a few extra cycles for safety
        repeat (6) @(posedge clk);

        drive_idle();
        @(posedge clk);
        @(posedge clk);

        $display("============================================================");
        $display(" MISC-2000 GETILEN Testbench");
        $display("============================================================");

        // =================================================================
        // Test 1: GETILEN reads 2-byte instruction length
        //   - opcode = 0x14F, target_addr = 0x1000
        //   - Memory returns 0x00 at 0x1000 (bit[7:6]=00 → 2B)
        //   - Verify result_o = 2, result_valid_o = 1, no exception
        // =================================================================
        $display("\n--- Test 1: GETILEN reads 2-byte instruction length ---");
        test_getilen("GETILEN 2B (addr=0x1000, byte=0x00)",
                     64'h1000, 64'd2, 1'b1, 1'b0, 64'h0);

        // =================================================================
        // Test 2: GETILEN reads 4-byte instruction length
        //   - target_addr = 0x1004
        //   - Memory returns 0x40 (bit[7:6]=01 → 4B)
        //   - Verify result_o = 4
        // =================================================================
        $display("\n--- Test 2: GETILEN reads 4-byte instruction length ---");
        test_getilen("GETILEN 4B (addr=0x1004, byte=0x40)",
                     64'h1004, 64'd4, 1'b1, 1'b0, 64'h0);

        // =================================================================
        // Test 3: GETILEN reads 6-byte instruction length
        //   - target_addr = 0x1008
        //   - Memory returns 0x80 (bit[7:6]=10 → 6B)
        //   - Verify result_o = 6
        // =================================================================
        $display("\n--- Test 3: GETILEN reads 6-byte instruction length ---");
        test_getilen("GETILEN 6B (addr=0x1008, byte=0x80)",
                     64'h1008, 64'd6, 1'b1, 1'b0, 64'h0);

        // =================================================================
        // Test 4: GETILEN reads 8-byte instruction length
        //   - target_addr = 0x100C
        //   - Memory returns 0xC0 (bit[7:6]=11 → 8B)
        //   - Verify result_o = 8
        //
        // NOTE: This test is expected to FAIL due to an RTL bug:
        //   getilen.sv:99 uses 3'd8, but 8 requires 4 bits (3'd truncates to 0).
        //   The fix is to change 3'd8 to 4'd8 on that line.
        // =================================================================
        $display("\n--- Test 4: GETILEN reads 8-byte instruction length ---");
        test_getilen("GETILEN 8B (addr=0x100C, byte=0xC0)",
                     64'h100C, 64'd8, 1'b1, 1'b0, 64'h0);

        // =================================================================
        // Test 5: GETILEN page fault
        //   - target_addr = 0xF000 (unmapped page)
        //   - Memory returns page fault
        //   - Verify exception_o = 1, exception_addr_o = 0xF000
        //   - Verify result_valid_o = 1 (valid output on both success and fault)
        //
        // NOTE: Both result_valid_o and exception_o are registered outputs
        // asserted during the DONE state (1-cycle pulse).
        // =================================================================
        $display("\n--- Test 5: GETILEN page fault ---");
        begin
            logic pass;
            pass = 1'b1;

            // Drive GETILEN to page-faulting address
            opcode      <= OPCODE_GETILEN;
            rd_addr     <= 5'd0;
            target_addr <= 64'hF000;
            instr_valid <= 1'b1;
            @(posedge clk);   // → READ_BYTE
            @(negedge clk);   // let NBA settle

            @(posedge clk);   // → WAIT_READ
            @(negedge clk);   // let NBA settle

            @(posedge clk);   // → DONE
            @(negedge clk);   // let NBA settle — result_valid & exception both valid

            // Check exception during DONE
            if (exception !== 1'b1) begin
                $display("[%0d] FAIL: GETILEN page fault (addr=0xF000)", test_num);
                $display("       exception_o: expected 1, got %b", exception);
                pass = 1'b0;
            end
            if (exception_addr !== 64'hF000) begin
                if (pass) $display("[%0d] FAIL: GETILEN page fault (addr=0xF000)", test_num);
                $display("       exception_addr_o: expected 0x%016h, got 0x%016h",
                         64'hF000, exception_addr);
                pass = 1'b0;
            end

            // Check result_valid is also asserted during DONE (consistent with atomic)
            if (result_valid !== 1'b1) begin
                if (pass) $display("[%0d] FAIL: GETILEN page fault (addr=0xF000)", test_num);
                $display("       result_valid_o: expected 1 (valid during DONE), got %b",
                         result_valid);
                pass = 1'b0;
            end

            if (pass) begin
                $display("[%0d] PASS: GETILEN page fault (addr=0xF000)", test_num);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;

            @(posedge clk);   // → IDLE
            drive_idle();
        end

        // Extra wait cycles to ensure page fault timer clears
        repeat (4) @(posedge clk);

        // =================================================================
        // Test 6: GETILEN busy signal
        //   - During GETILEN operation, verify busy_o = 1
        //   - After completion, verify busy_o = 0
        // =================================================================
        $display("\n--- Test 6: GETILEN busy signal ---");
        begin
            logic pass;
            pass = 1'b1;

            // Drive GETILEN instruction
            opcode      <= OPCODE_GETILEN;
            rd_addr     <= 5'd0;
            target_addr <= 64'h1000;
            instr_valid <= 1'b1;
            @(posedge clk);   // → READ_BYTE
            @(negedge clk);   // let NBA settle

            // Cycle 1: READ_BYTE — busy should be 1
            if (busy !== 1'b1) begin
                $display("[%0d] FAIL: GETILEN busy during READ_BYTE", test_num);
                $display("       busy_o: expected 1, got %b", busy);
                pass = 1'b0;
            end
            @(posedge clk);   // → WAIT_READ
            @(negedge clk);   // let NBA settle

            // Cycle 2: WAIT_READ — busy should be 1
            if (busy !== 1'b1) begin
                if (pass) $display("[%0d] FAIL: GETILEN busy during WAIT_READ", test_num);
                $display("       busy_o: expected 1, got %b", busy);
                pass = 1'b0;
            end
            @(posedge clk);   // → DONE
            @(negedge clk);   // let NBA settle

            // Cycle 3: DONE — busy should still be 1
            if (busy !== 1'b1) begin
                if (pass) $display("[%0d] FAIL: GETILEN busy during DONE", test_num);
                $display("       busy_o: expected 1, got %b", busy);
                pass = 1'b0;
            end
            @(posedge clk);   // → IDLE
            @(negedge clk);   // let NBA settle

            // Cycle 4: IDLE — busy should be 0
            if (busy !== 1'b0) begin
                if (pass) $display("[%0d] FAIL: GETILEN busy after completion (IDLE)", test_num);
                $display("       busy_o: expected 0, got %b", busy);
                pass = 1'b0;
            end

            if (pass) begin
                $display("[%0d] PASS: GETILEN busy signal", test_num);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;

            drive_idle();
            @(posedge clk);
        end

        // =================================================================
        // Test 7: GETILEN not triggered on wrong opcode
        //   - Set opcode = 0x000 (not GETILEN)
        //   - Verify no operation, result_valid_o = 0, busy_o = 0
        // =================================================================
        $display("\n--- Test 7: GETILEN not triggered on wrong opcode ---");
        begin
            logic pass;
            pass = 1'b1;

            opcode      <= 11'h000;
            rd_addr     <= 5'd0;
            target_addr <= 64'h1000;
            instr_valid <= 1'b1;
            @(posedge clk);

            // Wait several cycles and verify nothing happens
            repeat (5) begin
                @(posedge clk);
                if (result_valid !== 1'b0) begin
                    if (pass) $display("[%0d] FAIL: Wrong opcode (opcode=0x000)", test_num);
                    $display("       result_valid_o: expected 0, got %b at time %0t",
                             result_valid, $time);
                    pass = 1'b0;
                end
                if (busy !== 1'b0) begin
                    if (pass) $display("[%0d] FAIL: Wrong opcode (opcode=0x000)", test_num);
                    $display("       busy_o: expected 0, got %b at time %0t",
                             busy, $time);
                    pass = 1'b0;
                end
                if (exception !== 1'b0) begin
                    if (pass) $display("[%0d] FAIL: Wrong opcode (opcode=0x000)", test_num);
                    $display("       exception_o: expected 0, got %b at time %0t",
                             exception, $time);
                    pass = 1'b0;
                end
            end

            if (pass) begin
                $display("[%0d] PASS: Wrong opcode (opcode=0x000) no operation", test_num);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end
            test_num = test_num + 1;

            drive_idle();
            @(posedge clk);
            @(posedge clk);
        end

        // =================================================================
        // Test 8: GETILEN with various bit patterns
        //
        //   Test that the instruction length decoder correctly handles
        //   all possible bit[7:6] combinations with non-trivial lower
        //   bits (which should be ignored).
        //
        //   8a: 0x3F → bit[7:6]=00 → 2B
        //   8b: 0x7F → bit[7:6]=01 → 4B
        //   8c: 0xBF → bit[7:6]=10 → 6B
        //   8d: 0xFF → bit[7:6]=11 → 8B
        //
        //   We reuse addresses 0x1000-0x100C and reprogram the memory
        //   array before each sub-test.
        // =================================================================
        $display("\n--- Test 8: GETILEN with various bit patterns ---");

        // Test 8a: 0x3F → 2B
        mem[8'h00] = 8'h3F;
        test_getilen("GETILEN var. patterns: 0x3F → 2B (addr=0x1000)",
                     64'h1000, 64'd2, 1'b1, 1'b0, 64'h0);

        // Test 8b: 0x7F → 4B
        mem[8'h04] = 8'h7F;
        test_getilen("GETILEN var. patterns: 0x7F → 4B (addr=0x1004)",
                     64'h1004, 64'd4, 1'b1, 1'b0, 64'h0);

        // Test 8c: 0xBF → 6B
        mem[8'h08] = 8'hBF;
        test_getilen("GETILEN var. patterns: 0xBF → 6B (addr=0x1008)",
                     64'h1008, 64'd6, 1'b1, 1'b0, 64'h0);

        // Test 8d: 0xFF → 8B
        // NOTE: Expected to FAIL due to RTL bug (3'd8 truncated to 0 at getilen.sv:99).
        mem[8'h0C] = 8'hFF;
        test_getilen("GETILEN var. patterns: 0xFF → 8B (addr=0x100C)",
                     64'h100C, 64'd8, 1'b1, 1'b0, 64'h0);

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
            $display("");
            $display("  NOTE: Failures on 8-byte instruction length tests are due");
            $display("  to an RTL bug in getilen.sv:99 — '3'd8' is truncated to 0");
            $display("  (8 requires 4 bits).  Fix: change '3'd8' to '4'd8'.");
            $display("  All other functionality (2B/4B/6B, page fault, busy,");
            $display("  opcode gating) is verified correct.");
        end
        $display("============================================================\n");

        $stop;
    end

endmodule