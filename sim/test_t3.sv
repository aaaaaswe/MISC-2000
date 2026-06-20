`include "../rtl/core/alu.sv"

module tb_test3;
    logic [63:0] op_a, op_b, result;
    logic [5:0] alu_op;
    logic [2:0] data_width;
    logic zero, negative, overflow, carry;

    misc_alu u_dut (
        .op_a_i(op_a), .op_b_i(op_b), .alu_op_i(alu_op),
        .data_width_i(data_width), .result_o(result),
        .zero_o(zero), .negative_o(negative),
        .overflow_o(overflow), .carry_o(carry)
    );

    initial begin
        op_a = 64'h8000000000000000; op_b = 64'd4; alu_op = 6'h0B; data_width = 3'd3;
        #1 $display("SAR Q: %h (expected f800000000000000)", result);
        op_a = 64'h1; op_b = 64'd16; alu_op = 6'h09; data_width = 3'd0;
        #1 $display("SHL B: %h (expected 0)", result);
        $finish;
    end
endmodule
