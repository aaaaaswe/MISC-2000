module tb_debug;
    logic [63:0] a, b;
    initial begin
        a = 64'hFFFFFFFFFFFFFFFB;
        b = 64'd5;
        $display("a = %h", a);
        $display("b = %h", b);
        $display("a<b signed? %b", ($signed(a) < $signed(b)));
        $display("a<b unsigned? %b", (a < b));
    end
endmodule
