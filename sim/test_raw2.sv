module raw_signed_sar;
    logic signed [63:0] a;
    logic [63:0] r;
    initial begin
        a = 64'h8000000000000000;
        r = logic'(a >>> 4);
        $display("signed >>> 4: %h", r);
    end
endmodule
