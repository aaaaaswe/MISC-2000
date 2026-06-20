`include "../rtl/core/alu.sv"

module tb_test4;
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
        // Test [5]: ADD 0xFFFFFFFF + 0x1 (D), carry
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd2;
        #1 $display("[5] D: res=%h z=%b n=%b o=%b c=%b (expect c=1)",
                    result, zero, negative, overflow, carry);
        // Test [6]: ADD 0xFFFFFFFF + 0x1 (Q)
        op_a = 64'hFFFFFFFF; op_b = 64'h1; alu_op = 6'h00; data_width = 3'd3;
        #1 $display("[6] Q: res=%h z=%b n=%b o=%b c=%b (expect c=1)",
                    result, zero, negative, overflow, carry);
        // Test [7]: ADD -5 + 3 (D)
        op_a = 64'hFFFFFFFFFFFFFFFB; op_b = 64'h3; alu_op = 6'h00; data_width = 3'd2;
        #1 $display("[7] D-5+3: res=%h z=%b n=%b o=%b c=%b (expect c=1,n=1,z=0)",
                    result, zero, negative, overflow, carry);
        // Test [18]: MUL 0x100000000 * 0x100000000
        op_a = 64'h100000000; op_b = 64'h100000000; alu_op = 6'h02; data_width = 3'd3;
        #1 $display("[18] MUL: res=%h z=%b o=%b", result, zero, overflow);
        // Test [50]: SHL 0x1 << 16 (B)
        op_a = 64'h1; op_b = 64'd16; alu_op = 6'h09; data_width = 3'd0;
        #1 $display("[50] SHL B: res=%h", result);
        // Test [67]: INC 0xFFFFFFFF (D)
        op_a = 64'hFFFFFFFF; op_b = 64'h0; alu_op = 6'h0E; data_width = 3'd2;
        #1 $display("[67] INC D: res=%h z=%b n=%b o=%b c=%b",
                    result, zero, negative, overflow, carry);
        // Test [68]: INC 0xFF (B)
        op_a = 64'hFF; op_b = 64'h0; alu_op = 6'h0E; data_width = 3'd0;
        #1 $display("[68] INC B: res=%h c=%b", result, carry);
        // Test [83]: CMP 0x43 > 0x42 (Q)
        op_a = 64'h43; op_b = 64'h42; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[83] CMP>: res=%h z=%b n=%b o=%b c=%b",
                    result, zero, negative, overflow, carry);
        // Test [84]: CMP 0x41 < 0x42 (Q)
        op_a = 64'h41; op_b = 64'h42; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[84] CMP<: res=%h z=%b n=%b c=%b",
                    result, zero, negative, carry);
        // Test [85]: CMP -1 < 0
        op_a = 64'hFFFFFFFFFFFFFFFF; op_b = 64'h0; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[85] CMP-1<0: res=%h n=%b c=%b", result, negative, carry);
        // Test [86]: CMP 0 > -1
        op_a = 64'h0; op_b = 64'hFFFFFFFFFFFFFFFF; alu_op = 6'h12; data_width = 3'd3;
        #1 $display("[86] CMP0>-1: res=%h n=%b c=%b", result, negative, carry);
        // Test [87]: CMP 127 > -128 (B)
        op_a = 64'h7F; op_b = 64'h80; alu_op = 6'h12; data_width = 3'd0;
        #1 $display("[87] CMP B: res=%h n=%b o=%b c=%b",
                    result, negative, overflow, carry);
        // Test [88]: TEST 0xFF & 0xFF (B)
        op_a = 64'hFF; op_b = 64'hFF; alu_op = 6'h13; data_width = 3'd0;
        #1 $display("[88] TEST B: res=%h z=%b n=%b", result, zero, negative);
        // Test [90]: TEST 0xAA & 0xA0 (Q)
        op_a = 64'hAA; op_b = 64'hA0; alu_op = 6'h13; data_width = 3'd3;
        #1 $display("[90] TEST Q: res=%h z=%b n=%b", result, zero, negative);
        // Test [91]: TEST MSB (Q)
        op_a = 64'h8000000000000000; op_b = 64'h8000000000000000; alu_op = 6'h13; data_width = 3'd3;
        #1 $display("[91] TEST MSB: res=%h z=%b n=%b", result, zero, negative);
        // Test [95]: MIN signed -5,5
        op_a = 64'hFFFFFFFFFFFFFFFB; op_b = 64'h5; alu_op = 6'h14; data_width = 3'd3;
        #1 $display("[95] MIN -5,5: res=%h", result);
        // Test [100]: MAX signed -5,5
        op_a = 64'hFFFFFFFFFFFFFFFB; op_b = 64'h5; alu_op = 6'h15; data_width = 3'd3;
        #1 $display("[100] MAX -5,5: res=%h", result);
        $finish;
    end
endmodule
