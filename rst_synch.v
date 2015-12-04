module rst_synch(rst_n,RST_n,clk);

input clk;
input RST_n;
output reg rst_n;

reg flop1_output;

//Code first flop
always@(negedge clk, negedge RST_n)
  if(!RST_n)
    flop1_output <= 1'b0;
  else
    flop1_output <= 1'b1;

//Code second flop
always@(negedge clk, negedge RST_n)
  if(!RST_n)
    rst_n <= 1'b0;
  else
    rst_n <= flop1_output;

endmodule

