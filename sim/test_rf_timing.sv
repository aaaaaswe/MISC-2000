`timescale 1ns / 1ps
`include "../rtl/core/regfile.sv"

module tb;
    logic clk;
    logic rst_n;
    logic [4:0]  rs1_addr;
    logic [63:0] rs1_data;
    logic [4:0]  rd_addr;
    logic [63:0] rd_data;
    logic rd_wen;
    logic [2:0] rd_width;

    misc_regfile #(
        .DATA_WIDTH(64),
        .ADDR_WIDTH(5),
        .NUM_REGS(32)
    ) u_dut (
        .clk_i      (clk),
        .rst_n_i    (rst_n),
        .rs1_addr_i (rs1_addr),
        .rs2_addr_i (5'b0),
        .rd_addr_i  (rd_addr),
        .rd_data_i  (rd_data),
        .rd_wen_i   (rd_wen),
        .rd_width_i (rd_width),
        .rs1_data_o (rs1_data),
        .rs2_data_o ()
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $monitor("time=%0t clk=%b rst_n=%b rd_addr=%0d rd_wen=%b rd_data=0x%016h rs1_addr=%0d rs1_data=0x%016h",
                 $time, clk, rst_n, rd_addr, rd_wen, rd_data, rs1_addr, rs1_data);
        
        rst_n = 1'b0;
        rs1_addr = 5'd1;
        rd_addr = 5'd0;
        rd_data = 64'h0;
        rd_wen = 1'b0;
        rd_width = 3'd3;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        
        $display("--- Before write, time=%0t ---", $time);
        rd_addr <= 5'd1;
        rd_data <= 64'hDEADBEEF;
        rd_wen <= 1'b1;
        rd_width <= 3'd3;
        $display("After non-blocking assigns (before posedge)");
        
        @(posedge clk);
        $display("At posedge clk (time=%0t), rd_wen=%b", $time, rd_wen);
        
        rd_wen <= 1'b0;
        $display("After rd_wen<=0 (time=%0t), rd_wen is still %b (NBA pending)", $time, rd_wen);
        
        #1 $display("After #1 (time=%0t), rd_wen=%b", $time, rd_wen);
        
        #9; // total #10
        $display("After #10 (time=%0t)", $time);
        rs1_addr <= 5'd1;
        #10;
        $display("Final rs1_data = 0x%016h", rs1_data);
        
        $finish;
    end
endmodule
