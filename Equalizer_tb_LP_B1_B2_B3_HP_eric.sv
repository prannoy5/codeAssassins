module Equalizer_tb();

//This testbench tests the frequency and amplitude for the case when: 
//only filter B3 is enabled (1 to 4 KHZ) with unity gain(0x800) and volume is at max (0xFFF)

reg clk, RST_n;
wire A2D_SS_n, A2D_MOSI, A2D_MISO, A2D_SCLK;
wire LRCLK, SCLK, MCLK, RSTn, SDin, SDout, AMP_ON;
wire signed [15:0] aout_lft, aout_rht;
reg[12:0] cin;
reg signed [15:0] ain_lft, ain_rht;
reg signed [15:0] aout_lft_q,aout_rht_q;
reg signed [15:0] max_lft_ampl,max_rht_ampl;
wire zero_crossing_lft,zero_crossing_rht;

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
integer lft_sample_count,rht_sample_count;
integer lft_freq_errors,rht_freq_errors,lft_ampl_errors,rht_ampl_errors;
integer cin_lft, cin_rht;
integer start_lft_test,start_rht_test;
integer testing_sample_count;

//Convert audio_in.dat to audio_in.csv
initial begin
  fptr = $fopen("audio_out_LP_B1_B2_B3__HPeric.csv", "w");
  fptr1 = $fopen("audio_in_eric.csv", "w");
  ain_lft = codec.audmem[0];
  ain_rht = codec.audmem[1];
  $fdisplay(fptr1, "%d, %d", ain_lft,ain_rht);
  for( cin = 0; cin < 4096; cin = cin+1 ) begin
    ain_lft = codec.audmem[(cin+1)*2];
    ain_rht = codec.audmem[(cin+1)*2+1];
    $fdisplay(fptr1, "%d, %d", ain_lft, ain_rht);
  end
end

//Write both left and right outputs to audio_out.csv when right output changes
//since at that time, left would also have changed
always@(aout_rht)
  $fdisplay(fptr, "%d, %d", aout_lft, aout_rht);

//Flops to help capture zero crossing 
always@(posedge clk) begin
  aout_lft_q <= aout_lft;
  aout_rht_q <= aout_rht;
end

//Create zero crossing pulse at negative to positive crossing
assign zero_crossing_lft = ~aout_lft[15] & aout_lft_q[15];
assign zero_crossing_rht = ~aout_rht[15] & aout_rht_q[15];

//Count samples and record amplitude for left channel
initial begin
  repeat(10) @(zero_crossing_lft);
  start_lft_test = 1;
  for(cin_lft = 0; cin_lft < testing_sample_count; cin_lft++) begin
    @(aout_lft); 
    #10 lft_sample_count = lft_sample_count + 1; //added delay to avoid conflict with always block resetting sample count
    max_lft_ampl = (aout_lft > max_lft_ampl) ? aout_lft : max_lft_ampl;
  end
  start_lft_test = 0;
  $display("Number of left audio frequency errors = %d\n",lft_freq_errors);
  $display("Number of left audio amplitude errors = %d\n",lft_ampl_errors);
end

//Count samples and record amplitude for right channel
initial begin
  repeat(10) @(zero_crossing_rht);
  start_rht_test = 1;
  for(cin_rht = 0; cin_rht < testing_sample_count; cin_rht++) begin
    @(aout_rht); 
    #10 rht_sample_count = rht_sample_count + 1; //added delay to avoid conflict with always block resetting sample count
    max_rht_ampl = (aout_rht > max_rht_ampl) ? aout_rht : max_rht_ampl;
  end
  start_rht_test = 0;
  $display("Number of right audio frequency errors = %d\n",rht_freq_errors);
  $display("Number of right audio amplitude errors = %d\n",rht_ampl_errors);
  $stop;
end

//Count number of samples at zero crossing time. Should be around 16.
//Count max amplitude at zero crossing time. Should be around 4000
always@(posedge zero_crossing_lft) begin

    if (start_lft_test && ((max_lft_ampl < 2500) || (max_lft_ampl > 17000))) begin
    lft_ampl_errors = lft_ampl_errors + 1;
    $display("Erroneous Left Amplitude at Sample %d = %d\n",cin_lft,max_lft_ampl);
  end

  //$display("Left Sample Count = %d\n",lft_sample_count);
  //$display("Left Amplitude = %d\n",max_lft_ampl);
  lft_sample_count = 0;
  max_lft_ampl = 0;
end

//Count number of samples at zero crossing time. Should be around 16.
always@(posedge zero_crossing_rht) begin

  if (start_rht_test && ((max_rht_ampl < 2500) || (max_rht_ampl > 17000))) begin
    rht_ampl_errors = rht_ampl_errors + 1;
    $display("Erroneous Right Amplitude at Sample %d = %d\n",cin_rht,max_rht_ampl);
  end

  rht_sample_count = 0;
  max_rht_ampl = 0;
end

//Initalize clock and reset
initial begin
  lft_sample_count = 0;
  rht_sample_count = 0;
  max_lft_ampl = 0;
  max_rht_ampl = 0;
  lft_freq_errors = 0;
  rht_freq_errors = 0;
  lft_ampl_errors = 0;
  rht_ampl_errors = 0;
  start_lft_test = 0;
  start_rht_test = 0;
  testing_sample_count = 2000;
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
