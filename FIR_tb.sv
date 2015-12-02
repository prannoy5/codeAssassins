module FIR_tb();

parameter SAMPLES = 8192;

reg clk, rst_n, valid_d, wrt_sig, wrt_en;
wire LRCLK, SCLK, MCLK, RSTn;
wire SDin, SDout, valid, sequencing_1024, sequencing_1536;
wire [15:0] lft_out, rht_out, lft_in, rht_in, q1024_out, q1536_out;
wire [15:0] LP_out, B1_out, B2_out, B3_out, HP_out;
wire [15:0] LP_scl, B1_scl, B2_scl, B3_scl, HP_scl;
wire [11:0] LP_pot, B1_pot, B2_pot, B3_pot, HP_pot, VOL_pot;

LP_FIR LP(.clk(clk),
            .rst_n(rst_n),
            .sequencing(sequencing_1024),
            .smpl_in(q1024_out),
            .smpl_out(LP_out)
            );
B1_FIR B1(.clk(clk),
            .rst_n(rst_n),
            .sequencing(sequencing_1024),
            .smpl_in(q1024_out),
            .smpl_out(B1_out)
            );
B2_FIR B2(.clk(clk),
            .rst_n(rst_n),
            .sequencing(sequencing_1024),
            .smpl_in(q1024_out),
            .smpl_out(B2_out)
            );
B3_FIR B3(.clk(clk),
            .rst_n(rst_n),
            .sequencing(sequencing_1536),
            .smpl_in(q1536_out),
            .smpl_out(B3_out)
            );
HP_FIR HP(.clk(clk),
            .rst_n(rst_n),
            .sequencing(sequencing_1536),
            .smpl_in(q1536_out),
            .smpl_out(HP_out)
            );
queue1024 q1024(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(lft_in), //testing lft chan first
                    .smpl_out(q1024_out),
                    .wrt_smpl(wrt_en & wrt_sig),
                    .sequencing(sequencing_1024)
                    );
queue1024 q1536(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(lft_in), //testing lft chan first
                    .smpl_out(q1536_out),
                    .wrt_smpl(wrt_sig),
                    .sequencing(sequencing_1536)
                    );
slide_intf slider(.clk(clk),
                    .rst_n(rst_n),
                    .POT_LP(LP_pot),
                    .POT_B1(B1_pot),
                    .POT_B2(B2_pot),
                    .POT_B3(B3_pot),
                    .POT_HP(HP_pot),
                    .VOLUME(VOL_pot)
                    );
band_scale scale_lp(.pot(LP_pot),
                    .audio(LP_out),
                    .scaled(LP_scl)
                    );
band_scale scale_B1(.pot(B1_pot),
                    .audio(B1_out),
                    .scaled(B1_scl)
                    );
band_scale scale_B2(.pot(B2_pot),
                    .audio(B2_out),
                    .scaled(B2_scl)
                    );
band_scale scale_B3(.pot(B3_pot),
                    .audio(B3_out),
                    .scaled(B3_scl)
                    );
band_scale scale_HP(.pot(HP_pot),
                    .audio(HP_out),
                    .scaled(HP_scl)
                    );
codec_intf intf(.clk(clk), 
                .rst_n(rst_n),
                .LRCLK(LRCLK), 
                .SCLK(SCLK), 
                .MCLK(MCLK), 
                .RSTn(RSTn), 
                .SDout(SDout), 
                .SDin(SDin), 
                .lft_in(lft_in),
                .rht_in(rht_in),
                .valid(valid),
                .lft_out(lft_out),
                .rht_out(rht_out)
                );
CS4272 codec(.MCLK(MCLK), 
            .RSTn(RSTn), 
            .SCLK(SCLK), 
            .LRCLK(LRCLK),
            .SDout(SDout),
            .SDin(SDin),
            .aout_lft(),
            .aout_rht()
            );

assign lft_out = 16'haaaa; //why is this fixed. why not take from equalizer
assign rht_out = 16'hffff; //why is this fixed. why not take from equalizer

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    //memptr = 1023;
    wrt_en = 1'b0;
    repeat(20) @(posedge clk);
    rst_n = 1'b1;
end

always #1 clk=~clk;

//For triggering wrt_smpl
always @(posedge clk) begin
    valid_d <= valid;
end

always @(posedge clk) begin
    wrt_sig = valid & ~valid_d;
    if(wrt_sig)
        wrt_en = ~wrt_en;
end

endmodule
