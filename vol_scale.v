module vol_scale(clk, pot, audio, scaled);

input clk;
input [11:0] pot;
input signed [15:0] audio;
output wire [15:0] scaled;
wire signed [12:0] signed_pot;
reg signed [28:0] signed_audio_scaled;

assign signed_pot = {1'b0, pot[11:0]};

//Intentional flop stage
always@(posedge clk) 
  signed_audio_scaled <= signed_pot*audio;

//Bit 28 can't be set anyway
assign scaled = signed_audio_scaled[27:12];

endmodule
