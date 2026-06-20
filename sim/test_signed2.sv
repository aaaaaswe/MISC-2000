module tb_debug2;
    logic [63:0] a, b;
    logic [63:0] result;
    initial begin
        a = 64'hFFFFFFFFFFFFFFFB;
        b = 64'd5;
        result = (a < b) ? a : b;
        $display("unsigned: res = %h", result);
        result = ($signed(a) < $signed(b)) ? a : b;
        $display("signed:   res = %h", result);
    end
endmodule
