module Equalizer_tb();

reg clk, RST_n;
wire A2D_SS_n, A2D_MOSI, A2D_MISO, A2D_SCLK;
wire LRCLK, SCLK, MCLK, RSTn, SDin, SDout, AMP_ON;
wire signed [15:0] aout_lft, aout_rht;
reg[12:0] cin;
reg signed [15:0] ain_lft, ain_rht;

Equalizer eq(.clk(clk),
                .RST_n(RST_n),
                .LED(),
                .A2D_SS_n(A2D_SS_n),
                .A2D_MOSI(A2D_MOSI),
                .A2D_MISO(A2D_MISO),
                .A2D_SCLK(A2D_SCLK),
                .MCLK(MCLK),
                .SCL(SCLK),
                .LRCLK(LRCLK),
                .SDout(SDout),
                .SDin(SDin),
                .AMP_ON(),
                .RSTn(RSTn)
                );

CS4272 codec(.MCLK(MCLK), 
                .RSTn(RSTn), 
                .SCLK(SCLK), 
                .LRCLK(LRCLK),
                .SDout(SDout),
                .SDin(SDin),
                .aout_lft(aout_lft),
                .aout_rht(aout_rht)
                );

ADC128S idut2 (.clk(clk),
                .rst_n(RST_n),
                .SS_n(A2D_SS_n),
                .SCLK(A2D_SCLK),
                .MISO(A2D_MISO),
                .MOSI(A2D_MOSI)
                );

integer fptr,fptr1;
initial begin
    fptr = $fopen("audio_out.csv", "w");
    $fmonitor(fptr, "%d, %d", aout_lft, aout_rht);
end

initial begin
  fptr1 = $fopen("audio_in.csv", "w");
  ain_lft = codec.audmem[0];
  ain_rht = codec.audmem[1];
  $fdisplay(fptr1, "%d, %d", ain_lft,ain_rht);
  for( cin = 0; cin < 4096; cin = cin+1 ) begin
    ain_lft = codec.audmem[(cin+1)*2];
    ain_rht = codec.audmem[(cin+1)*2+1];
    $fdisplay(fptr1, "%d, %d", ain_lft, ain_rht);
  end
end

initial begin
    clk = 1'b0;
    RST_n = 1'b0;
    repeat(20) @(posedge clk);
    RST_n = 1'b1;
    //force eq.LP_pot = 12'h3ff;
    //force eq.B1_pot = 12'h3ff;
    //force eq.B2_pot = 12'h3ff;
    //force eq.B3_pot = 12'h3ff;
    //force eq.HP_pot = 12'h3ff;
    //force eq.volume = 12'h3ff;
end

always #10 clk=~clk;

endmodule
