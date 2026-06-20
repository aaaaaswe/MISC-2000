`include "../rtl/core/alu.sv"

module tb_test5;
    logic [64:0] add_ext;
    logic [64:0] sub_ext;
    initial begin
        // [6] case: 0xFFFFFFFF + 0x1 at Q
        add_ext = {1'b0, 64'hFFFFFFFF} + {1'b0, 64'h1};
        $display("Q_ADD: %h bit64=%b", add_ext, add_ext[64]);
        // [7] case: 0xFFFFFFFB + 0x3 at D
        add_ext = {1'b0, 64'hFFFFFFFFFFFFFFFB} + {1'b0, 64'h3};
        $display("D_ADD: %h bit32=%b bit63=%b", add_ext, add_ext[32], add_ext[63]);
    end
endmodule
