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
        $display("Start");
        op_a = 64'h42; op_b = 64'h13; alu_op = 6'h00; data_width = 3'd3;
        #1 $display("ADD: %h z=%b n=%b o=%b c=%b", result, zero, negative, overflow, carry);
        op_a = 64'h55; op_b = 64'h13; alu_op = 6'h01; data_width = 3'd3;
        #1 $display("SUB: %h", result);
        op_a = 64'h6; op_b = 64'h7; alu_op = 6'h02; data_width = 3'd3;
        #1 $display("MUL: %h", result);
        op_a = 64'h64; op_b = 64'hA; alu_op = 6'h03; data_width = 3'd3;
        #1 $display("DIV: %h", result);
        op_a = 64'h64; op_b = 64'h7; alu_op = 6'h04; data_width = 3'd3;
        #1 $display("MOD: %h", result);
        op_a = 64'hFF; op_b = 64'h0F; alu_op = 6'h05; data_width = 3'd3;
        #1 $display("AND: %h", result);
        op_a = 64'hF0; op_b = 64'h0F; alu_op = 6'h06; data_width = 3'd3;
        #1 $display("OR: %h", result);
        op_a = 64'hAA; op_b = 64'h55; alu_op = 6'h07; data_width = 3'd3;
        #1 $display("XOR: %h", result);
        op_a = 64'hFFFFFFFF; op_b = 64'h0; alu_op = 6'h08; data_width = 3'd3;
        #1 $display("NOT: %h", result);
        op_a = 64'h1; op_b = 64'd4; alu_op = 6'h09; data_width = 3'd3;
        #1 $display("SHL: %h", result);
        op_a = 64'h80; op_b = 64'd4; alu_op = 6'h0A; data_width = 3'd3;
        #1 $display("SHR: %h", result);
        op_a = 64'h80000000; op_b = 64'd4; alu_op = 6'h0B; data_width = 3'd3;
        #1 $display("SAR: %h", result);
        op_a = 64'h80; op_b = 64'd1; alu_op = 6'h0C; data_width = 3'd0;
        #1 $display("ROL(B=8): %h", result);
        op_a = 64'h1; op_b = 64'd1; alu_op = 6'h0D; data_width = 3'd0;
        #1 $display("ROR(B=8): %h", result);
        op_a = 64'h1; op_b = 64'd1; alu_op = 6'h0E; data_width = 3'd3;
        #1 $display("INC: %h", result);
        op_a = 64'h2; op_b = 64'd1; alu_op = 6'h0F; data_width = 3'd3;
        #1 $display("DEC: %h", result);
        op_a = 64'hFFFFFFFFFFFFFFF6; op_b = 64'd0; alu_op = 6'h10; data_width = 3'd3;
        #1 $display("NEG: %h", result);
        op_a = 64'hFFFFFFFFFFFFFFF6; op_b = 64'd0; alu_op = 6'h11; data_width = 3'd3;
        #1 $display("ABS: %h", result);
        op_a = 64'h55; op_b = 64'h42; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("CMP: %h n=%b", result, negative);
        op_a = 64'h1; op_b = 64'hFF; alu_op = 6'h14; data_width = 3'd3;
        #1 $display("MIN: %h", result);
        op_a = 64'h1; op_b = 64'hFF; alu_op = 6'h15; data_width = 3'd3;
        #1 $display("MAX: %h", result);
        op_a = 64'h00FF; op_b = 64'd0; alu_op = 6'h18; data_width = 3'd1;
        #1 $display("CLZ(16bit): %h", result);
        op_a = 64'h100; op_b = 64'd0; alu_op = 6'h19; data_width = 3'd3;
        #1 $display("CTZ: %h", result);
        op_a = 64'hAA; op_b = 64'd0; alu_op = 6'h1A; data_width = 3'd0;
        #1 $display("POPCNT: %h", result);
        op_a = 64'h0102030405060708; op_b = 64'd0; alu_op = 6'h1B; data_width = 3'd3;
        #1 $display("BSWAP: %h", result);
        op_a = 64'h1; op_b = 64'd0; alu_op = 6'h1C; data_width = 3'd3;
        #1 $display("BITREV: %h", result);
        $finish;
    end
endmodule
