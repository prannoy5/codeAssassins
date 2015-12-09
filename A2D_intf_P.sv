module A2D_intf_P (clk,rst_n,strt_cnv,cnv_cmplt,chnnl,res,a2d_SS_n,SCLK,MOSI,MISO);

input clk,rst_n,MISO,strt_cnv;
input [2:0]chnnl;

output [11:0]res;
output a2d_SS_n,SCLK,MOSI;

output wire cnv_cmplt;


reg wrt_en;      //SM output
wire done_en;	 // SM input


wire  [15:0]chnnl_sel;
assign chnnl_sel = {2'b00,chnnl,11'h000};


wire [15:0]rd_data_imm;

assign res = rd_data_imm [11:0];


SPI_mstr iDUT (.wrt(wrt_en),.cmd(chnnl_sel),.done(done_en),.rd_data(rd_data_imm),.clk(clk),.rst_n(rst_n),.SCLK(SCLK),.SS_n(a2d_SS_n),.MOSI(MOSI),.MISO(MISO));


typedef enum logic [1:0]{IDLE,CMD1,WAIT1,CMD2} state_t;

state_t state,nxt_state;

reg done_rcv;     // SM  output



/*always_ff @(posedge clk or negedge rst_n)
begin
if (!rst_n)
cnv_cmplt <= 0;
else if (strt_cnv)
cnv_cmplt <= 0;
else if (done_rcv)
cnv_cmplt <= 1;
end
*/

assign cnv_cmplt = (done_rcv) ? 1 : 0;

always_ff @(posedge clk or negedge rst_n)
begin
if(!rst_n)
state <= IDLE;
else 
state <= nxt_state;
end




always_comb
begin

done_rcv = 0;
wrt_en = 0;
nxt_state = IDLE;

case(state)
IDLE : begin
       if (strt_cnv)
	begin
	wrt_en = 1;
	nxt_state = CMD1;
	done_rcv=0;
	end
	else
	nxt_state = IDLE;
	end
CMD1 : if (done_en)	
	nxt_state = WAIT1 ;
	else
	begin
	nxt_state = CMD1;
	end
WAIT1 : begin
	nxt_state = CMD2;
	wrt_en = 1;
  	end
CMD2 : if (done_en)
	begin
	nxt_state = IDLE;
	done_rcv = 1;
	end
	else
	begin
	nxt_state = CMD2;
	end

default : begin
	  done_rcv = 0;
	  wrt_en = 0;
	  nxt_state = IDLE;
	 end

endcase
end


endmodule
