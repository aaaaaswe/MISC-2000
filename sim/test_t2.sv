`include "../rtl/core/alu.sv"

module tb_test;
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
        // ADD: 0xFFFFFFFF + 0x1 at DW_D
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd2;
        #1 $display("ADD D: %h o=%b c=%b", result, overflow, carry);
        // ADD: 0xFFFFFFFF + 0x1 at DW_Q
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd3;
        #1 $display("ADD Q: %h o=%b c=%b", result, overflow, carry);
        // ADD: 0x80 + 0x80 at DW_B
        op_a = 64'h80; op_b = 64'h80; alu_op = 6'h00; data_width = 3'd0;
        #1 $display("ADD B: %h o=%b c=%b", result, overflow, carry);
        $finish;
    end
endmodule
