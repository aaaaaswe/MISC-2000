//=============================================================================
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
//=============================================================================
//
// MISC-2000 Instruction Fetch Unit (misc_ifu) Testbench
//
// Comprehensive self-checking testbench for the misc_ifu module.
// Tests all instruction lengths (2/4/6/8 bytes), cross-page detection,
// page faults, pipeline control (flush/stall/branch), and atomic
// cross-page detection.
//
// The IFU presents instruction outputs in the DONE state.  With
// stall_i=0 the DONE→FETCH_FIRST transition happens immediately (the
// last NBA to instr_valid_o wins and clears it).  Therefore normal-fetch
// tests use stall_i=1 to hold the IFU in DONE while outputs are sampled.
// Exception tests do not need stall because the exception is latched.
//=============================================================================


`timescale 1ns / 1ps

module tb_ifu;

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam int DATA_WIDTH = 64;
    localparam int ADDR_WIDTH = 64;
    localparam int CLK_PERIOD = 10;   // 10 ns

    localparam int MEM_DEPTH = 65536; // 64K 16-bit words

    // Exception cause encodings (mirror IFU internal)
    localparam logic [1:0] EXC_PAGE_FAULT        = 2'b00;
    localparam logic [1:0] EXC_ILLEGAL_INSTR     = 2'b01;
    localparam logic [1:0] EXC_ATOMIC_CROSS_PAGE = 2'b10;

    // Instruction length encodings (mirror IFU internal)
    localparam logic [2:0] LEN_2B = 3'd0;
    localparam logic [2:0] LEN_4B = 3'd1;
    localparam logic [2:0] LEN_6B = 3'd2;
    localparam logic [2:0] LEN_8B = 3'd3;

    //=========================================================================
    // DUT Signals
    //=========================================================================
    logic                     clk;
    logic                     rst_n;
    logic                     stall;
    logic                     flush;
    logic [ADDR_WIDTH-1:0]   pc;
    logic [15:0]             mem_rdata;
    logic                     mem_ready;
    logic                     mem_page_fault;
    logic                     branch_taken;
    logic [ADDR_WIDTH-1:0]   branch_target;
    logic [ADDR_WIDTH-1:0]   fetch_addr;
    logic                     fetch_req;
    logic [DATA_WIDTH-1:0]   instr;
    logic                     instr_valid;
    logic [ 2:0]             instr_len;
    logic                     exception;
    logic [ 1:0]             exception_cause;
    logic [ADDR_WIDTH-1:0]   exception_addr;
    logic [ADDR_WIDTH-1:0]   next_pc;

    //=========================================================================
    // Memory Model
    //=========================================================================
    logic [15:0]             mem_data  [0:MEM_DEPTH-1];
    logic                    mem_mapped[0:MEM_DEPTH-1];

    // Word-aligned index into memory (byte address >> 1)
    logic [31:0]             mem_idx;
    assign mem_idx = fetch_addr[31:1];

    // Combinational memory response: responds immediately when fetch_req is
    // asserted.  The IFU samples mem_ready_i on the next posedge.
    always_comb begin
        if (fetch_req && (mem_idx < MEM_DEPTH)) begin
            mem_ready = 1'b1;
            if (mem_mapped[mem_idx]) begin
                mem_page_fault = 1'b0;
                mem_rdata = mem_data[mem_idx];
            end else begin
                mem_page_fault = 1'b1;
                mem_rdata = 16'h0;
            end
        end else begin
            mem_ready  = 1'b0;
            mem_page_fault = 1'b0;
            mem_rdata  = 16'h0;
        end
    end

    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    misc_ifu #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_dut (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .stall_i          (stall),
        .flush_i          (flush),
        .pc_i             (pc),
        .mem_rdata_i      (mem_rdata),
        .mem_ready_i      (mem_ready),
        .mem_page_fault_i (mem_page_fault),
        .branch_taken_i   (branch_taken),
        .branch_target_i  (branch_target),
        .fetch_addr_o     (fetch_addr),
        .fetch_req_o      (fetch_req),
        .instr_o          (instr),
        .instr_valid_o    (instr_valid),
        .instr_len_o      (instr_len),
        .exception_o      (exception),
        .exception_cause_o(exception_cause),
        .exception_addr_o (exception_addr),
        .next_pc_o        (next_pc)
    );

    //=========================================================================
    // Clock generation — 10 ns period, 5 ns high / 5 ns low
    //=========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //=========================================================================
    // Test infrastructure
    //=========================================================================
    integer pass_cnt;
    integer fail_cnt;
    integer test_num;

    //=========================================================================
    // Helper: clear memory model
    //=========================================================================
    task automatic mem_clear();
        for (int i = 0; i < MEM_DEPTH; i++) begin
            mem_data[i]   = 16'h0;
            mem_mapped[i] = 1'b0;
        end
    endtask

    //=========================================================================
    // Helper: write a 16-bit word into the memory model
    //=========================================================================
    task automatic mem_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [15:0]           data,
        input logic                  mapped = 1'b1
    );
        mem_data[addr[31:1]]   = data;
        mem_mapped[addr[31:1]] = mapped;
    endtask

    //=========================================================================
    // Helper: apply reset (active-low, 3 cycles)
    //=========================================================================
    task automatic apply_reset();
        rst_n <= 1'b0;
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    //=========================================================================
    // Helper: initiate fetch with stall=0, then assert stall=1 to hold DONE,
    //         wait the required number of memory-chunk cycles, then sample.
    //
    //   num_chunks = 1 → 2-byte  instruction
    //   num_chunks = 2 → 4-byte  instruction
    //   num_chunks = 3 → 6-byte  instruction
    //   num_chunks = 4 → 8-byte  instruction
    //
    // After returning, the IFU is in DONE with stall=1 asserted and
    // outputs are valid.
    //=========================================================================
    task automatic fetch_and_hold(
        input logic [ADDR_WIDTH-1:0] fetch_pc,
        input int                     num_chunks
    );
        // Deassert stall so IFU can leave IDLE
        stall <= 1'b0;
        // Set PC (blocking so IFU samples it this cycle)
        pc = fetch_pc;
        @(posedge clk);   // IDLE → FETCH_FIRST (fetch issued)

        // Assert stall — when IFU reaches DONE it will be held there
        stall <= 1'b1;

        // Wait for all chunks to be fetched.
        // After the first @(posedge clk) above the IFU is in FETCH_FIRST.
        // It takes (num_chunks) total cycles to reach DONE:
        //   num_chunks=1: FETCH_FIRST (processes data) → DONE  (1 more clk)
        //   num_chunks=2: FETCH_FIRST → FETCH_REMAINING → DONE (2 more clks)
        //   num_chunks=3: FETCH_FIRST → F_R → F_R → DONE     (3 more clks)
        //   num_chunks=4: FETCH_FIRST → F_R → F_R → F_R → DONE (4 more clks)
        repeat (num_chunks) @(posedge clk);

        // Now the IFU is in DONE (held by stall=1).  Outputs are valid.
    endtask

    //=========================================================================
    // Helper: release stall, flush IFU back to IDLE, keep stall=1.
    //          After this the IFU is quiescent in IDLE, ready for the
    //          next test.  fetch_and_hold() will deassert stall when it
    //          is time to issue the next fetch.
    //=========================================================================
    task automatic release_stall();
        // Flush the IFU to force it back to IDLE (flush has priority
        // over stall in the RTL).  Keep stall=1 so the IFU stays in
        // IDLE after the flush.
        flush <= 1'b1;
        @(posedge clk);
        flush <= 1'b0;
        // IFU is now in IDLE with stall=1.
    endtask

    //=========================================================================
    // Helper: wait for exception or timeout
    //=========================================================================
    task automatic wait_exception(
        input int timeout_cycles = 100
    );
        int cyc;
        cyc = 0;
        while (!exception && cyc < timeout_cycles) begin
            @(posedge clk);
            cyc = cyc + 1;
        end
        if (cyc >= timeout_cycles) begin
            $display("[%0d] TIMEOUT: wait_exception exceeded %0d cycles",
                     test_num, timeout_cycles);
            fail_cnt = fail_cnt + 1;
        end
    endtask

    //=========================================================================
    // Helper: wait a specified number of cycles
    //=========================================================================
    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    //=========================================================================
    // Check helpers — various flavours
    //=========================================================================

    task automatic check_bit(
        input string    test_name,
        input logic     actual,
        input logic     expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected %b, got %b", expected, actual);
            fail_cnt = fail_cnt + 1;
        end
        test_num = test_num + 1;
    endtask

    task automatic check64(
        input string            test_name,
        input logic [63:0]     actual,
        input logic [63:0]     expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected 0x%016h, got 0x%016h", expected, actual);
            fail_cnt = fail_cnt + 1;
        end
        test_num = test_num + 1;
    endtask

    task automatic check3(
        input string        test_name,
        input logic [2:0]   actual,
        input logic [2:0]   expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected %0d, got %0d", expected, actual);
            fail_cnt = fail_cnt + 1;
        end
        test_num = test_num + 1;
    endtask

    task automatic check2(
        input string        test_name,
        input logic [1:0]   actual,
        input logic [1:0]   expected
    );
        if (actual === expected) begin
            $display("[%0d] PASS: %s", test_num, test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[%0d] FAIL: %s", test_num, test_name);
            $display("       Expected %0d, got %0d", expected, actual);
            fail_cnt = fail_cnt + 1;
        end
        test_num = test_num + 1;
    endtask

    //=========================================================================
    // MAIN TEST SEQUENCE
    //=========================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        test_num = 1;

        $display("============================================================");
        $display(" MISC-2000 IFU Testbench");
        $display("============================================================");

        // -----------------------------------------------------------------
        // Initialize all inputs.  Start with stall=1 to prevent the IFU
        // from issuing spurious fetches after reset while tests are being
        // set up.  fetch_and_hold() will deassert stall when ready.
        // -----------------------------------------------------------------
        pc            = '0;
        stall         = 1'b1;
        flush         = 1'b0;
        branch_taken  = 1'b0;
        branch_target = '0;

        // Clear memory model
        mem_clear();

        // Apply reset
        $display("\n--- Applying reset ---");
        apply_reset();
        // After reset, IFU is in IDLE with stall=1 — no spurious fetches.

        // =================================================================
        // TEST 1: 2-byte instruction fetch
        // =================================================================
        $display("\n--- Test 1: 2-byte instruction fetch ---");

        mem_clear();
        // Store instruction at 0x1000: bit[7:6]=00 → 2B
        mem_write(64'h1000, 16'h0042);

        // Hold IFU in DONE after fetching
        fetch_and_hold(64'h1000, 1);

        check3("Test 1: instr_len_o = 0 (2B)", instr_len, LEN_2B);
        check64("Test 1: instr_o = 0x0042", instr, 64'h0000000000000042);
        check_bit("Test 1: instr_valid_o = 1", instr_valid, 1'b1);
        check_bit("Test 1: exception_o = 0", exception, 1'b0);
        check64("Test 1: next_pc_o = 0x1002", next_pc, 64'h1002);

        release_stall();

        // =================================================================
        // TEST 2: 4-byte instruction fetch
        // =================================================================
        $display("\n--- Test 2: 4-byte instruction fetch ---");

        mem_clear();
        // First 2 bytes at 0x1000: bit[7:6]=01 → 4B
        mem_write(64'h1000, 16'h0142);
        // Second 2 bytes at 0x1002
        mem_write(64'h1002, 16'hABCD);

        fetch_and_hold(64'h1000, 2);

        check3("Test 2: instr_len_o = 1 (4B)", instr_len, LEN_4B);
        // Little-endian: byte at addr+0 → [7:0], addr+1 → [15:8], ...
        // First read: 0x0142 → buffer[15:0]
        // Second read: 0xABCD → buffer[31:16]
        // instr_o = 0xABCD_0142
        check64("Test 2: instr_o = 0xABCD_0142", instr, 64'h00000000ABCD0142);
        check_bit("Test 2: instr_valid_o = 1", instr_valid, 1'b1);
        check_bit("Test 2: exception_o = 0", exception, 1'b0);
        check64("Test 2: next_pc_o = 0x1004", next_pc, 64'h1004);

        release_stall();

        // =================================================================
        // TEST 3: 6-byte instruction fetch
        // =================================================================
        $display("\n--- Test 3: 6-byte instruction fetch ---");

        mem_clear();
        // First 2 bytes at 0x1000: bit[7:6]=10 → 6B
        mem_write(64'h1000, 16'h8000);
        mem_write(64'h1002, 16'h1111);
        mem_write(64'h1004, 16'h2222);

        fetch_and_hold(64'h1000, 3);

        check3("Test 3: instr_len_o = 2 (6B)", instr_len, LEN_6B);
        // buffer[15:0]  = 0x8000
        // buffer[31:16] = 0x1111
        // buffer[47:32] = 0x2222
        check64("Test 3: instr_o 6 bytes collected", instr,
                64'h0000_2222_1111_8000);
        check_bit("Test 3: instr_valid_o = 1", instr_valid, 1'b1);
        check_bit("Test 3: exception_o = 0", exception, 1'b0);
        check64("Test 3: next_pc_o = 0x1006", next_pc, 64'h1006);

        release_stall();

        // =================================================================
        // TEST 4: 8-byte instruction fetch
        // =================================================================
        $display("\n--- Test 4: 8-byte instruction fetch ---");

        mem_clear();
        // First 2 bytes at 0x1000: bit[7:6]=11 → 8B
        mem_write(64'h1000, 16'hC000);
        mem_write(64'h1002, 16'hAAAA);
        mem_write(64'h1004, 16'hBBBB);
        mem_write(64'h1006, 16'hCCCC);

        fetch_and_hold(64'h1000, 4);

        check3("Test 4: instr_len_o = 3 (8B)", instr_len, LEN_8B);
        // buffer[15:0]  = 0xC000
        // buffer[31:16] = 0xAAAA
        // buffer[47:32] = 0xBBBB
        // buffer[63:48] = 0xCCCC
        check64("Test 4: instr_o 8 bytes collected", instr,
                64'hCCCC_BBBB_AAAA_C000);
        check_bit("Test 4: instr_valid_o = 1", instr_valid, 1'b1);
        check_bit("Test 4: exception_o = 0", exception, 1'b0);
        check64("Test 4: next_pc_o = 0x1008", next_pc, 64'h1008);

        release_stall();

        // =================================================================
        // TEST 5: Cross-page fetch success
        // =================================================================
        $display("\n--- Test 5: Cross-page fetch success ---");

        mem_clear();
        // pc_i = 0x1FFE (4-byte instruction, crosses to 0x2000)
        // Page 0x1000: addresses 0x1000–0x1FFF
        // Page 0x2000: addresses 0x2000–0x2FFF
        // First 2 bytes at 0x1FFE → bit[7:6]=01 → 4B
        mem_write(64'h1FFE, 16'h0142);
        // Second 2 bytes at 0x2000 (next page, mapped)
        mem_write(64'h2000, 16'hBEEF);

        // instr_start_addr = 0x1FFE, instr_start_addr[11:0] = 0xFFE
        // 0xFFE + 4 = 0x1002 > 0x1000 → crosses page, but no atomic
        // → continue fetching

        fetch_and_hold(64'h1FFE, 2);

        check3("Test 5: instr_len_o = 1 (4B)", instr_len, LEN_4B);
        check64("Test 5: instr_o = 0xBEEF_0142", instr, 64'h00000000BEEF0142);
        check_bit("Test 5: instr_valid_o = 1", instr_valid, 1'b1);
        check_bit("Test 5: exception_o = 0", exception, 1'b0);
        // instr_start_addr = 0x1FFE, next_pc = 0x1FFE + 4 = 0x2002
        check64("Test 5: next_pc_o = 0x2002", next_pc, 64'h2002);

        release_stall();

        // =================================================================
        // TEST 6: Cross-page fetch page fault
        // =================================================================
        $display("\n--- Test 6: Cross-page fetch page fault ---");

        mem_clear();
        // pc_i = 0x1FFE (4-byte instruction)
        // First 2 bytes at 0x1FFE — mapped, succeeds
        mem_write(64'h1FFE, 16'h0142);
        // Second page (0x2000) — NOT mapped → page fault

        // For exception tests, we do NOT use stall, so the IFU can
        // progress normally through its states and raise the exception.
        stall <= 1'b0;
        pc = 64'h1FFE;
        @(posedge clk);   // IDLE → FETCH_FIRST (fetch issues)

        // Wait for the exception
        // IFU: FETCH_FIRST (succeeds at 0x1FFE) → FETCH_REMAINING
        //      → page fault at 0x2000 → exception → IDLE
        wait_exception();

        check_bit("Test 6: exception_o = 1", exception, 1'b1);
        // Exception address MUST be the instruction start address (0x1FFE),
        // NOT the intermediate fetch address (0x2000)
        check64("Test 6: exception_addr_o = 0x1FFE", exception_addr, 64'h1FFE);
        check2("Test 6: exception_cause_o = 0 (page_fault)", exception_cause,
               EXC_PAGE_FAULT);
        check_bit("Test 6: instr_valid_o = 0", instr_valid, 1'b0);

        // Let IFU settle back to IDLE
        @(posedge clk);

        // =================================================================
        // TEST 7: Pipeline flush
        // =================================================================
        $display("\n--- Test 7: Pipeline flush ---");

        mem_clear();
        mem_write(64'h1000, 16'h8042);  // bit[7:6]=10 → 6B
        mem_write(64'h1002, 16'hAAAA);
        mem_write(64'h1004, 16'hBBBB);

        stall <= 1'b0;
        pc = 64'h1000;
        @(posedge clk);   // IDLE → FETCH_FIRST

        // Let the IFU process the first chunk (enter FETCH_REMAINING)
        @(posedge clk);   // FETCH_FIRST → FETCH_REMAINING

        // Now assert flush — IFU should return to IDLE and clear outputs
        flush <= 1'b1;
        @(posedge clk);   // flush takes effect
        flush <= 1'b0;

        // Check that IFU is back in IDLE (outputs cleared)
        check_bit("Test 7: fetch_req_o = 0 after flush", fetch_req, 1'b0);
        check_bit("Test 7: instr_valid_o = 0 after flush", instr_valid, 1'b0);
        check_bit("Test 7: exception_o = 0 after flush", exception, 1'b0);

        // =================================================================
        // TEST 8: Pipeline stall
        // =================================================================
        $display("\n--- Test 8: Pipeline stall ---");

        mem_clear();
        mem_write(64'h1000, 16'h0042);  // 2B instruction

        // Assert stall — IFU should not issue a fetch
        stall <= 1'b1;
        pc = 64'h1000;
        @(posedge clk);   // IFU stays in IDLE (stalled)
        check_bit("Test 8: fetch_req_o = 0 during stall", fetch_req, 1'b0);

        // Deassert stall — IFU should resume and issue fetch
        stall <= 1'b0;
        @(posedge clk);   // IDLE → FETCH_FIRST
        // fetch_req_o should be asserted now
        check_bit("Test 8: fetch_req_o = 1 after stall deassert", fetch_req, 1'b1);

        // Now stall again to catch DONE
        stall <= 1'b1;
        @(posedge clk);   // FETCH_FIRST → DONE (2B, held)

        check_bit("Test 8: instr_valid_o = 1 after stall resume", instr_valid, 1'b1);
        check64("Test 8: instr_o = 0x0042", instr, 64'h0000000000000042);

        release_stall();

        // =================================================================
        // TEST 9: Atomic cross-page detection
        // =================================================================
        $display("\n--- Test 9: Atomic cross-page detection ---");

        mem_clear();
        // pc_i = 0x1FFE, opcode in 0x144–0x148 range, bit[7:6]=01 → 4B
        // 0x0144 has bit[7:6]=01
        mem_write(64'h1FFE, 16'h0144);

        // instr_start_addr[11:0] = 0xFFE
        // 0xFFE + 4 = 0x1002 > 0x1000 → atomic crosses page boundary
        // → exception with EXC_ATOMIC_CROSS_PAGE

        stall <= 1'b0;
        pc = 64'h1FFE;
        @(posedge clk);   // IDLE → FETCH_FIRST

        // The atomic cross-page check happens in FETCH_FIRST, so the
        // exception is raised on the next cycle.
        wait_exception();

        check_bit("Test 9: exception_o = 1", exception, 1'b1);
        check2("Test 9: exception_cause_o = 2 (atomic_cross_page)",
               exception_cause, EXC_ATOMIC_CROSS_PAGE);
        check64("Test 9: exception_addr_o = 0x1FFE", exception_addr, 64'h1FFE);
        check_bit("Test 9: instr_valid_o = 0", instr_valid, 1'b0);

        // Let IFU settle back to IDLE
        @(posedge clk);

        // =================================================================
        // TEST 10: Branch flush
        // =================================================================
        $display("\n--- Test 10: Branch flush ---");

        // Note: The current IFU RTL does not implement branch_taken_i /
        // branch_target_i handling (they are declared as inputs but not
        // used in the state machine).  This test documents the expected
        // behaviour — if the RTL is updated to support branches, this
        // test will validate the implementation.

        mem_clear();
        mem_write(64'h1000, 16'h0042);  // 2B

        stall <= 1'b0;
        pc = 64'h1000;
        @(posedge clk);   // IDLE → FETCH_FIRST

        // Assert branch_taken during fetch with target 0x3000
        branch_taken  = 1'b1;
        branch_target = 64'h3000;
        @(posedge clk);
        branch_taken  = 1'b0;
        branch_target = '0;

        // Verify next_pc_o reflects branch target
        check64("Test 10: next_pc_o = 0x3000 (branch)", next_pc, 64'h3000);

        // =================================================================
        // SUMMARY
        // =================================================================
        $display("\n============================================================");
        $display(" IFU TEST SUMMARY");
        $display("============================================================");
        $display("  Total checks: %0d", test_num - 1);
        $display("  Passed:       %0d", pass_cnt);
        $display("  Failed:       %0d", fail_cnt);
        $display("============================================================");

        if (fail_cnt == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  SOME TESTS FAILED!");
            $display("  Failures: %0d", fail_cnt);
        end
        $display("============================================================\n");

        $stop;
    end

endmodule