module band_scale(clk, pot, audio, scaled);

input clk;
input [11:0] pot;
input signed [15:0] audio;
output wire [15:0] scaled;

wire [23:0] mult_pot;
reg signed [12:0] signed_mult_pot;
reg signed [28:0] signed_audio_scaled;
wire [3:0] sat_bits;
wire sat_pos, sat_neg;

assign mult_pot = pot*pot;

//Intentional flop stage
always@(posedge clk)
  signed_mult_pot <= {1'b0, mult_pot[23:12]};

//Intentional flop stage
always@(posedge clk) 
  signed_audio_scaled <= signed_mult_pot*audio;


assign sat_bits = signed_audio_scaled[28:25];
assign sat_pos = ((sat_bits[3] == 1'b0) && (sat_bits[2:0] > 3'b000)) ? 1'b1 : 1'b0;
assign sat_neg = ((sat_bits[3] == 1'b1) && (sat_bits[2:0] < 3'b111)) ? 1'b1 : 1'b0;
assign scaled = (sat_pos == 1'b1) ? 16'h7fff :
                (sat_neg == 1'b1) ? 16'h8000 : signed_audio_scaled[25:10];
endmodule
