module LED_avg(clk, rst_n, sequencing, smpl_in, smpl_out);
input clk, rst_n, sequencing;
input signed [15:0] smpl_in;

reg inc_smpl, clr_accum;
reg [9:0] ptr;
reg [24:0] accum; //designed to hold ten 15 bit values 
                  //since all audio samples are converted to their mod
output reg [15:0] smpl_out;
wire flt_done;

typedef enum reg [1:0] {IDLE, ACCUM} state;
state st, nxt_st;

//For addressing the ROM
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        ptr <= 10'h0;
    end else begin
        if(inc_smpl)
            ptr <= ptr +1;
        else
            ptr <= 10'h0; //keep it reset by default
    end
end

//Filter done logic
assign flt_done = (ptr == 1021) ? 1'b1 : 1'b0;

//Accumulator
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        accum <= 25'hx;
    end else begin
        if(clr_accum)
            accum <= 25'h0;
        else if(inc_smpl)
            accum <= accum + smpl_in;
    end
end

//Filter output
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        smpl_out <= 16'hx;
    end else begin
        //if(flt_done_d) 
        if(flt_done) 
            smpl_out <= accum[24:9];
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
clr_accum = 1'b0;
inc_smpl = 1'b0;
case(st)
    IDLE:
        if(sequencing) begin
            clr_accum = 1'b1;
            inc_smpl = 1'b1;
            nxt_st = ACCUM; 
        end else begin
            nxt_st = IDLE;
        end
    ACCUM:
        if(sequencing) begin
            inc_smpl = 1'b1;
            nxt_st = ACCUM;
        end else begin
            nxt_st = IDLE;
        end
endcase
end

endmodule
