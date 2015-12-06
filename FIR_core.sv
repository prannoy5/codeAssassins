module CORE_FIR(clk, rst_n, sequencing, smpl_in, smpl_out, cff_ptr, cff_out);

parameter NUM_COEFF = 1021;
input clk, rst_n, sequencing;
input signed [15:0] smpl_in;
input signed [15:0] cff_out;

reg inc_smpl, clr_accum;
output reg [9:0] cff_ptr;
reg [31:0] accum;
reg signed [15:0] cff_out;
output reg [15:0] smpl_out;
wire flt_done;
wire signed [31:0] mult;

typedef enum reg [1:0] {IDLE, MAC} state;
state st, nxt_st;

//For addressing the ROM
always@(posedge clk, negedge rst_n) 
  if(!rst_n)
    cff_ptr <= 10'h0;
  else 
    if(inc_smpl)
      cff_ptr <= cff_ptr + 1;
    else
      cff_ptr <= 10'h0; //keep it reset by default

//Filter done logic
//Asserting done 1 cycle later to give the MAC extra time 
assign flt_done = (cff_ptr == 1022) ? 1'b1 : 1'b0;

assign mult = cff_out*smpl_in;

//MAC
always@(posedge clk, negedge rst_n) 
  if(!rst_n) 
    accum <= 32'hx;
  else
    if(clr_accum)
      accum <= 32'h0;
    else if(inc_smpl)
      accum <= accum + mult;

//Filter output
always@(posedge clk, negedge rst_n) 
  if(!rst_n) 
    smpl_out <= 16'hx;
  else if(flt_done) 
    smpl_out <= accum[30:15];

//SM
always@(posedge clk, negedge rst_n) 
  if(!rst_n) 
    st <= IDLE;
  else 
    st <= nxt_st;

always_comb begin
  clr_accum = 1'b0;
  inc_smpl = 1'b0;
  nxt_st = IDLE;

  case(st)
    IDLE:
      if(sequencing) begin
        clr_accum = 1'b1;
        inc_smpl = 1'b1; //why here
        nxt_st = MAC; 
      end else 
        nxt_st = IDLE;
      
    MAC:
      if(sequencing) begin
        inc_smpl = 1'b1;
        nxt_st = MAC;
      end else
        nxt_st = IDLE;

  endcase
end

endmodule
