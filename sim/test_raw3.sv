module raw_check;
    logic [64:0] ext;
    initial begin
        ext = {1'b0, 64'h0} - {1'b0, 64'hFFFFFFFFFFFFFFFF};
        $display("Q: 0-(-1) 64-5bit = %h bit64=%b", ext, ext[64]);
        ext = {1'b0, 64'h43} - {1'b0, 64'h42};
        $display("Q: 43-42 = %h bit64=%b", ext, ext[64]);
    end
endmodule
