module queue1024(clk, rst_n, new_smpl, smpl_out, wrt_smpl, sequencing);

input clk, rst_n, wrt_smpl;
input [15:0] new_smpl; //lft_in or rht_in
output reg sequencing;
output reg [15:0] smpl_out;

reg [9:0] old_ptr, new_ptr, read_ptr, end_ptr;
reg [15:0] ram_rdata, ram_wdata;
reg we, readout_done;
logic inc_new, inc_old, readout, wr_data;

typedef enum reg [1:0] {IDLE, WAIT, FULL, READOUT} state;
state st, nxt_st;

dualPort1024x16 ram(.clk(clk) ,.we(we) ,.waddr(new_ptr) ,.raddr(read_ptr) ,.wdata(ram_wdata) ,.rdata(ram_rdata));

//write ptr
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        new_ptr <= 1023; //so that the first store is in 0
    end else begin
        if (inc_new)
            new_ptr <= new_ptr + 1;
    end
end

//old ptr (start of read)
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        old_ptr <= 10'b0;
    end else begin
        if(inc_old)
            old_ptr <= old_ptr +1;
    end
end

//read ptr (used for readout)
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        read_ptr <= 10'b0;
    end else begin
        if (readout)
            read_ptr <= read_ptr +1;
        else 
            read_ptr <= old_ptr;
    end
end
assign end_ptr = old_ptr + 1020;
//actually should be old_ptr + 1021 but old_ptr itself advances on wrt_smpl

//readout finish indicator
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        readout_done <= 1'b0;
    end else begin
        if(read_ptr == end_ptr)
            readout_done <= 1'b1;
        else
            readout_done <= 1'b0;
    end
end

//sequencing flag set/unset
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        sequencing <= 1'b0;
    end else begin
        if (readout)
            sequencing <= 1'b1;
        else 
            sequencing <= 1'b0;
    end
end

//reading data from ram
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        smpl_out <= 16'hx;
    end else begin
        if(readout) //from SM
            smpl_out <= ram_rdata;
        else
            smpl_out <= 16'hx;
    end
end

//writing data to ram
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        we <= 1'b0;
        ram_wdata <= 16'hx; //deliberately keeping x to save area
    end else begin
        if(wr_data) begin
            we <= 1'b1;
            ram_wdata <= new_smpl;
        end else begin
            we <= 1'b0;
            ram_wdata <= 16'hx; //keeping x to save area
        end
    end
end

always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        st <= WAIT;
    end else begin
        st <= nxt_st;
    end
end

always_comb begin
inc_new = 1'b0;
inc_old = 1'b0;
wr_data = 1'b0;
readout = 1'b0;

case(st)
    WAIT:
        if (rst_n && wrt_smpl) begin
            wr_data = 1'b1;
            inc_new = 1'b1;
            if(new_ptr == 1021) begin
                inc_old = 1'b1;
                readout = 1'b1;
                nxt_st = READOUT;
            end else begin
                nxt_st = WAIT;
            end
        end else begin
            nxt_st = WAIT;
        end
    FULL: 
        if(wrt_smpl) begin
            wr_data = 1'b1;
            inc_new = 1'b1;
            inc_old = 1'b1;
            readout = 1'b1;
            nxt_st = READOUT;
        end else begin
            nxt_st = FULL;
        end
    READOUT:
        if (readout_done == 1'b0) begin
            readout = 1'b1;
            nxt_st = READOUT;
        end else begin
            nxt_st = FULL;
        end
endcase 
end

endmodule
