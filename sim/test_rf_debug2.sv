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
            $display("  [write_reg] enter: time=%0t, clk=%b, addr=%0d", $time, clk, addr);
            rd_addr   <= addr[4:0];
            rd_data   <= data;
            rd_wen    <= 1'b1;
            rd_width  <= width;
            $display("  [write_reg] before @posedge: time=%0t, clk=%b", $time, clk);
            @(posedge clk);
            $display("  [write_reg] after @posedge: time=%0t, clk=%b", $time, clk);
            rd_wen    <= 1'b0;
            rd_addr   <= '0;
            rd_data   <= '0;
            $display("  [write_reg] exit: time=%0t, clk=%b", $time, clk);
        end
    endtask

    task automatic apply_reset();
        begin
            $display("  [apply_reset] enter: time=%0t", $time);
            rst_n <= 1'b0;
            repeat (3) @(posedge clk);
            $display("  [apply_reset] after 3 posedges: time=%0t", $time);
            rst_n <= 1'b1;
            @(posedge clk);
            $display("  [apply_reset] exit: time=%0t", $time);
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

        $display("\n=== Test: write x1 ===");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        $display("Back from write_reg, time=%0t", $time);
        #10;
        rs1_addr <= 5'd1;
        #10;
        $display("Final: rs1_data = 0x%016h", rs1_data);
        
        $finish;
    end
endmodule
