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
// MISC-2000 Atomic Instruction Testbench
// =============================================================================
// Comprehensive self-checking testbench for the misc_atomic and misc_csr
// modules. Tests LL.D (Load Linked), SC.D (Store Conditional), CAS.D
// (Compare and Swap), cross-page detection, FENCE, and page-fault handling.

`include "../rtl/core/atomic.sv"
`include "../rtl/core/csr.sv"

`timescale 1ns / 1ps

module tb_atomic;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int DATA_WIDTH = 64;
    localparam int ADDR_WIDTH = 64;
    localparam int CLK_PERIOD = 10;   // 10 ns

    // =========================================================================
    // Opcode Constants
    // =========================================================================
    localparam logic [10:0] OP_LL_D    = 11'h040;
    localparam logic [10:0] OP_SC_D    = 11'h041;
    localparam logic [10:0] OP_CAS_IMM = 11'h144;
    localparam logic [10:0] OP_FENCE   = 11'h15E;

    // =========================================================================
    // CSR Address Constants
    // =========================================================================
    localparam logic [11:0] CSR_MONITOR_ADDR  = 12'h340;
    localparam logic [11:0] CSR_MONITOR_VALID = 12'h341;

    // =========================================================================
    // DUT Signals — misc_atomic
    // =========================================================================
    logic                       clk;
    logic                       rst_n;
    logic [10:0]                opcode;
    logic [4:0]                 rd_addr;
    logic [4:0]                 rs1_addr;
    logic [4:0]                 rs2_addr;
    logic [DATA_WIDTH-1:0]      rs1_data;
    logic [DATA_WIDTH-1:0]      rs2_data;
    logic [ADDR_WIDTH-1:0]      inst_addr;
    logic                       instr_valid;
    logic [ADDR_WIDTH-1:0]      mem_addr;
    logic [DATA_WIDTH-1:0]      mem_wdata;
    logic                       mem_read;
    logic                       mem_write;
    logic [DATA_WIDTH-1:0]      mem_rdata;
    logic                       mem_ready;
    logic                       mem_page_fault;
    logic                       ll_exec;
    logic [ADDR_WIDTH-1:0]      ll_addr;
    logic                       sc_exec;
    logic                       sc_success;
    logic                       monitor_clear;
    logic                       exception;
    logic [ADDR_WIDTH-1:0]      exception_addr;
    logic [DATA_WIDTH-1:0]      result;
    logic                       result_valid;
    logic                       busy;
    logic                       fence_exec;

    // =========================================================================
    // DUT Signals — misc_csr
    // =========================================================================
    logic                       csr_ren_i;
    logic                       csr_wen_i;
    logic [11:0]                csr_addr;
    logic [DATA_WIDTH-1:0]      csr_wdata;
    logic [DATA_WIDTH-1:0]      csr_rdata;

    // =========================================================================
    // Memory Model
    // =========================================================================
    logic [DATA_WIDTH-1:0]      mem_array [logic [ADDR_WIDTH-1:0]];
    logic                       mem_responding;  // flag: memory is handling a request
    logic [ADDR_WIDTH-1:0]      mem_req_addr;
    logic                       mem_req_is_write;
    logic [DATA_WIDTH-1:0]      mem_req_wdata;
    logic                       mem_fault;        // internal: asserted on next response when inject is set
    logic                       mem_fault_inject; // testbench sets this to inject a page fault

    // =========================================================================
    // Test Infrastructure
    // =========================================================================
    integer pass_count;
    integer fail_count;
    integer test_num;

    // Internal monitor tracking (for SC success determination)
    logic                       tb_monitor_valid;
    logic [ADDR_WIDTH-1:0]      tb_monitor_addr;

    // Pulse capture flags — latch rising edges of pulsed outputs
    logic                       ll_exec_captured;
    logic                       sc_exec_captured;
    logic                       fence_exec_captured;

    // =========================================================================
    // Clock Generation — 10 ns period, 5 ns high / 5 ns low
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // DUT Instantiation — misc_atomic
    // =========================================================================
    misc_atomic #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_atomic (
        .clk_i           (clk),
        .rst_n_i         (rst_n),
        .opcode_i        (opcode),
        .rd_addr_i       (rd_addr),
        .rs1_addr_i      (rs1_addr),
        .rs2_addr_i      (rs2_addr),
        .rs1_data_i      (rs1_data),
        .rs2_data_i      (rs2_data),
        .inst_addr_i     (inst_addr),
        .instr_valid_i   (instr_valid),
        .mem_addr_o      (mem_addr),
        .mem_wdata_o     (mem_wdata),
        .mem_read_o      (mem_read),
        .mem_write_o     (mem_write),
        .mem_rdata_i     (mem_rdata),
        .mem_ready_i     (mem_ready),
        .mem_page_fault_i(mem_page_fault),
        .ll_exec_o       (ll_exec),
        .ll_addr_o       (ll_addr),
        .sc_exec_o       (sc_exec),
        .sc_success_i    (sc_success),
        .monitor_clear_i (monitor_clear),
        .exception_o     (exception),
        .exception_addr_o(exception_addr),
        .result_o        (result),
        .result_valid_o  (result_valid),
        .busy_o          (busy),
        .fence_exec_o    (fence_exec)
    );

    // =========================================================================
    // DUT Instantiation — misc_csr
    // =========================================================================
    misc_csr #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_csr (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .csr_ren_i        (csr_ren_i),
        .csr_wen_i        (csr_wen_i),
        .csr_addr_i       (csr_addr),
        .csr_wdata_i      (csr_wdata),
        .csr_rdata_o      (csr_rdata),
        .exception_taken_i(1'b0),
        .exception_pc_i   ('0),
        .exception_ilen_i ('0),
        .exception_cause_i('0),
        .eret_exec_i      (1'b0),
        .eret_target_o    (),
        .ll_exec_i        (ll_exec),
        .ll_addr_i        (ll_addr),
        .sc_exec_i        (sc_exec),
        .sc_success_o     (sc_success),
        .monitor_clear_i  (1'b0)
    );

    // =========================================================================
    // Memory Model Logic
    // =========================================================================
    // On a read or write request, latch the request and respond next cycle.
    // The memory model is a simple single-cycle response model.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_responding  <= 1'b0;
            mem_req_addr    <= '0;
            mem_req_is_write <= 1'b0;
            mem_req_wdata   <= '0;
            mem_ready       <= 1'b0;
            mem_rdata       <= '0;
            mem_page_fault  <= 1'b0;
            mem_fault       <= 1'b0;
        end else begin
            // Default: deassert ready and page_fault
            mem_ready      <= 1'b0;
            mem_page_fault <= 1'b0;

            // Latch fault injection request
            if (mem_fault_inject)
                mem_fault <= 1'b1;

            if (mem_responding) begin
                // Respond this cycle
                mem_ready      <= 1'b1;
                mem_responding <= 1'b0;
                if (mem_fault) begin
                    mem_page_fault <= 1'b1;
                    mem_fault      <= 1'b0;
                end else if (mem_req_is_write) begin
                    mem_array[mem_req_addr] <= mem_req_wdata;
                end else begin
                    // Read: provide data from memory array
                    if (mem_array.exists(mem_req_addr))
                        mem_rdata <= mem_array[mem_req_addr];
                    else
                        mem_rdata <= '0;
                end
            end else if (mem_read || mem_write) begin
                // Latch new request, respond next cycle
                mem_responding  <= 1'b1;
                mem_req_addr    <= mem_addr;
                mem_req_is_write <= mem_write;
                mem_req_wdata   <= mem_wdata;
            end
        end
    end

    // =========================================================================
    // Pulse Capture — latch rising edges of pulsed outputs
    // =========================================================================
    // ll_exec_o, sc_exec_o, and fence_exec_o are pulsed for one cycle.
    // We capture them so they can be checked later in the test sequence.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ll_exec_captured    <= 1'b0;
            sc_exec_captured    <= 1'b0;
            fence_exec_captured <= 1'b0;
        end else begin
            if (ll_exec)    ll_exec_captured    <= 1'b1;
            if (sc_exec)    sc_exec_captured    <= 1'b1;
            if (fence_exec) fence_exec_captured <= 1'b1;
        end
    end

    // =========================================================================
    // Monitor tracking for testbench (for verification purposes only)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb_monitor_valid <= 1'b0;
            tb_monitor_addr  <= '0;
        end else begin
            if (ll_exec) begin
                tb_monitor_valid <= 1'b1;
                tb_monitor_addr  <= ll_addr;
            end
            if (monitor_clear || (sc_exec && sc_success)) begin
                tb_monitor_valid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Helper Tasks
    // =========================================================================

    // -------------------------------------------------------------------------
    // Apply reset: active low, 3 cycles
    // -------------------------------------------------------------------------
    task automatic apply_reset();
        rst_n <= 1'b0;
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Initialize all DUT inputs to safe defaults
    // -------------------------------------------------------------------------
    task automatic init_inputs();
        opcode           <= 11'h000;
        rd_addr          <= 5'd0;
        rs1_addr         <= 5'd0;
        rs2_addr         <= 5'd0;
        rs1_data         <= '0;
        rs2_data         <= '0;
        inst_addr        <= '0;
        instr_valid      <= 1'b0;
        monitor_clear    <= 1'b0;
        csr_ren_i        <= 1'b0;
        csr_wen_i        <= 1'b0;
        csr_addr         <= 12'h000;
        csr_wdata        <= '0;
        mem_fault_inject <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Clear pulse capture flags (call before each test that checks pulses)
    // -------------------------------------------------------------------------
    task automatic clear_captures();
        ll_exec_captured    <= 1'b0;
        sc_exec_captured    <= 1'b0;
        fence_exec_captured <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Issue an instruction to the atomic module
    // -------------------------------------------------------------------------
    task automatic issue_instr(
        input logic [10:0]           op,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] rs2_val,
        input logic [ADDR_WIDTH-1:0] i_addr
    );
        opcode      <= op;
        rs1_data    <= addr;
        rs2_data    <= rs2_val;
        inst_addr   <= i_addr;
        instr_valid <= 1'b1;
        @(posedge clk);
        instr_valid <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Wait for memory operation to complete (mem_ready asserted)
    // -------------------------------------------------------------------------
    task automatic wait_mem_ready();
        // Wait until memory responds, or timeout
        repeat (100) begin
            @(posedge clk);
            if (mem_ready) begin
                @(posedge clk);  // consume the ready cycle
                return;
            end
        end
        $display("[%0d] ERROR: Memory timeout — mem_ready never asserted", test_num);
    endtask

    // -------------------------------------------------------------------------
    // Wait for result_valid
    // -------------------------------------------------------------------------
    task automatic wait_result_valid();
        repeat (100) begin
            @(posedge clk);
            if (result_valid) begin
                return;
            end
        end
        $display("[%0d] ERROR: Result timeout — result_valid never asserted", test_num);
    endtask

    // -------------------------------------------------------------------------
    // Read a CSR register
    // -------------------------------------------------------------------------
    task automatic read_csr(
        input  logic [11:0]           addr,
        output logic [DATA_WIDTH-1:0] data
    );
        csr_ren_i <= 1'b1;
        csr_addr  <= addr;
        @(posedge clk);
        data = csr_rdata;
        csr_ren_i <= 1'b0;
        csr_addr  <= 12'h000;
    endtask

    // -------------------------------------------------------------------------
    // Preload memory with a value at a given address
    // -------------------------------------------------------------------------
    task automatic mem_store(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
        mem_array[addr] = data;
    endtask

    // -------------------------------------------------------------------------
    // Read from memory array
    // -------------------------------------------------------------------------
    function automatic logic [DATA_WIDTH-1:0] mem_load(
        input logic [ADDR_WIDTH-1:0] addr
    );
        if (mem_array.exists(addr))
            return mem_array[addr];
        else
            return '0;
    endfunction

    // -------------------------------------------------------------------------
    // Check and report pass/fail
    // -------------------------------------------------------------------------
    task automatic check(
        input string                test_name,
        input logic [DATA_WIDTH-1:0] actual,
        input logic [DATA_WIDTH-1:0] expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            $display("       Expected: 0x%016h  Got: 0x%016h", expected, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected: 0x%016h  Got: 0x%016h", expected, actual);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;
    endtask

    // -------------------------------------------------------------------------
    // Check a boolean condition
    // -------------------------------------------------------------------------
    task automatic check_bool(
        input string  test_name,
        input logic   actual,
        input logic   expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            $display("       Expected: %b  Got: %b", expected, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected: %b  Got: %b", expected, actual);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;
    endtask

    // -------------------------------------------------------------------------
    // Check a 64-bit value with a formatted message
    // -------------------------------------------------------------------------
    task automatic check_val(
        input string                test_name,
        input logic [DATA_WIDTH-1:0] actual,
        input logic [DATA_WIDTH-1:0] expected
    );
        check(test_name, actual, expected);
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        $display("============================================================");
        $display(" MISC-2000 Atomic Instruction Testbench");
        $display("============================================================");

        // Initialize all inputs
        init_inputs();

        // Apply reset
        $display("\n--- Applying Reset (active low, 3 cycles) ---");
        apply_reset();
        $display("Reset complete.\n");

        // =====================================================================
        // Test 1: LL.D — Load Linked
        // =====================================================================
        $display("--- Test 1: LL.D — Load Linked ---");

        // Preload memory at 0x1000
        mem_store(64'h1000, 64'hDEADBEEF_CAFEBABE);

        // Clear previous captures
        clear_captures();

        // Issue LL.D at address 0x1000
        issue_instr(OP_LL_D, 64'h1000, 64'h0, 64'h0);

        // Wait for memory read to complete
        wait_mem_ready();

        // Wait for result_valid
        wait_result_valid();

        // Verify result
        check_val("LL.D result = 0xDEADBEEF_CAFEBABE", result, 64'hDEADBEEF_CAFEBABE);
        check_bool("LL.D result_valid = 1", result_valid, 1'b1);
        check_bool("LL.D ll_exec_o pulsed", ll_exec_captured, 1'b1);
        check_val("LL.D ll_addr_o = 0x1000", ll_addr, 64'h1000);

        // =====================================================================
        // Test 2: LL.D sets monitor (CSR readback)
        // =====================================================================
        $display("\n--- Test 2: LL.D sets monitor (CSR readback) ---");

        begin
            logic [DATA_WIDTH-1:0] csr_data;
            logic [ADDR_WIDTH-1:0] expected_monitor_addr;

            // Read CSR_MONITOR_VALID
            read_csr(CSR_MONITOR_VALID, csr_data);
            check_bool("CSR_MONITOR_VALID = 1", csr_data[0], 1'b1);

            // Read CSR_MONITOR_ADDR
            read_csr(CSR_MONITOR_ADDR, csr_data);
            expected_monitor_addr = {64'h1000[63:6], 6'b0};  // 64-byte aligned
            check_val("CSR_MONITOR_ADDR = 64-byte aligned 0x1000", csr_data[ADDR_WIDTH-1:0], expected_monitor_addr);
        end

        // =====================================================================
        // Test 3: SC.D success
        // =====================================================================
        $display("\n--- Test 3: SC.D success ---");

        // First execute LL.D at address 0x2000 (sets monitor)
        mem_store(64'h2000, 64'h0);  // initial value (don't care)
        clear_captures();
        issue_instr(OP_LL_D, 64'h2000, 64'h0, 64'h0);
        wait_mem_ready();
        wait_result_valid();

        // Now execute SC.D at address 0x2000 with store data
        clear_captures();
        issue_instr(OP_SC_D, 64'h2000, 64'h12345678_9ABCDEF0, 64'h0);

        // Wait for SC to complete (memory write + result)
        wait_mem_ready();
        wait_result_valid();

        // Verify sc_exec_o pulsed
        check_bool("SC.D sc_exec_o pulsed", sc_exec_captured, 1'b1);
        // Verify result = 0 (success)
        check_val("SC.D result = 0 (success)", result, 64'h0);
        // Verify memory now contains the store data
        check_val("SC.D memory[0x2000] = 0x12345678_9ABCDEF0", mem_load(64'h2000), 64'h12345678_9ABCDEF0);

        // =====================================================================
        // Test 4: SC.D failure after monitor clear
        // =====================================================================
        $display("\n--- Test 4: SC.D failure after monitor clear ---");

        // Preload memory at 0x3000 with a known value
        mem_store(64'h3000, 64'hAAAAAAAA_BBBBBBBB);

        // Execute LL.D at address 0x3000
        issue_instr(OP_LL_D, 64'h3000, 64'h0, 64'h0);
        wait_mem_ready();
        wait_result_valid();

        // Assert monitor_clear (simulating another core's write)
        @(posedge clk);
        monitor_clear <= 1'b1;
        @(posedge clk);
        monitor_clear <= 1'b0;

        // Execute SC.D at address 0x3000
        issue_instr(OP_SC_D, 64'h3000, 64'hDEADDEAD_DEADDEAD, 64'h0);
        wait_mem_ready();
        wait_result_valid();

        // Verify result = 1 (failure)
        check_val("SC.D failure result = 1", result, 64'h1);
        // Verify memory NOT modified
        check_val("SC.D memory[0x3000] unchanged", mem_load(64'h3000), 64'hAAAAAAAA_BBBBBBBB);

        // =====================================================================
        // Test 5: CAS.D — Compare and Swap (match)
        // =====================================================================
        $display("\n--- Test 5: CAS.D — Compare and Swap (match) ---");

        // Preload memory at 0x4000 with compare value
        mem_store(64'h4000, 64'h11111111_22222222);

        // Issue CAS.D: rs1_data = address (0x4000), rs2_data = compare value
        // CAS.D stores new value (from rs2_data upper or encoded) and returns old value
        // The CAS.D opcode 0x144 uses rs2_data as the new value to write,
        // and compares against memory. If match, writes new value.
        // For CAS.D, we need to provide the new value somehow.
        // In typical CAS encoding, rs2 holds new value, memory holds old/expected.
        // Let's use: rs2_data = new_value, and the compare value is in memory.
        issue_instr(OP_CAS_IMM, 64'h4000, 64'hCAFECAFE_CAFECAFE, 64'h0);

        wait_mem_ready();  // CAS reads memory
        // CAS may need another memory cycle for write
        if (mem_read || mem_write)
            wait_mem_ready();
        wait_result_valid();

        // Verify CAS returns old value (which equals compare value)
        check_val("CAS.D match: result = old value", result, 64'h11111111_22222222);
        // Verify memory now contains new value
        check_val("CAS.D match: memory[0x4000] = new value", mem_load(64'h4000), 64'hCAFECAFE_CAFECAFE);

        // =====================================================================
        // Test 6: CAS.D — Compare and Swap (no match)
        // =====================================================================
        $display("\n--- Test 6: CAS.D — Compare and Swap (no match) ---");

        // Preload memory at 0x5000 with a DIFFERENT value than compare
        mem_store(64'h5000, 64'hFFFFFFFF_00000000);

        // Issue CAS.D with new value (different from memory)
        issue_instr(OP_CAS_IMM, 64'h5000, 64'hBEEFBEEF_BEEFBEEF, 64'h0);

        wait_mem_ready();
        if (mem_read || mem_write)
            wait_mem_ready();
        wait_result_valid();

        // Verify CAS returns old value (NOT equal to expected compare)
        check_val("CAS.D no-match: result = old value", result, 64'hFFFFFFFF_00000000);
        // Verify memory NOT modified
        check_val("CAS.D no-match: memory[0x5000] unchanged", mem_load(64'h5000), 64'hFFFFFFFF_00000000);

        // =====================================================================
        // Test 7: CAS cross-page detection
        // =====================================================================
        $display("\n--- Test 7: CAS cross-page detection ---");

        // Set inst_addr to 0x1FFE (4-byte instruction crossing page boundary)
        // Set opcode in 0x144-0x148 range (CAS range)
        // The 4-byte instruction at 0x1FFE spans [0x1FFE, 0x1FFF, 0x2000, 0x2001]
        // which crosses the 4KB page boundary at 0x2000
        issue_instr(OP_CAS_IMM, 64'h0, 64'h0, 64'h1FFE);

        wait_result_valid();

        check_bool("CAS cross-page: exception_o = 1", exception, 1'b1);
        check_val("CAS cross-page: exception_addr_o = 0x1FFE", exception_addr, 64'h1FFE);

        // =====================================================================
        // Test 8: FENCE instruction
        // =====================================================================
        $display("\n--- Test 8: FENCE instruction ---");

        clear_captures();

        // Issue FENCE opcode
        issue_instr(OP_FENCE, 64'h0, 64'h0, 64'h0);

        // FENCE should pulse fence_exec_o for one cycle
        // Wait a few cycles for the pulse to be captured
        repeat (5) @(posedge clk);

        check_bool("FENCE fence_exec_o pulsed", fence_exec_captured, 1'b1);

        // =====================================================================
        // Test 9: LL.D page fault
        // =====================================================================
        $display("\n--- Test 9: LL.D page fault ---");

        // Pulse mem_fault_inject for one cycle to inject a page fault
        mem_fault_inject <= 1'b1;
        @(posedge clk);
        mem_fault_inject <= 1'b0;

        // Issue LL.D
        issue_instr(OP_LL_D, 64'h6000, 64'h0, 64'h0);

        // Wait for memory response (which will have page_fault)
        wait_mem_ready();

        // Wait for result or exception
        wait_result_valid();

        check_bool("LL.D page fault: exception_o = 1", exception, 1'b1);

        // =====================================================================
        // Test 10: SC.D page fault during write
        // =====================================================================
        $display("\n--- Test 10: SC.D page fault during write ---");

        // First execute LL.D at address 0x7000 (success)
        mem_store(64'h7000, 64'h0);
        issue_instr(OP_LL_D, 64'h7000, 64'h0, 64'h0);
        wait_mem_ready();
        wait_result_valid();

        // Pulse mem_fault_inject for one cycle to inject a page fault on SC write
        mem_fault_inject <= 1'b1;
        @(posedge clk);
        mem_fault_inject <= 1'b0;

        // Execute SC.D at address 0x7000
        issue_instr(OP_SC_D, 64'h7000, 64'hFEEDFEED_FEEDFEED, 64'h0);

        wait_mem_ready();
        wait_result_valid();

        check_bool("SC.D page fault: exception_o = 1", exception, 1'b1);

        // =====================================================================
        // SUMMARY
        // =====================================================================
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

        $stop;
    end

    // =========================================================================
    // Monitor: detect ll_exec and sc_exec pulses for verification
    // =========================================================================
    // These are captured in the main test sequence via the signals directly.
    // The ll_exec and sc_exec signals are combinatorial/registered outputs
    // that we sample after the operation completes.

endmodule