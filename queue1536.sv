module queue1536(clk, rst_n, new_smpl, smpl_out, wrt_smpl, sequencing);

input clk, rst_n, wrt_smpl;
input [15:0] new_smpl; //lft_in or rht_in
output reg sequencing;
output reg [15:0] smpl_out;

reg [10:0] old_ptr, new_ptr, read_ptr, end_ptr;
reg [15:0] ram_rdata, ram_wdata;
reg write_en, readout_done;
logic inc_new, inc_old, readout, wr_data;

typedef enum reg [1:0] {IDLE, WAIT, FULL, READOUT} state;
state st, nxt_st;

//Circular RAM Queue
dualPort1536x16 ram(.clk(clk) ,.we(write_en) ,.waddr(new_ptr) ,.raddr(read_ptr) ,.wdata(ram_wdata) ,.rdata(ram_rdata));

//write ptr
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    new_ptr <= 1535; //so that the first entry is written to location 0
  else if (inc_new) 
    new_ptr <= (new_ptr + 1)%1536;

//old ptr (start of readout)
always @(posedge clk, negedge rst_n) 
  if(!rst_n) begin
    old_ptr <= 11'b0;
  else if(inc_old)
    old_ptr <= (old_ptr +1)%1536;
    
//read ptr (used for readout)
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    read_ptr <= 11'h0;
  else
    if (readout)
      read_ptr <= (read_ptr +1)%1536;
    else 
      read_ptr <= old_ptr;
    
//actually should be old_ptr + 1021 but old_ptr itself advances on wrt_smpl
//identify the end marker of readout
assign end_ptr = (old_ptr + 1020)%1536;

//readout finish indicator
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    readout_done <= 1'b0;
  else 
    if(read_ptr == end_ptr)
      readout_done <= 1'b1;
    else
      readout_done <= 1'b0;
    
//sequencing flag set/unset
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    sequencing <= 1'b0;
  else 
    if (readout)
      sequencing <= 1'b1;
    else 
      sequencing <= 1'b0;

//reading data from ram
always @(posedge clk, negedge rst_n)
  if(!rst_n) 
    smpl_out <= 16'hx; //helps save area
  else if(readout) //from SM
    smpl_out <= ram_rdata;

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

//State Machine
always @(posedge clk, negedge rst_n) 
  if(!rst_n) 
    st <= WAIT;
  else 
    st <= nxt_st;
    
always_comb begin
  inc_new = 1'b0;
  inc_old = 1'b0;
  wr_data = 1'b0;
  readout = 1'b0;
  nxt_st = WAIT;

  case(st)
    WAIT:
      if (wrt_smpl) begin
        wr_data = 1'b1;
        inc_new = 1'b1;
        if(new_ptr == 1530) begin
          inc_old = 1'b1;
          readout = 1'b1;
          nxt_st = READOUT;
        end else 
          nxt_st = WAIT;    
      end else 
          nxt_st = WAIT;

        
    FULL: 
      if(wrt_smpl) begin
        readout = 1'b1;
        wr_data = 1'b1;
        inc_new = 1'b1;
        inc_old = 1'b1;
        nxt_st = READOUT;
      end else 
        nxt_st = FULL;
    
    READOUT:
      if (readout_done == 1'b0) begin
        readout = 1'b1;
        nxt_st = READOUT;
      end else 
        nxt_st = FULL;
      
  endcase 
end

endmodule
