module codec_intf(clk, rst_n, LRCLK, SCLK, MCLK, RSTn, SDout, SDin, lft_in, rht_in, valid, lft_out, rht_out);

input clk, rst_n, SDout;
input [15:0] lft_out, rht_out;
output reg LRCLK, SCLK, MCLK, RSTn, SDin, valid;
output reg [15:0] lft_in, rht_in;

reg [9:0] timer;
reg [4:0] shift_cnt;
reg [15:0] shift_reg, lft_in_buf, rht_in_buf;
logic shift_l, shift_r, set_valid, clr_valid;
logic lrclk_cycle_cmplt, clr_shift, inc_shift;

typedef enum reg[1:0] {IDLE, SHIFT_L, SHIFT_R} state_t;
state_t st, nxt_st;

assign LRCLK = timer[9];
assign SCLK = timer[4];
assign MCLK = timer[1];
assign sclk_posedge = (timer%32 == 16) ? 1'b1 : 1'b0;
assign sclk_negedge = (timer%32 == 0) ? 1'b1 : 1'b0;
assign lrclk_posedge = (timer%1024 == 512) ? 1'b1 : 1'b0;
assign lrclk_negedge = ((lrclk_cycle_cmplt == 1) && (timer%1024 == 0)) ? 1'b1 : 1'b0;

//for the timer
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        timer <= 10'h0; //does this have to be 10'h200
    end else begin
        timer <= timer + 1;
    end
end

//detecting lrclk cycle
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        lrclk_cycle_cmplt <= 1'b0;
    end else if (timer == 1023) begin
        lrclk_cycle_cmplt <= 1'b1;
    end
end

//for RSTn (obviously :))
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        RSTn <= 1'b0;
    else if (lrclk_negedge)
        RSTn <= 1'b1;
end

//valid
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        valid <= 1'b0;
    end else if (set_valid) begin
        valid <= 1'b1;
    end else if (clr_valid) begin
        valid <= 1'b0;
    end
end

//loading shift reg for out
always@(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        SDin <= 1'b0;
    end else begin
        SDin <= shift_reg[15];
    end
end

always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        shift_reg <= 16'b0;
    end else begin
        if(lrclk_posedge)
            shift_reg <= lft_out;
        else if (lrclk_negedge)
            shift_reg <= rht_out;
        else if(shift_l || shift_r) begin
            shift_reg <= shift_reg << 1;
        end //else maintain
    end
end
//buffering lft and rht signals
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        lft_in <= 16'h0;
        rht_in <= 16'h0;
    end else begin
        if (set_valid) begin
            lft_in <= lft_in_buf;
            rht_in <= rht_in_buf;
        end //else maintain
    end
end

//shift reg for lft_in, rht_in
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        lft_in_buf <= 15'b0;
        rht_in_buf <= 15'b0;
    end else begin
        if(shift_l) begin
            lft_in_buf <= {lft_in_buf[14:0], SDout};
        end else if (shift_r) begin
            rht_in_buf <= {rht_in_buf[14:0], SDout};
        end //else maintain
    end
end

//for keeping track of shift amount
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        shift_cnt <= 5'b0;
    end else begin
        if(clr_shift)
            shift_cnt <= 5'b0;
        else if(inc_shift)
            shift_cnt <= shift_cnt +1;
        //else maintain
    end
end

//codec SM
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        st <= IDLE;
    end else begin
        st <= nxt_st;
    end
end

always_comb begin
shift_l = 1'b0;
shift_r = 1'b0;
inc_shift = 1'b0;
clr_shift = 1'b0;
set_valid = 1'b0;
clr_valid = 1'b0;
  case (st)
    IDLE:
        if(RSTn && lrclk_posedge == 1'b1) begin //posedge LRCLK
            nxt_st = SHIFT_L;
        end else begin
            nxt_st = IDLE;
        end
    SHIFT_L:
        if(shift_cnt == 16) begin
            clr_shift = 1'b1;
            nxt_st = SHIFT_R;
        end else begin
            if(sclk_posedge == 1'b1) begin
                shift_l = 1'b1;
                inc_shift = 1'b1;
            end else if (sclk_negedge) begin
                clr_valid = 1'b1;
            end
            nxt_st = SHIFT_L;
        end
    SHIFT_R:
        if (shift_cnt == 16) begin
            set_valid = 1'b1;
            clr_shift = 1'b1;
            nxt_st = SHIFT_L;
        end else begin
            if(sclk_posedge == 1'b1) begin
                shift_r = 1'b1;
                inc_shift = 1'b1;
            end else if (sclk_negedge) begin
                clr_valid = 1'b1;
            end
            nxt_st = SHIFT_R;
       end
    default:
        nxt_st = IDLE;
  endcase

end

endmodule
