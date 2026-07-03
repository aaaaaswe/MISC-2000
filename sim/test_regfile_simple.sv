`include "../rtl/core/regfile.sv"

module tb;
    logic clk;
    logic rst_n;
    logic [4:0] rs1_addr;
    logic [63:0] rs1_data;
    logic [4:0] rd_addr;
    logic [63:0] rd_data;
    logic rd_wen;
    logic [2:0] rd_width;

    misc_regfile dut (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .rs1_addr_i(rs1_addr),
        .rs1_data_o(rs1_data),
        .rs2_addr_i(5'd0),
        .rs2_data_o(),
        .rd_addr_i(rd_addr),
        .rd_data_i(rd_data),
        .rd_wen_i(rd_wen),
        .rd_width_i(rd_width)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        rs1_addr = 0;
        rd_addr = 0;
        rd_data = 0;
        rd_wen = 0;
        rd_width = 3'd3;
        
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Write 0x1234 to x1
        $display("Writing 0x1234 to x1");
        rd_addr <= 5'd1;
        rd_data <= 64'h1234;
        rd_wen <= 1'b1;
        @(posedge clk);
        rd_wen <= 1'b0;
        rd_addr <= 0;
        rd_data <= 0;
        
        // Read x1
        @(posedge clk);
        rs1_addr = 5'd1;
        #1;
        $display("x1 = 0x%016h", rs1_data);
        
        // Write and read same cycle (forwarding)
        @(posedge clk);
        rd_addr <= 5'd2;
        rd_data <= 64'hDEAD;
        rd_wen <= 1'b1;
        rs1_addr = 5'd2;
        #1;
        $display("x2 (forwarded) = 0x%016h", rs1_data);
        
        @(posedge clk);
        rd_wen <= 1'b0;
        #1;
        $display("x2 (after write) = 0x%016h", rs1_data);
        
        $finish;
    end
endmodule
