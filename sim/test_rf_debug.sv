`timescale 1ns / 1ps
`include "../rtl/core/regfile.sv"

module tb_regfile;
    localparam DATA_WIDTH = 64;
    localparam ADDR_WIDTH = 5;
    localparam NUM_REGS   = 32;
    
    logic                      clk;
    logic                      rst_n;
    logic [ADDR_WIDTH-1:0]    rs1_addr;
    logic [DATA_WIDTH-1:0]    rs1_data;
    logic [ADDR_WIDTH-1:0]    rs2_addr;
    logic [DATA_WIDTH-1:0]    rs2_data;
    logic [ADDR_WIDTH-1:0]    rd_addr;
    logic [DATA_WIDTH-1:0]    rd_data;
    logic                      rd_wen;
    logic [2:0]                rd_width;
    integer                    pass_cnt = 0;
    integer                    fail_cnt = 0;

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

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic write_reg(
        input int               addr,
        input logic [63:0]      data,
        input logic [2:0]       width = 3'd3
    );
        begin
            rd_addr   <= addr[4:0];
            rd_data   <= data;
            rd_wen    <= 1'b1;
            rd_width  <= width;
            @(posedge clk);
            rd_wen    <= 1'b0;
            rd_addr   <= '0;
            rd_data   <= '0;
        end
    endtask

    task automatic read_port1(
        input int addr
    );
        rs1_addr <= addr[4:0];
    endtask

    task automatic check_equal(
        input string     test_name,
        input logic [63:0] actual,
        input logic [63:0] expected
    );
        begin
            if (actual === expected) begin
                $display("[PASS] %s: got 0x%016h", test_name, actual);
                pass_cnt++;
            end else begin
                $display("[FAIL] %s: expected 0x%016h, got 0x%016h",
                         test_name, expected, actual);
                fail_cnt++;
            end
        end
    endtask

    task automatic apply_reset();
        begin
            rst_n <= 1'b0;
            repeat (3) @(posedge clk);
            rst_n <= 1'b1;
            @(posedge clk);
        end
    endtask

    initial begin
        $display("--- Test 1: x0 reads as zero ---");
        rs1_addr  = '0;
        rs2_addr  = '0;
        rd_addr   = '0;
        rd_data   = '0;
        rd_wen    = 1'b0;
        rd_width  = 3'd3;

        apply_reset();
        $display("After reset, time=%0t", $time);

        read_port1(0);
        #10;
        check_equal("x0 read via rs1", rs1_data, 64'h0);

        $display("\n--- Test 2: x0 writes are ignored ---");
        write_reg(0, 64'hDEAD, 3'd3);
        $display("After write_reg(0), time=%0t", $time);
        #10;
        read_port1(0);
        #10;
        check_equal("x0 after write of 0xDEAD", rs1_data, 64'h0);

        $display("\n--- Test 3: Basic write/read to x1 ---");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        $display("After write_reg(1), time=%0t, rd_wen=%b", $time, rd_wen);
        #10;
        read_port1(1);
        $display("After read_port1(1), time=%0t, rs1_data=0x%016h", $time, rs1_data);
        #10;
        check_equal("x1 read after Q write", rs1_data, 64'h1234567890ABCDEF);

        $display("\nPass: %0d, Fail: %0d", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
