module HP_FIR(clk, rst_n, sequencing, smpl_in, smpl_out);

input clk, rst_n, sequencing;
input signed [15:0] smpl_in;

reg [9:0] cff_ptr;
reg signed [15:0] cff_out;
output reg [15:0] smpl_out;

ROM_HP rom_hp(.clk(clk), .addr(cff_ptr), .dout(cff_out));

CORE_FIR filter(.clk(clk),
                .rst_n(rst_n),
                .sequencing(sequencing),
                .smpl_in(smpl_in),
                .smpl_out(smpl_out),
                .cff_ptr(cff_ptr),
                .cff_out(cff_out)
                );

endmodule
