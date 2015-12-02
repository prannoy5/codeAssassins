module rst_synch(RST_n, clk, rst_n);
input RST_n, clk;
output reg rst_n;

always@(negedge clk, negedge RST_n) begin
    if(!RST_n) begin
        rst_n <= 1'b0;
    end else begin
        rst_n <= 1'b1;
    end
end

endmodule
