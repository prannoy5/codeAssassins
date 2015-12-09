/*---------------------------------------------------------------
  CS4272: Audio Codec model
  
  * mimic the CS4272 chip as configured in our audio circuit -
   namely- serial data will be in left justified format, 
    and the chip behaves in slave mode  
  author : brian coutinho bcoutinho@wisc.edu
----------------------------------------------------------------*/

module CS4272(MCLK, RSTn, SCLK, LRCLK, SDout, SDin, aout_lft, aout_rht);

parameter SAMPLES = 32768;   // number of audio samples (both left and right combined)
parameter SMPLOG2 = 15;

input MCLK;            // master clock to the chip
input RSTn;            // chip reset

input  SCLK;           // serial data clock
input  LRCLK;          // left-right clock - indicates which channel is on
output SDout;          // serial data output line
input  SDin;           // serial data input line

output reg [15:0] aout_lft; // flopped left audio on the input line
output reg [15:0] aout_rht; // flopped right audio on the input line

/*-- Internal signals --*/
reg   [15:0] audmem [0:SAMPLES-1];    // store audio samples in memory
reg   [SMPLOG2-1:0] audptr;           // pointer to read samples

reg   [15:0] outshiftreg;                // used for serial out 
reg   [15:0] inshiftreg;                 // used for serial out 
reg   LR_prev, SCLK_prev;                // edge detection flops
wire  newtrans, shiftout, shiftin;                // control signals

/*-- load the audio samples  --*/
initial 
begin
  //$readmemh("LP/audio_in_f40_a1000.dat", audmem);
  //$readmemh("B1/audio_in_f120_a1000.dat", audmem);
  //$readmemh("B2/audio_in_f500_a1000.dat", audmem);
  //$readmemh("B3/audio_in_f2500_a1000.dat", audmem);
  //$readmemh("HP/audio_in_f10000_a1000.dat", audmem);
  $readmemh("audio_in_mixed.dat", audmem);
end

/*-- Edge detection flops  --*/
always @(posedge MCLK or negedge RSTn)
  if(!RSTn)
    LR_prev  <=  1'b0;      // NOTE: this assumes rst_n is removed when LRCLK 1->0
  else
    LR_prev  <=  LRCLK;

always @(posedge MCLK or negedge RSTn)
  if(!RSTn)
    SCLK_prev  <=  1'b0;    // * a similar assumption as above
  else
    SCLK_prev  <=  SCLK; 

//-- LRCLK edge detection
assign newtrans =  LRCLK ^ LR_prev;     // since any edge indicates a new sample
assign flop_lft = ~LRCLK &  LR_prev;    // save left value on falling edge of LRCLK
assign flop_rht =  LRCLK & ~LR_prev;    // save right value on rising edge of LRCLK

//-- SCLK falling edge detection
assign shiftout = (~SCLK) & SCLK_prev;    
//-- SCLK rising edge detection
assign shiftin  = SCLK & (~SCLK_prev);

/*-- audio in pointer update --*/
always @(posedge MCLK or negedge RSTn)
  if(!RSTn)
    audptr  <=  0;
  else if(newtrans)
    audptr  <=  audptr + 1;


/*-- and .. the output shift register 
    give higher priority for newtrans --*/
always @(posedge MCLK or negedge RSTn)
begin
  if(!RSTn)
    outshiftreg  <=  16'h0000;
  else if(newtrans)
    outshiftreg  <=  audmem[audptr];
  else if(shiftout)
    outshiftreg  <=  {outshiftreg[14:0], outshiftreg[15]};
end

assign  SDout = outshiftreg[15];

/*-- the input shift register 
    note: in this case we shift-in the
    the last bit on the SCLK rising edge 
    a half SCLK cycle before LRCLK toggles
    This allows us to double flop the value
    to aout_lft and aout_rht --*/
always @(posedge MCLK or negedge RSTn)
begin
  if(!RSTn)
    inshiftreg  <=  16'h0000;
  else if(shiftin)
    inshiftreg  <=  {inshiftreg[14:0],SDin};
end

/*-- flop the shift reg values into aout_lft 
   and aout_rht flops --*/
always @(posedge MCLK or negedge RSTn)
begin
  if(!RSTn)
    aout_lft  <=  16'h0000;
  else if(flop_lft)
    aout_lft  <=  inshiftreg;
end

always @(posedge MCLK or negedge RSTn)
begin
  if(!RSTn)
    aout_rht  <=  16'h0000;
  else if(flop_rht)
    aout_rht  <=  inshiftreg;
end

endmodule
