`include "../rtl/core/alu.sv"

module tb_simple;
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
        op_a = 64'h42; op_b = 64'h13; alu_op = 6'h00; data_width = 3'd3;
        #1;
        $display("ADD: 0x%h + 0x%h = 0x%h", op_a, op_b, result);
        op_a = 64'h6; op_b = 64'h7; alu_op = 6'h02;
        #1;
        $display("MUL: 0x%h * 0x%h = 0x%h", op_a, op_b, result);
        op_a = 64'h1; op_b = 64'h4; alu_op = 6'h09; data_width = 3'd3;
        #1;
        $display("SHL: 0x%h << 0x%h = 0x%h", op_a, op_b, result);
        $finish;
    end
endmodule
