module band_scale_sum(LP_scl, B1_scl, B2_scl, B3_scl, HP_scl, out);

input [15:0] LP_scl, B1_scl, B2_scl, B3_scl, HP_scl;
output wire [15:0] out;

wire signed [18:0] sum_out;
wire [2:0] sat_bits;
wire sat_pos, sat_neg;

assign sum_out = LP_scl + B1_scl + B2_scl + B3_scl + HP_scl;
assign sat_bits = sum_out[18:16];
assign sat_pos = ((sat_bits[2] == 1'b0) && (sat_bits[1:0] > 2'b00)) ? 1'b1 : 1'b0;
assign sat_neg = ((sat_bits[2] == 1'b1) && (sat_bits[1:0] < 2'b11)) ? 1'b1 : 1'b0;

assign out = (sat_pos == 1'b1) ? 16'h7fff :
                (sat_neg == 1'b1) ? 16'h8000 : sum_out[15:0];

endmodule
