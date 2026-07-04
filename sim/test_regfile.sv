// Copyright 2026 The MISC-2000 Authors.
// SPDX-License-Identifier: Apache-2.0

// Testbench for the MISC-2000 Register File (misc_regfile).
// Tests: x0 hardwired-zero, write/read, sub-word writes,
// forwarding, reset, and full 32-register sweep.


`timescale 1ns / 1ps

module tb_regfile;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam DATA_WIDTH = 64;
    localparam ADDR_WIDTH = 5;
    localparam NUM_REGS   = 32;

    // -----------------------------------------------------------------------
    // DUT Signals
    // -----------------------------------------------------------------------
    logic                       clk;
    logic                       rst_n;
    logic [ADDR_WIDTH-1:0]      rs1_addr;
    logic [ADDR_WIDTH-1:0]      rs2_addr;
    logic [ADDR_WIDTH-1:0]      rd_addr;
    logic [DATA_WIDTH-1:0]      rd_data;
    logic                       rd_wen;
    logic [2:0]                 rd_width;
    logic [DATA_WIDTH-1:0]      rs1_data;
    logic [DATA_WIDTH-1:0]      rs2_data;

    // -----------------------------------------------------------------------
    // DUT Instantiation
    // -----------------------------------------------------------------------
    misc_regfile #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_dut (
        .clk_i      (clk),
        .rst_n_i    (rst_n),
        .rs1_addr_i (rs1_addr),
        .rs2_addr_i (rs2_addr),
        .rd_addr_i  (rd_addr),
        .rd_data_i  (rd_data),
        .rd_wen_i   (rd_wen),
        .rd_width_i (rd_width),
        .rs1_data_o (rs1_data),
        .rs2_data_o (rs2_data)
    );

    // -----------------------------------------------------------------------
    // Clock generation — 10 ns period, 5 ns high / 5 ns low
    // -----------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Test control
    // -----------------------------------------------------------------------
    // Global pass/fail tracking
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // -----------------------------------------------------------------------
    // Helper tasks
    // -----------------------------------------------------------------------
    task automatic write_reg(
        input int               addr,
        input logic [63:0]      data,
        input logic [2:0]       width = 3'd3
    );
        rd_addr   <= addr[4:0];
        rd_data   <= data;
        rd_wen    <= 1'b1;
        rd_width  <= width;
        @(posedge clk);
        rd_wen    <= 1'b0;
        rd_addr   <= '0;
        rd_data   <= '0;
    endtask

    task automatic read_port1(
        input int addr
    );
        rs1_addr <= addr[4:0];
    endtask

    task automatic read_port2(
        input int addr
    );
        rs2_addr <= addr[4:0];
    endtask

    task automatic read_both(
        input int addr1,
        input int addr2
    );
        rs1_addr <= addr1[4:0];
        rs2_addr <= addr2[4:0];
    endtask

    task automatic check_equal(
        input string     test_name,
        input logic [63:0] actual,
        input logic [63:0] expected
    );
        if (actual === expected) begin
            $display("[PASS] %s: got 0x%016h", test_name, actual);
            pass_cnt++;
        end else begin
            $display("[FAIL] %s: expected 0x%016h, got 0x%016h",
                     test_name, expected, actual);
            fail_cnt++;
        end
    endtask

    task automatic apply_reset();
        rst_n <= 1'b0;
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin
        // Initialize all inputs
        rs1_addr  = '0;
        rs2_addr  = '0;
        rd_addr   = '0;
        rd_data   = '0;
        rd_wen    = 1'b0;
        rd_width  = 3'd3;

        $display("==============================================");
        $display(" MISC-2000 Register File Testbench");
        $display("==============================================");
        $display("");

        // ---------------------------------------------------------------
        // Apply reset
        // ---------------------------------------------------------------
        $display("--- Applying reset ---");
        apply_reset();

        // ---------------------------------------------------------------
        // Test 1: x0 reads as zero always
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 1: x0 reads as zero ---");
        read_port1(0);
        #10;
        check_equal("x0 read via rs1", rs1_data, 64'h0);
        read_port2(0);
        #10;
        check_equal("x0 read via rs2", rs2_data, 64'h0);

        // ---------------------------------------------------------------
        // Test 2: x0 writes are ignored
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 2: x0 writes are ignored ---");
        write_reg(0, 64'hDEAD, 3'd3);
        #10;
        read_port1(0);
        #10;
        check_equal("x0 after write of 0xDEAD", rs1_data, 64'h0);

        // ---------------------------------------------------------------
        // Test 3: Basic write/read to x1
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 3: Basic write/read to x1 ---");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        #10;
        read_port1(1);
        #10;
        check_equal("x1 read after Q write", rs1_data, 64'h1234567890ABCDEF);

        // ---------------------------------------------------------------
        // Test 4: Dual read — write different values to x1 and x2
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 4: Dual read (x1 and x2) ---");
        // x1 already has 0x1234567890ABCDEF, write new value to x2
        write_reg(2, 64'hAABBCCDDEEFF0011, 3'd3);
        #10;
        read_both(1, 2);
        #10;
        check_equal("x1 dual read", rs1_data, 64'h1234567890ABCDEF);
        check_equal("x2 dual read", rs2_data, 64'hAABBCCDDEEFF0011);

        // ---------------------------------------------------------------
        // Test 5: Sub-word write B (8-bit) to x3
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 5: Sub-word write B to x3 ---");
        // First write full value, then sub-word write
        write_reg(3, 64'hFFFFFFFFFFFFFFFF, 3'd3);
        #10;
        write_reg(3, 64'hAB, 3'd0);  // B write
        #10;
        read_port1(3);
        #10;
        check_equal("x3 after B write of 0xAB", rs1_data,
                    64'hFFFFFFFFFFFFFFAB);

        // ---------------------------------------------------------------
        // Test 6: Sub-word write W (16-bit) to x4
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 6: Sub-word write W to x4 ---");
        write_reg(4, 64'h7777777777777777, 3'd3);
        #10;
        write_reg(4, 64'hCDEF, 3'd1);  // W write
        #10;
        read_port1(4);
        #10;
        check_equal("x4 after W write of 0xCDEF", rs1_data,
                    64'h777777777777CDEF);

        // ---------------------------------------------------------------
        // Test 7: Sub-word write D (32-bit) to x5
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 7: Sub-word write D to x5 ---");
        write_reg(5, 64'hCCCCCCCCCCCCCCCC, 3'd3);
        #10;
        write_reg(5, 64'h12345678, 3'd2);  // D write
        #10;
        read_port1(5);
        #10;
        check_equal("x5 after D write of 0x12345678", rs1_data,
                    64'hCCCCCCCC12345678);

        // ---------------------------------------------------------------
        // Test 8: Sub-word write Q (64-bit) to x6
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 8: Sub-word write Q to x6 ---");
        write_reg(6, 64'hFEDCBA9876543210, 3'd3);
        #10;
        read_port1(6);
        #10;
        check_equal("x6 after Q write of 0xFEDCBA9876543210", rs1_data,
                    64'hFEDCBA9876543210);

        // ---------------------------------------------------------------
        // Test 9: Forwarding — write to x7, read in same cycle
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 9: Forwarding (write and read x7 same cycle) ---");
        // Pre-load x7 with a known value
        write_reg(7, 64'h1111111111111111, 3'd3);
        #10;
        // Now issue write and read simultaneously
        @(posedge clk);
        rd_addr   <= 5'd7;
        rd_data   <= 64'hDEADBEEFCAFEFACE;
        rd_wen    <= 1'b1;
        rd_width  <= 3'd3;
        rs1_addr  <= 5'd7;
        @(posedge clk);  // Wait one cycle — forwarding should give new value
        check_equal("x7 forwarded Q write (same cycle)", rs1_data,
                    64'hDEADBEEFCAFEFACE);
        // Deassert write
        rd_wen    <= 1'b0;
        rd_addr   <= '0;
        rd_data   <= '0;
        rs1_addr  <= '0;
        @(posedge clk);
        // Verify it was actually committed
        #10;
        read_port1(7);
        #10;
        check_equal("x7 committed after forward", rs1_data,
                    64'hDEADBEEFCAFEFACE);

        // ---------------------------------------------------------------
        // Test 10: Forwarding with sub-word write
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 10: Forwarding with sub-word write to x8 ---");
        // Pre-load x8
        write_reg(8, 64'h8888888888888888, 3'd3);
        #10;
        // Issue B write and read simultaneously
        @(posedge clk);
        rd_addr   <= 5'd8;
        rd_data   <= 64'h5A;
        rd_wen    <= 1'b1;
        rd_width  <= 3'd0;  // B write
        rs1_addr  <= 5'd8;
        @(posedge clk);  // Forwarding should give merged value
        check_equal("x8 forwarded B write (same cycle)", rs1_data,
                    64'h888888888888885A);
        rd_wen    <= 1'b0;
        rd_addr   <= '0;
        rd_data   <= '0;
        rs1_addr  <= '0;
        @(posedge clk);

        // Also test W forwarding
        @(posedge clk);
        rd_addr   <= 5'd8;
        rd_data   <= 64'hBEEF;
        rd_wen    <= 1'b1;
        rd_width  <= 3'd1;  // W write
        rs1_addr  <= 5'd8;
        @(posedge clk);
        check_equal("x8 forwarded W write (same cycle)", rs1_data,
                    64'h888888888888BEEF);
        rd_wen    <= 1'b0;
        rd_addr   <= '0;
        rd_data   <= '0;
        rs1_addr  <= '0;
        @(posedge clk);

        // Also test D forwarding
        @(posedge clk);
        rd_addr   <= 5'd8;
        rd_data   <= 64'hCAFEFACE;
        rd_wen    <= 1'b1;
        rd_width  <= 3'd2;  // D write
        rs1_addr  <= 5'd8;
        @(posedge clk);
        check_equal("x8 forwarded D write (same cycle)", rs1_data,
                    64'h88888888CAFEFACE);
        rd_wen    <= 1'b0;
        rd_addr   <= '0;
        rd_data   <= '0;
        rs1_addr  <= '0;
        @(posedge clk);

        // ---------------------------------------------------------------
        // Test 11: Reset — assert reset, verify all registers cleared
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 11: Reset clears all registers ---");
        apply_reset();
        // Now check several registers are zero
        read_port1(1);
        #10;
        check_equal("x1 after reset", rs1_data, 64'h0);
        read_port1(7);
        #10;
        check_equal("x7 after reset", rs1_data, 64'h0);
        read_port1(8);
        #10;
        check_equal("x8 after reset", rs1_data, 64'h0);
        read_port1(0);
        #10;
        check_equal("x0 after reset", rs1_data, 64'h0);

        // ---------------------------------------------------------------
        // Test 12: All 32 registers — write unique values and read back
        // ---------------------------------------------------------------
        $display("");
        $display("--- Test 12: All 32 registers write/read ---");

        // Write unique values to x0–x31 (x0 writes should be ignored)
        for (int i = 0; i < 32; i++) begin
            logic [63:0] val;
            val = 64'hDEAD000000000000 | (i[4:0] << 8) | (i[4:0]);
            write_reg(i, val, 3'd3);
            #10;
        end

        // Read back all 32 registers and verify
        for (int i = 0; i < 32; i++) begin
            string name;
            logic [63:0] expected;
            read_port1(i);
            #10;
            if (i == 0) begin
                expected = 64'h0;  // x0 always zero
            end else begin
                expected = 64'hDEAD000000000000 | (i[4:0] << 8) | (i[4:0]);
            end
            $sformat(name, "x%0d 64-bit write/read", i);
            check_equal(name, rs1_data, expected);
        end

        // ---------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------
        $display("");
        $display("==============================================");
        $display(" Test Summary");
        $display("==============================================");
        $display("  Passed: %0d", pass_cnt);
        $display("  Failed: %0d", fail_cnt);
        $display("==============================================");

        if (fail_cnt == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("SOME TESTS FAILED");
        end

        $stop;
    end

endmodule