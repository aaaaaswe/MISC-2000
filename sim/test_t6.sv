`include "../rtl/core/alu.sv"

module tb_test6;
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
        // [5] ADD 0xFFFFFFFF+0x1 carry (D)
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd2;
        #1 $display("[5] ADD c(D): r=%h z=%b n=%b o=%b c=%b (expect r=0 z=1 n=0 o=1 c=1)",
                    result, zero, negative, overflow, carry);
        // [6] ADD 0xFFFFFFFF+0x1 (Q)
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd3;
        #1 $display("[6] ADD c(Q): r=%h z=%b n=%b o=%b c=%b (expect r=0x100000000 z=0 n=0 o=0 c=1)",
                    result, zero, negative, overflow, carry);
        // [7] ADD -5 + 3 (D)
        op_a = 64'hFFFFFFFB; op_b = 64'h3; alu_op = 6'h00; data_width = 3'd2;
        #1 $display("[7] ADD D(-5+3): r=%h z=%b n=%b o=%b c=%b (expect r=0xFFFFFFFE z=0 n=1 o=0 c=1)",
                    result, zero, negative, overflow, carry);
        // [18] MUL overflow (Q)
        op_a = 64'h100000000; op_b = 64'h100000000; alu_op = 6'h02; data_width = 3'd3;
        #1 $display("[18] MUL overflow: r=%h z=%b n=%b o=%b c=%b (expect r=0 z=1 n=0 o=1 c=0)",
                    result, zero, negative, overflow, carry);
        // [50] SHL 0x1 << 16 (B)
        op_a = 64'h1; op_b = 64'd16; alu_op = 6'h09; data_width = 3'd0;
        #1 $display("[50] SHL B 1<<16: r=%h (expect 0)", result);
        // [67] INC 0xFFFFFFFF (D)
        op_a = 64'hFFFFFFFF; op_b = 64'h0; alu_op = 6'h0E; data_width = 3'd2;
        #1 $display("[67] INC D: r=%h c=%b (expect r=0 c=1)", result, carry);
        // [68] INC 0xFF (B)
        op_a = 64'hFF; op_b = 64'h0; alu_op = 6'h0E; data_width = 3'd0;
        #1 $display("[68] INC B: r=%h c=%b (expect r=0 c=1)", result, carry);
        // [83] CMP 0x43 > 0x42 Q
        op_a = 64'h43; op_b = 64'h42; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[83] CMP Q: r=%h z=%b n=%b o=%b c=%b (expect r=0 z=0 n=0 o=0 c=1)",
                    result, zero, negative, overflow, carry);
        // [84] CMP 0x41 < 0x42 Q
        op_a = 64'h41; op_b = 64'h42; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[84] CMP Q: r=%h z=%b n=%b o=%b c=%b (expect r=0 z=0 n=1 o=0 c=0)",
                    result, zero, negative, overflow, carry);
        // [87] CMP 127 > -128 B
        op_a = 64'h7F; op_b = 64'h80; alu_op = 6'h12; data_width = 3'd0;
        #1 $display("[87] CMP B(127>-128): r=%h z=%b n=%b o=%b c=%b (expect r=0 z=0 n=0 o=1 c=1)",
                    result, zero, negative, overflow, carry);
        // [90] TEST 0xAA & 0xA0 (Q)
        op_a = 64'hAA; op_b = 64'hA0; alu_op = 6'h13; data_width = 3'd3;
        #1 $display("[90] TEST Q AA&A0: r=%h n=%b (expect r=0xA0 n=0)", result, negative);
        // [95] MIN -5,5 (Q)
        op_a = 64'hFFFFFFFFFFFFFFFB; op_b = 64'd5; alu_op = 6'h14; data_width = 3'd3;
        #1 $display("[95] MIN: r=%h (expect 0xFFFFFFFFFFFFFFFB)", result);
        // [100] MAX -5,5 (Q)
        op_a = 64'hFFFFFFFFFFFFFFFB; op_b = 64'd5; alu_op = 6'h15; data_width = 3'd3;
        #1 $display("[100] MAX: r=%h (expect 0x5)", result);
        $finish;
    end
endmodule
