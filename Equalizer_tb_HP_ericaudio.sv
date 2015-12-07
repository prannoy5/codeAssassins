module Equalizer_tb_B3_ericaudio();

//This testbench tests the frequency and amplitude for the case when: 
//only filter B3 is enabled (1KHz to 4KHz) with unity gain(0x800) and volume is at unity (0x800)

reg clk, RST_n;
wire A2D_SS_n, A2D_MOSI, A2D_MISO, A2D_SCLK;
wire LRCLK, SCLK, MCLK, RSTn, SDin, SDout, AMP_ON;
wire signed [15:0] aout_lft, aout_rht;
reg[12:0] cin;
reg signed [15:0] ain_lft, ain_rht;
reg signed [15:0] aout_lft_q,aout_rht_q;
reg signed [15:0] max_lft_ampl,max_rht_ampl;
wire zero_crossing_lft,zero_crossing_rht;
wire pos_to_neg_zero_crossing_lft,pos_to_neg_zero_crossing_rht;

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
integer zero_crossing_count_rht,zero_crossing_count_lft;
integer testing_sample_count;
integer min_sample_count,max_sample_count,ideal_sample_count,ideal_ampl,min_ampl,max_ampl;
integer fluctuation_lft,fluctuation_rht;
integer index_lft,index_rht;
integer fluctuation_check_sample_count;

//Convert audio_in.dat to audio_in.csv
initial begin
  fptr = $fopen("audio_out.csv", "w");
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

assign pos_to_neg_zero_crossing_lft = aout_lft[15] & ~aout_lft_q[15];
assign pos_to_neg_zero_crossing_rht = aout_rht[15] & ~aout_rht_q[15];

//Count samples and record amplitude for left channel
initial begin
  @(posedge zero_crossing_lft); //ignore first crossing as it is a x to 0 transition
  @(posedge zero_crossing_lft);
  for(cin_lft = 0; cin_lft < testing_sample_count; cin_lft++) begin
    @(aout_lft); 
    #10 lft_sample_count = lft_sample_count + 1; //added delay to avoid conflict with always block resetting sample count
    max_lft_ampl = (aout_lft > max_lft_ampl) ? aout_lft : max_lft_ampl;
  end
end

//Count samples and record amplitude for right channel
initial begin
  @(posedge zero_crossing_rht); //ignore first crossing as it is a x to 0 transition
  @(posedge zero_crossing_rht);
  for(cin_rht = 0; cin_rht < testing_sample_count; cin_rht++) begin
    @(aout_rht); 
    #10 rht_sample_count = rht_sample_count + 1; //added delay to avoid conflict with always block resetting sample count
    max_rht_ampl = (aout_rht > max_rht_ampl) ? aout_rht : max_rht_ampl;
  end
  $display("Number of right audio frequency errors = %d\n",rht_freq_errors);
  $display("Number of right audio amplitude errors = %d\n",rht_ampl_errors);
  $display("Number of left audio frequency errors = %d\n",lft_freq_errors);
  $display("Number of left audio amplitude errors = %d\n",lft_ampl_errors);
  $stop;
end

//Count number of samples at zero crossing time. Should be around 16.
//Count max amplitude at zero crossing time. Should be around 4000
always@(posedge zero_crossing_lft) begin

  zero_crossing_count_lft = zero_crossing_count_lft + 1;

  $display("Left Neg to Pos Crossing Found at Sample Num %d, Data %d and Count is %d\n",cin_lft,aout_lft,zero_crossing_count_lft);

  //wait for few more sample before declaring this as "true" zero crossing.
  //It's not a true crossing if one of the next few sample turn out to be pos to neg crossing
  for(index_lft = 0; index_lft < fluctuation_check_sample_count; index_lft++) begin
    @(aout_lft);
    if(pos_to_neg_zero_crossing_lft)
      fluctuation_lft = 1; 
  end

  //Do not consider zero crossings that 
  //(1) occurs before test start 
  //(2) occurs after first proper neg to pos crossing
  //(3) is a fluctuation and not true crossing
  if ((zero_crossing_count_lft > 2) && !fluctuation_lft) begin  

    if ((lft_sample_count < min_sample_count) || (lft_sample_count > max_sample_count)) begin
      lft_freq_errors = lft_freq_errors + 1;
      $display("Erroneous Left Sample Count at Sample %d = %d\n",cin_lft,lft_sample_count);
    end

    if ((max_lft_ampl < min_ampl) || (max_lft_ampl > max_ampl)) begin
      lft_ampl_errors = lft_ampl_errors + 1;
      $display("Erroneous Left Amplitude at Sample %d = %d\n",cin_lft,max_lft_ampl);
    end

    //$display("Left Sample Count = %d\n",lft_sample_count);
    //$display("Left Amplitude = %d\n",max_lft_ampl);
    lft_sample_count = 0;
    max_lft_ampl = 0;
  end
end

//Count number of samples at zero crossing time. Should be around 16.
always@(posedge zero_crossing_rht) begin

  zero_crossing_count_rht = zero_crossing_count_rht + 1;

  $display("Right Neg to Pos Crossing Found at Sample Num %d, Data %d and Count is %d\n",cin_rht,aout_rht,zero_crossing_count_rht);

  //wait for few more sample before declaring this as "true" zero crossing.
  //It's not a true crossing if one of the next few sample turn out to be pos to neg crossing
  for(index_rht = 0; index_rht < fluctuation_check_sample_count; index_rht++) begin
    @(aout_rht);
    if(pos_to_neg_zero_crossing_rht)
      fluctuation_rht = 1; 
  end

  //Do not consider zero crossings that 
  //(1) occurs before test start 
  //(2) occurs after first proper neg to pos crossing
  //(3) is a fluctuation and not true crossing
  if ((zero_crossing_count_rht > 2) && !fluctuation_rht) begin  
    if ((rht_sample_count < min_sample_count) || (rht_sample_count > max_sample_count)) begin
      rht_freq_errors = rht_freq_errors + 1;
      $display("Erroneous Right Sample Count at Sample %d = %d\n",cin_rht,rht_sample_count);
    end

    if ((max_rht_ampl < min_ampl) || (max_rht_ampl > max_ampl)) begin
      rht_ampl_errors = rht_ampl_errors + 1;
      $display("Erroneous Right Amplitude at Sample %d = %d\n",cin_rht,max_rht_ampl);
    end

    rht_sample_count = 0;
    max_rht_ampl = 0;
  end
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
  zero_crossing_count_lft = 0;
  zero_crossing_count_rht = 0;
  fluctuation_lft = 0;
  fluctuation_rht = 0;

  testing_sample_count = 80; //generate approx 4 full periods
  fluctuation_check_sample_count = 3;
  min_sample_count = 14;
  ideal_sample_count = 19; //not used, (48828 Hz / 2560 Hz) = 19
  max_sample_count = 24;
  min_ampl = 2400;
  ideal_ampl = 3200; //not used
  max_ampl = 4000;

  clk = 1'b0;
  RST_n = 1'b0;
  repeat(20) @(posedge clk);
  RST_n = 1'b1;

end

always #10 clk=~clk;

endmodule
