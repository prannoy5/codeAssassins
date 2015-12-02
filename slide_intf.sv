module slide_intf(clk,rst_n,POT_LP,POT_B1,POT_B2,POT_B3,POT_HP,VOLUME, chnnl, strt_cnv, res, cnv_cmplt);

input clk,rst_n;
input cnv_cmplt;
input [11:0]res;
output reg [11:0] POT_LP,POT_B1,POT_B2,POT_B3,POT_HP,VOLUME;
output reg strt_cnv;

//reg en_POT_LP,en_POT_B1,en_POT_B2,en_POT_B3,en_POT_HP,en_VOLUME;

typedef enum reg [2:0]{reading_LP,reading_B1,reading_B2,reading_B3,reading_HP,reading_VOLUME} state_type;
typedef enum reg [2:0]{chnl_LP,chnl_B1,chnl_B2,chnl_B3,chnl_HP,chnl_VOLUME=3'b111} chnnl_type;
state_type state,nxt_state;
output chnnl_type chnnl;

//Flop to maintain state
always_ff @(posedge clk, negedge rst_n)
begin
  if(!rst_n)
    state <= reading_LP;
  else
    state <= nxt_state;
end

//Combinational logic to control state machine
//that sends chnnl numbers
always_comb
begin

  //Defaults
  nxt_state = reading_LP;
  chnnl = chnl_LP;

  case (state)
    
    reading_LP : begin
              chnnl = chnl_LP;
              if(cnv_cmplt) 
	        nxt_state = reading_B1;		
  	      else 
	        nxt_state = reading_LP;              
           end

    reading_B1 : begin
              chnnl = chnl_B1;
              if(cnv_cmplt)
	        nxt_state = reading_B2;		
              else
	        nxt_state = reading_B1;
           end

    reading_B2 : begin
              chnnl = chnl_B2;
              if(cnv_cmplt)
	        nxt_state = reading_B3;		
              else
	        nxt_state = reading_B2;
           end

    reading_B3 : begin
              chnnl = chnl_B3;
              if(cnv_cmplt)
	        nxt_state = reading_HP;		
              else
	        nxt_state = reading_B3;
           end

    reading_HP : begin    
              chnnl = chnl_HP;        
              if(cnv_cmplt)
	        nxt_state = reading_VOLUME;		
              else
	        nxt_state = reading_HP;
           end

    reading_VOLUME : begin
              chnnl = chnl_VOLUME;
              if(cnv_cmplt)
	        nxt_state = reading_LP;		
              else
	        nxt_state = reading_VOLUME;
           end

  endcase
end

//Flop to maintain start conversion signal
//It's always 1 except when reset is asserted
//This is functionality correct as adc_intf only samples in IDLE state
always_ff @(posedge clk, negedge rst_n)
begin
  if(!rst_n)
    strt_cnv <= 1'b0;
  else
    strt_cnv <= 1'b1;
end

always_ff @ (posedge clk or negedge rst_n)
begin 
  if (!rst_n) begin
    POT_LP <= 12'h000;
    POT_B1 <= 12'h000;
    POT_B2 <= 12'h000;
    POT_B3 <= 12'h000;
    POT_HP <= 12'h000;
    VOLUME <= 12'h000;
  end else if ((chnnl == chnl_LP) && cnv_cmplt)
    POT_LP <= res;
  else if ((chnnl == chnl_B1) && cnv_cmplt)
    POT_B1 <= res;
  else if ((chnnl == chnl_B2) && cnv_cmplt)
    POT_B2 <= res;
  else if ((chnnl == chnl_B3) && cnv_cmplt) 
    POT_B3 <= res;
  else if ((chnnl == chnl_HP) && cnv_cmplt)
    POT_HP <=res;
  else if ((chnnl == chnl_VOLUME) && cnv_cmplt)
    VOLUME <= res;
end	  

endmodule

