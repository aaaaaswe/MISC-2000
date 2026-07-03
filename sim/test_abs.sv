`include "../rtl/core/defines.sv"
`include "../rtl/core/alu.sv"

module test_abs;
    logic [63:0] op_a_i;
    logic [63:0] op_b_i;
    logic [ 5:0] alu_op_i;
    logic [ 2:0] data_width_i;
    logic [63:0] result_o;
    logic        zero_o;
    logic        neg_o;
    logic        overflow_o;
    logic        carry_o;

    alu dut (
        .op_a_i(op_a_i),
        .op_b_i(op_b_i),
        .alu_op_i(alu_op_i),
        .data_width_i(data_width_i),
        .result_o(result_o),
        .zero_o(zero_o),
        .neg_o(neg_o),
        .overflow_o(overflow_o),
        .carry_o(carry_o)
    );

    initial begin
        // ABS 0x80 (8-bit)
        op_a_i = 64'h80;
        alu_op_i = `OP_ABS;
        data_width_i = 3'd0;  // B
        #10;
        $display("ABS 0x80 (B):");
        $display("  result=0x%016h", result_o);
        $display("  zero=%b neg=%b ovf=%b carry=%b", zero_o, neg_o, overflow_o, carry_o);
    end
endmodule
