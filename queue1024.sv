module queue1024(clk, rst_n, new_smpl, smpl_out, wrt_smpl, sequencing, AMP_ON);

input clk, rst_n, wrt_smpl;
input [15:0] new_smpl; //lft_in or rht_in
output reg sequencing, AMP_ON;
output reg [15:0] smpl_out;

reg [9:0] old_ptr, new_ptr, read_ptr, end_ptr;
reg [15:0] ram_rdata, ram_wdata;
reg write_en, readout_done;
logic inc_new, inc_old, readout, wr_data, amp_on;

typedef enum reg [1:0] {IDLE, WAIT, FULL, READOUT} state;
state st, nxt_st;

//Circular RAM Queue
dualPort1024x16 ram(.clk(clk) ,.we(write_en) ,.waddr(new_ptr) ,.raddr(read_ptr) ,.wdata(ram_wdata) ,.rdata(ram_rdata));

//write ptr -- 1 write on every alternate valid signal
always @(posedge clk, negedge rst_n)
  if(!rst_n)
    new_ptr <= 1023; //so that the first store is in 0
  else if (inc_new) //from SM
    new_ptr <= new_ptr + 1;

//old ptr (start of read)
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    old_ptr <= 10'b0;
  else if(inc_old) //from SM
    old_ptr <= old_ptr + 1;

//read ptr (used for readout)
//On readout signal, read all 1021 values by incrementing read_ptr
//otherwise, maintain read_ptr = old_ptr
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    read_ptr <= 10'b0;
  else
    if (readout) //from SM
      read_ptr <= read_ptr + 1;
    else 
      read_ptr <= old_ptr;

//actually should be old_ptr + 1021 but old_ptr itself advances on wrt_smpl
//identify the end marker of readout
assign end_ptr = old_ptr + 1020;

//readout finish indicator
always @(posedge clk, negedge rst_n) 
  if(!rst_n)
    readout_done <= 1'b0;
  else 
    if(read_ptr == end_ptr)
      readout_done <= 1'b1;
    else
      readout_done <= 1'b0;

//sequencing flag set/unset - indicates to downstream module that data is being read out
always @(posedge clk, negedge rst_n)
  if(!rst_n)
    sequencing <= 1'b0;
  else
    if (readout) //from SM
      sequencing <= 1'b1;
    else 
      sequencing <= 1'b0;

//reading data from circular queue ram
always @(posedge clk, negedge rst_n)
  if(!rst_n)
    smpl_out <= 16'hx;
  else
    if(readout) //from SM
      smpl_out <= ram_rdata;
    else
      smpl_out <= 16'hx;

//Write enable control for writing to circular queue ram
always @(posedge clk, negedge rst_n)
  if(!rst_n)
    write_en <= 1'b0;
  else 
    if(wr_data) //from SM 
      write_en <= 1'b1;
    else
      write_en <= 1'b0;

//writing data to circular queue ram
always @(posedge clk, negedge rst_n)
  if(!rst_n) 
    ram_wdata <= 16'hx; //deliberately keeping x to save area
  else
    if(wr_data) //from SM
      ram_wdata <= new_smpl;
    else 
      ram_wdata <= 16'hx; //keeping x to save area

//Trigger to turn on Class-D Amplifiers
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        AMP_ON <= 1'b0;
    end else begin
        if(amp_on) //from SM
            AMP_ON <= 1'b1;
    end
end

//State machine 
always @(posedge clk, negedge rst_n)
  if(!rst_n) 
    st <= WAIT;
  else
    st <= nxt_st;  

//State machine encoding
always_comb begin
  inc_new = 1'b0;
  inc_old = 1'b0;
  wr_data = 1'b0;
  readout = 1'b0;
  amp_on = 1'b0;
  nxt_st = WAIT;

  case(st)
    WAIT:
      if(wrt_smpl) begin //is rst_n necessary??
        wr_data = 1'b1;
        inc_new = 1'b1; //inc_new and wrt_smpl will be set every alternate valid signal from CODEC
        if(new_ptr == 1020) begin //once 1021 samples have been written, "quickly" read out all 1021 values before next valid signal
          inc_old = 1'b1;
          readout = 1'b1;
          nxt_st = READOUT;
        end else 
          nxt_st = WAIT;
      end else 
        nxt_st = WAIT;
        
    FULL: 
      if(wrt_smpl) begin //once the queue is full for first time, at every alternate valid signal, read out 1021 values from old_ptr to new_ptr
        wr_data = 1'b1;
        inc_new = 1'b1;
        inc_old = 1'b1;
        readout = 1'b1;
        nxt_st = READOUT;
      end else 
        nxt_st = FULL;
        
    READOUT:
      if(readout_done == 1'b0) begin
        readout = 1'b1;
        nxt_st = READOUT;
      end else begin
        amp_on = 1'b1;
        nxt_st = FULL;
      end
        
  endcase 
end

endmodule
