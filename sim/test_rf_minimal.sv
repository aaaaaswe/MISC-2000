`timescale 1ns / 1ps
`include "../rtl/core/regfile.sv"

module tb;
    localparam DATA_WIDTH = 64;
    localparam ADDR_WIDTH = 5;
    localparam NUM_REGS   = 32;
    
    logic clk;
    logic rst_n;
    logic [4:0]  rs1_addr;
    logic [63:0] rs1_data;
    logic [4:0]  rs2_addr;
    logic [63:0] rs2_data;
    logic [4:0]  rd_addr;
    logic [63:0] rd_data;
    logic rd_wen;
    logic [2:0] rd_width;
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    misc_regfile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS(NUM_REGS)
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
        input int addr,
        input logic [63:0] data,
        input logic [2:0] width = 3'd3
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

    task automatic apply_reset();
        begin
            rst_n <= 1'b0;
            repeat (3) @(posedge clk);
            rst_n <= 1'b1;
            @(posedge clk);
        end
    endtask

    initial begin
        rs1_addr  = '0;
        rs2_addr  = '0;
        rd_addr   = '0;
        rd_data   = '0;
        rd_wen    = 1'b0;
        rd_width  = 3'd3;
        
        apply_reset();
        
        $display("Test: write x1 with task");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        #10;
        rs1_addr <= 5'd1;
        #10;
        
        if (rs1_data === 64'h1234567890ABCDEF) begin
            $display("PASS: rs1_data = 0x%016h", rs1_data);
            pass_cnt++;
        end else begin
            $display("FAIL: expected 0x1234567890abcdef, got 0x%016h", rs1_data);
            fail_cnt++;
        end
        
        // Direct write test
        $display("Test: direct write to x2");
        rd_addr <= 5'd2;
        rd_data <= 64'hDEADBEEF;
        rd_wen <= 1'b1;
        rd_width <= 3'd3;
        @(posedge clk);
        rd_wen <= 1'b0;
        #10;
        rs1_addr <= 5'd2;
        #10;
        
        if (rs1_data === 64'hDEADBEEF) begin
            $display("PASS: direct write rs1_data = 0x%016h", rs1_data);
            pass_cnt++;
        end else begin
            $display("FAIL: direct write expected 0xdeadbeef, got 0x%016h", rs1_data);
            fail_cnt++;
        end
        
        $display("\nPass: %0d, Fail: %0d", pass_cnt, fail_cnt);
        $finish;
    end
endmodule
