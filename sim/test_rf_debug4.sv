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
    logic [ADDR_WIDTH-1:0]    rd_addr;
    logic [DATA_WIDTH-1:0]    rd_data;
    logic                      rd_wen;
    logic [2:0]                rd_width;

    misc_regfile #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .NUM_REGS   (NUM_REGS)
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

    task automatic write_reg(
        input int               addr,
        input logic [63:0]      data,
        input logic [2:0]       width = 3'd3
    );
        begin
            $display("  [write_reg] enter: time=%0t, clk=%b, rd_wen=%b", $time, clk, rd_wen);
            rd_addr   <= addr[4:0];
            rd_data   <= data;
            rd_wen    <= 1'b1;
            rd_width  <= width;
            $display("  [write_reg] before @posedge: time=%0t, clk=%b, rd_wen=%b (NBA pending)", $time, clk, rd_wen);
            @(posedge clk);
            $display("  [write_reg] after @posedge: time=%0t, clk=%b, rd_wen=%b", $time, clk, rd_wen);
            rd_wen    <= 1'b0;
            rd_addr   <= '0;
            rd_data   <= '0;
            $display("  [write_reg] exit: time=%0t, clk=%b, rd_wen=%b (NBA pending=0)", $time, clk, rd_wen);
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
        $monitor("MON: time=%0t clk=%b rd_wen=%b rd_addr=%0d rs1_data=0x%016h",
                 $time, clk, rd_wen, rd_addr, rs1_data);
        
        rs1_addr  = 5'd1;
        rd_addr   = '0;
        rd_data   = '0;
        rd_wen    = 1'b0;
        rd_width  = 3'd3;

        apply_reset();
        $display("After reset, time=%0t", $time);

        $display("\n=== First write: x0 ===");
        write_reg(0, 64'hDEAD, 3'd3);
        $display("Back from write_reg(0), time=%0t", $time);
        #10;
        $display("After #10 (55ns?), time=%0t", $time);
        #10;
        $display("After another #10 (65ns?), time=%0t", $time);

        $display("\n=== Second write: x1 ===");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        $display("Back from write_reg(1), time=%0t", $time);
        
        #20;
        $display("Final x1 = 0x%016h", rs1_data);
        $finish;
    end
endmodule
