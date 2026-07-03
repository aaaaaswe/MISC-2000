`include "../rtl/core/regfile.sv"

module tb;
    localparam DATA_WIDTH = 64;
    localparam ADDR_WIDTH = 5;
    localparam NUM_REGS   = 32;
    
    logic clk;
    logic rst_n;
    logic [ADDR_WIDTH-1:0] rs1_addr;
    logic [DATA_WIDTH-1:0] rs1_data;
    logic [ADDR_WIDTH-1:0] rs2_addr;
    logic [DATA_WIDTH-1:0] rs2_data;
    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_wen;
    logic [2:0] rd_width;

    misc_regfile #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS(NUM_REGS)
    ) u_dut (
        .clk_i(clk),
        .rst_n_i(rst_n),
        .rs1_addr_i(rs1_addr),
        .rs2_addr_i(rs2_addr),
        .rd_addr_i(rd_addr),
        .rd_data_i(rd_data),
        .rd_wen_i(rd_wen),
        .rd_width_i(rd_width),
        .rs1_data_o(rs1_data),
        .rs2_data_o(rs2_data)
    );

    initial clk = 0;
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
    
    task automatic read_port1(input int addr);
        rs1_addr <= addr[4:0];
    endtask

    initial begin
        rst_n = 0;
        rs1_addr = 0;
        rs2_addr = 0;
        rd_addr = 0;
        rd_data = 0;
        rd_wen = 0;
        rd_width = 3'd3;
        
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("Test 3 style:");
        write_reg(1, 64'h1234567890ABCDEF, 3'd3);
        $display("After write_reg, time=%0t", $time);
        #10;
        $display("After #10, time=%0t", $time);
        read_port1(1);
        $display("After read_port1, rs1_data=0x%016h", rs1_data);
        #10;
        $display("After #10 more, time=%0t, rs1_data=0x%016h", $time, rs1_data);
        
        $finish;
    end
endmodule
