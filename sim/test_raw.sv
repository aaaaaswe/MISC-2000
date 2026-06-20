module raw_sar;
    logic [63:0] a, r;
    initial begin
        a = 64'h8000000000000000;
        r = a >>> 4;
        $display("raw >>> 4: %h", r);
    end
endmodule
