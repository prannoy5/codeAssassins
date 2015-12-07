module codec_intf(clk,rst_n,LRCLK,SCLK,MCLK,RSTn,SDout,SDin,lft_in,rht_in,valid,lft_out,rht_out);

input clk,rst_n;
input [15:0] lft_out;
input [15:0] rht_out;
input SDout;

output LRCLK;
output SCLK;
output MCLK;
output reg RSTn;
output SDin;
output [15:0] lft_in;
output [15:0] rht_in;
output reg valid;

reg [9:0] cnt_clk;
reg [1:0] state, next_state;
reg send_left,send_right;
reg [3:0] rht_bits_transferred;
reg q_LRCLK,q_SCLK,q_valid;
reg first_LRCLK_negedge_done;
wire posedge_LRCLK,negedge_LRCLK,posedge_SCLK,negedge_SCLK;
reg send_left_audio,send_right_audio;
reg [15:0] shift_reg_to_CODEC, lft_buffer, rht_buffer;
reg [15:0] shift_reg_lft_in;
reg [15:0] shift_reg_rht_in;


//Generate all required derived clocks
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    cnt_clk <= 10'h200;
  else
    cnt_clk <= cnt_clk + 1;

assign LRCLK = cnt_clk[9]; //clk by 1024
assign SCLK = cnt_clk[4]; // clk by 32
assign MCLK = cnt_clk[1]; // clk by 4

//Hold RSTn asserted until first cycle of LRCLK completes
always@(posedge clk, negedge rst_n)
  if(!rst_n) 
    RSTn <= 1'b0; 
  else if (posedge_LRCLK && first_LRCLK_negedge_done) 
    RSTn <= 1'b1;

always@(posedge clk, negedge rst_n)
  if(!rst_n)
    first_LRCLK_negedge_done <= 1'b0;
  else if(negedge_LRCLK)
    first_LRCLK_negedge_done <= 1'b1;    

//Rising edge detector for LRCLK
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    q_LRCLK <= 0;
  else
    q_LRCLK <= LRCLK;

assign posedge_LRCLK = ~q_LRCLK & LRCLK;
assign negedge_LRCLK = q_LRCLK & ~LRCLK;

//Rising edge detector for SCLK
///double-flopped for meta-stability
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    q_SCLK <= 0;
  else
    q_SCLK <= SCLK;

assign posedge_SCLK = ~q_SCLK & SCLK;
assign negedge_SCLK = q_SCLK & ~SCLK;

//Define states for state machine controlling data
//transfer from/to CODEC to/from digitizer core
localparam IDLE = 2'b00;
localparam SENDING_LEFT_AUDIO = 2'b01;
localparam SENDING_RIGHT_AUDIO = 2'b10;

//Encode state machine 
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    state <= IDLE;
  else
    state <= next_state;

always@(state,posedge_LRCLK,negedge_LRCLK,first_LRCLK_negedge_done)
  begin
    next_state = IDLE;
    send_left = 0;
    send_right = 0;

    case(state)

      IDLE: 
        if(posedge_LRCLK && first_LRCLK_negedge_done) 
          next_state = SENDING_LEFT_AUDIO;

      SENDING_LEFT_AUDIO: 
        begin
          send_left = 1;
          if(negedge_LRCLK)
            next_state = SENDING_RIGHT_AUDIO;
          else
            next_state = SENDING_LEFT_AUDIO;
        end

      SENDING_RIGHT_AUDIO: 
        begin
          send_right = 1;
          if(posedge_LRCLK)
            next_state = SENDING_LEFT_AUDIO;
          else
            next_state = SENDING_RIGHT_AUDIO;
        end

    endcase
end

//////////////////// CODEC TO DIGITIZER CIRCUITRY ////////////////////////

//Send audio data from CODEC to digitizer core
//at posedge of SCLK when commanded to do so by SM
always@(posedge clk, negedge rst_n)
  if(!rst_n) begin
    shift_reg_lft_in <= 16'h0000; 
    shift_reg_rht_in <= 16'h0000; 
  end
  else if(posedge_SCLK && send_left)
    shift_reg_lft_in <= {shift_reg_lft_in[14:0],SDout};
  else if(posedge_SCLK && send_right)
    shift_reg_rht_in <= {shift_reg_rht_in[14:0],SDout};

assign lft_in = shift_reg_lft_in;
assign rht_in = shift_reg_rht_in;

//Keep track of number of right bits transferred
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    rht_bits_transferred <= 0;
  else if(posedge_SCLK && send_right)
    rht_bits_transferred <= rht_bits_transferred + 1; 

//Set valid bit on rising edge of SCLK when
//16th bit of right audio will be transferred
//and reset it on next falling edge of SCLK
//We use cnt_clk to assign new value to valid
//1 clk cycle before rising/falling edge of SCLK
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    valid <= 1'b0;
  //else if((cnt_clk[4:0] == 5'b01111) && (rht_bits_transferred == 15))
  else if(posedge_SCLK && (rht_bits_transferred == 15))
    valid <= 1'b1;
  //else if((cnt_clk[4:0] == 5'b11111) && (rht_bits_transferred == 0))
  else if(negedge_SCLK && (rht_bits_transferred == 0))
    valid <= 1'b0;

//////////////////// DIGITIZER TO CODEC CIRCUITRY ////////////////////////

//Load value from lft_out to lft_buffer whenever valid is asserted
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    lft_buffer <= 16'h0000;
  else if(valid)
    lft_buffer <= lft_out;

//Load value from rht_out to rht_buffer whenever valid is asserted
always@(posedge clk, negedge rst_n)
  if(!rst_n)
    rht_buffer <= 16'h0000;
  else if(valid)
    rht_buffer <= rht_out;

//Send audio data from digitizer core to CODEC
always@(posedge clk, negedge rst_n)
  if(!rst_n) 
    shift_reg_to_CODEC <= 16'h0000;
  else if(posedge_LRCLK)
    shift_reg_to_CODEC <= lft_buffer;
  else if(negedge_LRCLK)
    shift_reg_to_CODEC <= rht_buffer;
  else if(negedge_SCLK && (send_left || send_right))
    shift_reg_to_CODEC <= {shift_reg_to_CODEC[14:0],1'b0}; 

assign SDin = shift_reg_to_CODEC[15];

endmodule
