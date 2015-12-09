module Equalizer_tb_HPMax_VolUnity();

//This testbench tests the frequency and amplitude for the case when: 
//only filter HP is enabled (4KHz and above) with unity gain(0x800) and volume is at unity (0x800)

reg clk, RST_n;
wire A2D_SS_n, A2D_MOSI, A2D_MISO, A2D_SCLK;
wire LRCLK, SCLK, MCLK, RSTn, SDin, SDout, AMP_ON;
wire signed [15:0] aout_lft, aout_rht;
reg[12:0] cin;
reg signed [15:0] ain_lft, ain_rht;
reg signed [15:0] aout_lft_smooth,aout_rht_smooth;
reg signed [15:0] aout_lft_smooth_q,aout_rht_smooth_q;
reg signed [15:0] aout_lft_smooth_array[0:49],aout_rht_smooth_array[0:49];
reg signed [21:0] lft_smooth_sum,rht_smooth_sum;
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

integer fptr,fptr1,fptr2;
integer lft_sample_count,rht_sample_count;
integer lft_freq_errors,rht_freq_errors,lft_ampl_errors,rht_ampl_errors;
integer cin_lft, cin_rht;
integer zero_crossing_count_rht,zero_crossing_count_lft;
integer testing_sample_count;
integer min_sample_count,max_sample_count,ideal_sample_count,ideal_ampl,min_ampl,max_ampl;
integer index_lft,index_rht;
integer smooth_index,lft_smooth_index,rht_smooth_index;
integer smooth_flops;

//Convert audio_in.dat to audio_in.csv
initial begin
  fptr = $fopen("audio_out.csv", "w");
  fptr2 = $fopen("audio_out_smooth.csv", "w");
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

//Write smoothed wave to CSV
always@(aout_rht)
  $fdisplay(fptr2, "%d, %d", aout_lft_smooth, aout_rht_smooth);

///Generate Smoothed Output Audio for testing
always@(aout_lft) begin
  aout_lft_smooth_array[0] <= aout_lft;
  for(lft_smooth_index = 1; lft_smooth_index < smooth_flops; lft_smooth_index = lft_smooth_index + 1) 
    aout_lft_smooth_array[lft_smooth_index] <= aout_lft_smooth_array[lft_smooth_index-1];
end

always@(aout_rht) begin
  aout_rht_smooth_array[0] <= aout_rht;
  for(rht_smooth_index = 1; rht_smooth_index < smooth_flops; rht_smooth_index = rht_smooth_index + 1) 
    aout_rht_smooth_array[rht_smooth_index] <= aout_rht_smooth_array[rht_smooth_index-1];
end

always_comb begin
  lft_smooth_sum = 0;
  rht_smooth_sum = 0;
  for(smooth_index = 0; smooth_index < smooth_flops; smooth_index = smooth_index + 1) begin
    lft_smooth_sum += aout_lft_smooth_array[smooth_index];
    rht_smooth_sum += aout_rht_smooth_array[smooth_index];
  end
  aout_lft_smooth = lft_smooth_sum / smooth_flops;
  aout_rht_smooth = rht_smooth_sum / smooth_flops;
end

//Flops to help capture zero crossing in smoothed signal
always@(posedge clk) begin
  aout_lft_smooth_q <= aout_lft_smooth;
  aout_rht_smooth_q <= aout_rht_smooth;
end

//Create zero crossing pulse at negative to positive crossing
assign zero_crossing_lft = ~aout_lft_smooth[15] & aout_lft_smooth_q[15];
assign zero_crossing_rht = ~aout_rht_smooth[15] & aout_rht_smooth_q[15];

//Count samples and record amplitude for left channel
initial begin
  @(posedge zero_crossing_lft); //ignore first crossing as it is a 0 to x transition
  @(posedge zero_crossing_lft); //this one is the first proper crossing
  for(cin_lft = 0; cin_lft < testing_sample_count; cin_lft++) begin
    #1 lft_sample_count= lft_sample_count + 1; //delay here to avoid conflict with set to 0 from another block
    max_lft_ampl = (aout_lft_smooth > max_lft_ampl) ? aout_lft_smooth : max_lft_ampl;
    @(aout_lft_smooth); 
  end
end

//Count samples and record amplitude for right channel
initial begin
  @(posedge zero_crossing_rht); //ignore first crossing as it is a 0 to x transition
  @(posedge zero_crossing_rht); //this one is the first proper crossing
  for(cin_rht = 0; cin_rht < testing_sample_count; cin_rht++) begin
    #1 rht_sample_count = rht_sample_count + 1; //delay here to avoid conflict with set to 0 from another block
    max_rht_ampl = (aout_rht_smooth > max_rht_ampl) ? aout_rht_smooth : max_rht_ampl;
    @(aout_rht_smooth); 
  end
  $display("Number of right audio frequency errors = %d\n",rht_freq_errors);
  $display("Number of right audio amplitude errors = %d\n",rht_ampl_errors);
  $display("Number of left audio frequency errors = %d\n",lft_freq_errors);
  $display("Number of left audio amplitude errors = %d\n",lft_ampl_errors);
  $stop;
end

//Count number of samples at zero crossing time
//Count max amplitude at zero crossing time
always@(posedge zero_crossing_lft) begin

  //$display("Left Neg to Pos Crossing Found at Sample Num %d, Data %d and Count is %d\n",cin_lft,aout_lft,zero_crossing_count_lft);

  zero_crossing_count_lft = zero_crossing_count_lft + 1;

  //Do not consider zero crossings that 
  //(1) occurs before test start 
  //(2) occurs before second proper neg to pos crossing
  if (zero_crossing_count_lft > 2) begin  
    $display("Zero Crossing on Left Audio....Starting Testing\n");
    if ((lft_sample_count < min_sample_count) || (lft_sample_count > max_sample_count)) begin
      lft_freq_errors = lft_freq_errors + 1;
      $display("Erroneous Left Sample Count at Sample %d = %d\n",cin_lft,lft_sample_count);
    end

    if ((max_lft_ampl < min_ampl) || (max_lft_ampl > max_ampl)) begin
      lft_ampl_errors = lft_ampl_errors + 1;
      $display("Erroneous Left Amplitude at Sample %d = %d\n",cin_lft,max_lft_ampl);
    end

    lft_sample_count = 0;
    max_lft_ampl = 0;
  end

end

//Count number of samples at zero crossing time
//Count max amplitude at zero crossing time
always@(posedge zero_crossing_rht) begin

  //$display("Right Neg to Pos Crossing Found at Sample Num %d, Data %d and Count is %d\n",cin_rht,aout_rht,zero_crossing_count_rht);
  zero_crossing_count_rht = zero_crossing_count_rht + 1;

  //Do not consider zero crossings that 
  //(1) occurs before test start 
  //(2) occurs before second proper neg to pos crossing
  if (zero_crossing_count_rht > 2) begin  
    $display("Zero Crossing on Right Audio....Starting Testing\n");
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
  
  smooth_flops = 1;
  testing_sample_count = 160; //generate approx 4 full periods
  min_sample_count = 6;
  ideal_sample_count = 8; //not used, (48828 Hz / 6000 Hz) = 8
  max_sample_count = 10;
  min_ampl = 9600;
  ideal_ampl = 12800; //not used
  max_ampl = 16000;

  clk = 1'b0;
  RST_n = 1'b0;
  repeat(20) @(posedge clk);
  RST_n = 1'b1;

end

always #10 clk=~clk;

endmodule
