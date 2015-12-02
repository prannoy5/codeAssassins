///////////////////////////////////////////////////////////////////////
// SPI master module that transmits and receives 16-bit packets     //
// cmd[15:0] is 16-bit packet that goes out on MOSI, rd_data[15:0] //
// is the 16-bit word that came back on MISO.                     //
// wrt is control signal to initiate a transaction. done is      //
// asserted when transaction is complete. SCLK is currently set //
// for 1:32 of clk (1.6MHz).                                   //
////////////////////////////////////////////////////////////////
module SPI_mstr(clk,rst_n,SS_n,SCLK,MISO,MOSI,wrt,done,rd_data,cmd);

  input clk,rst_n,wrt,MISO;
  input [15:0] cmd;					// command/data to slave
  output reg SS_n, done;			// both done and SS_n implemented as set/reset flops
  output SCLK,MOSI;
  
  output [15:0] rd_data;				// parallel data of MISO from EEPROM

  typedef enum reg[1:0] {IDLE,BITS,TRAIL} state_t;
  
  state_t state,nstate;			// declare enumerated states
  reg [4:0] dec_cntr;
  reg [4:0] bit_cntr;
  reg [15:0] shft_reg;			// stores the output to be serialized on MOSI
  
  ///////////////////////////////////
  // SM outputs are of type logic //
  /////////////////////////////////
  logic rst_cnt, en_cnt, shft;
  logic set_done, clr_done;

  ///////////////////////////////
  // Implement state register //
  /////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;

 //////////////////////////////////////////
  // Implement parallel to serial shift //
  // register who's MSB forms MOSI     //
  //////////////////////////////////////
  always_ff @(posedge clk)
	if (wrt)
      shft_reg <= cmd;
    else if (shft)
      shft_reg <= {shft_reg[14:0],MISO};

  ////////////////////////////
  // Implement bit counter //
  //////////////////////////
  always_ff @(posedge clk)
    if (rst_cnt)
      bit_cntr <= 5'b00000;
    else if (en_cnt)
      bit_cntr <= bit_cntr + 1'b1;

  //////////////////////////////
  // Implement pause counter //
  ////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  dec_cntr <= 5'b11000;
	else if (rst_cnt)
      dec_cntr <= 5'b11000;
    else
      dec_cntr <= dec_cntr - 1'b1;

  assign SCLK = dec_cntr[4];		// div 32, SCLK normally high
  
  ///////////////////////////////////////////
  // done implemented as a set/reset flop //
  /////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  done <= 1'b0;
	else if (set_done)
	  done <= 1'b1;
	else if (clr_done)
	  done <= 1'b0;
	  
  ////////////////////////////////////////////////////////
  // SS_n very similar to done except it is reset high //
  //////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  SS_n <= 1'b1;
	else if (set_done)
	  SS_n <= 1'b1;
	else if (clr_done)
	  SS_n <= 1'b0;
	  
  ////////////////////////////////////////
  // Implement SM that controls output //
  //////////////////////////////////////
  always_comb
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
      rst_cnt = 0; 
      en_cnt = 0;
      shft = 0;
      set_done = 0;
	  clr_done = 0;
	  nstate = IDLE;

      case (state)
        IDLE : begin
          rst_cnt = 1;
          if (wrt) 
		    begin
              nstate = BITS;
			  clr_done = 1;
			end
          else 
		    nstate = IDLE;
        end
        BITS : begin
          ////////////////////////////////////
          // For the 16 bits of the packet //
          //////////////////////////////////
          en_cnt = (dec_cntr==5'b11110) ? 1'b1 : 1'b0;
          shft = (dec_cntr==5'b11110) ? 1'b1 : 1'b0;	// shift 2 clocks after SCLK rise
		  if (bit_cntr[4])
		    nstate = TRAIL;
          else
            nstate = BITS;         
        end
        default : begin 	// this is TRAIL state
          /////////////////////////////////////////////////////////
          // This state keeps SS_n low for a while (back porch) //
          ///////////////////////////////////////////////////////
          if (dec_cntr==5'b11000)
		    begin
			  nstate = IDLE;
			  set_done = 1;
			end
		  else
		    nstate = TRAIL;
        end
      endcase
    end
  
  assign rd_data = shft_reg;			// when finished shft_reg will contain data read
  assign MOSI = shft_reg[15];

endmodule 
