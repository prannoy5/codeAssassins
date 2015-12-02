module CORE_FIR(clk, rst_n, sequencing, smpl_in, smpl_out, cff_ptr, cff_out);
parameter NUM_COEFF = 1021;
input clk, rst_n, sequencing;
input signed [15:0] smpl_in;
input signed [15:0] cff_out;

reg inc_smpl, clr_accum, rst_cff_ptr;
output reg [9:0] cff_ptr;
reg [31:0] accum;
reg signed [15:0] cff_out;
output reg [15:0] smpl_out;
wire flt_done;
wire signed [31:0] mult;

typedef enum reg [1:0] {IDLE, MAC} state;
state st, nxt_st;

//For addressing the ROM
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        cff_ptr <= 10'h0;
    end else begin
        if(inc_smpl)
            cff_ptr <= cff_ptr +1;
        else
            cff_ptr <= 10'h0; //keep it reset by default
    end
end

//Filter done logic
//Asserting done 1 cycle later to give the MAC extra time 
assign flt_done = (cff_ptr == 1022) ? 1'b1 : 1'b0;

assign mult = cff_out*smpl_in;

//MAC
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        accum <= 32'hx;
    end else begin
        if(clr_accum)
            accum <= 32'h0;
        else if(inc_smpl)
            accum <= accum + mult;
    end
end

//Filter output
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        smpl_out <= 16'hx;
    end else begin
        //if(flt_done_d) 
        if(flt_done) 
            smpl_out <= accum[31:16];
    end
end

//SM
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        st <= IDLE;
    end else begin
        st <= nxt_st;
    end
end

always_comb begin
rst_cff_ptr = 1'b0;
clr_accum = 1'b0;
inc_smpl = 1'b0;
case(st)
    IDLE:
        if(sequencing) begin
            rst_cff_ptr = 1'b1;
            clr_accum = 1'b1;
            inc_smpl = 1'b1; //why here
            nxt_st = MAC; 
        end else begin
            nxt_st = IDLE;
        end
    MAC:
        if(sequencing) begin
            inc_smpl = 1'b1;
            nxt_st = MAC;
        end else begin
            nxt_st = IDLE;
        end
endcase
end

endmodule
