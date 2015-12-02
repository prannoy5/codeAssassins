/******************************************************
* Fall 2015 ECE551 Project
* 5-channel Stereo Equalizer
******************************************************/
module Equalizer(clk,RST_n,LED,A2D_SS_n,A2D_MOSI,A2D_SCLK,A2D_MISO,MCLK,SCL,LRCLK,SDout,SDin,AMP_ON,RSTn);

input clk,RST_n;		// 50MHz clock and asynch active low reset from push button
output [7:0] LED;		// Active high outputs that drive LEDs
output A2D_SS_n;		// Active low slave select to ADC
output A2D_MOSI;		// Master Out Slave in to ADC
output A2D_SCLK;		// SCLK on SPI interface to ADC
input A2D_MISO;			// Master In Slave Out from ADC
output MCLK;			// 12.5MHz clock to CODEC
output SCL;				// serial shift clock clock to CODEC
output LRCLK;			// Left/Right clock to CODEC
output SDin;			// forms serial data in to CODEC
input SDout;			// from CODEC SDout pin (serial data in to core)
output AMP_ON;			// signal to turn amp on
output RSTn;			// active low reset to CODEC

wire rst_n;				// internal global active low reset
wire valid;
wire strt_cnv,cnv_cmplt;
//wire valid_fall,valid_rise;
wire [15:0] lft_in,rht_in;
wire [15:0] lft_out,rht_out;
//wire [15:0] lft_out_sel,rht_out_sel;
wire [2:0] chnnl;
wire [11:0] res;
wire [11:0] LP_pot,B1_pot,B2_pot,B3_pot,HP_pot,volume;
reg [10:0] del;

/////////////////////////////////////
// Instantiate Reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

////////////////////////////////
// Instantiate A2D Interface //
//////////////////////////////
A2D_intf_P iA2D(.clk(clk),.rst_n(rst_n),.strt_cnv(strt_cnv),.cnv_cmplt(cnv_cmplt),.chnnl(chnnl),.res(res),
              .a2d_SS_n(A2D_SS_n),.SCLK(A2D_SCLK),.MOSI(A2D_MOSI),.MISO(A2D_MISO));
			  
///////////////////////////////////////////
// Instantiate Your Slide Pot Interface //
/////////////////////////////////////////
slide_intf iSLD(.clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .chnnl(chnnl), .cnv_cmplt(cnv_cmplt), .res(res),
                .POT_LP(LP_pot), .POT_B1(B1_pot), .POT_B2(B2_pot), .POT_B3(B3_pot), .POT_HP(HP_pot),
                .VOLUME(volume));		
				
///////////////////////////////////////
// Instantiate Your CODEC Interface //
/////////////////////////////////////
codec_intf iCS(.clk(clk), .rst_n(rst_n), .lft_in(lft_in), .rht_in(rht_in), .lft_out(lft_out), .rht_out(rht_out),
                  .valid(valid), .RSTn(RSTn), .MCLK(MCLK), .SCLK(SCL), .LRCLK(LRCLK), .SDin(SDin), .SDout(SDout));

///////////////////////////////////
// Instantiate Equalizer Engine //
/////////////////////////////////
core iCore(.clk(clk), .rst_n(rst_n), .LP_pot(LP_pot), .B1_pot(B1_pot), .B2_pot(B2_pot), .B3_pot(B3_pot), 
            .HP_pot(HP_pot), .VOL_pot(volume), .lft_in(lft_in), .rht_in(rht_in), .valid(valid), 
            .lft_out(lft_out), .rht_out(rht_out));


////////////////////////////////////////////////////////////
// Instantiate LED effect driver (optional extra credit) //
//////////////////////////////////////////////////////////
	  
///////////////////////////////////////////////
// Implement logic for delaying Amp on till //
// after queues are steady.   (AMP_ON)     //
////////////////////////////////////////////



endmodule
