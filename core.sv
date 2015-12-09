module core(clk, rst_n, LP_pot, B1_pot, B2_pot, B3_pot, HP_pot, VOL_pot, lft_in, rht_in, valid, lft_out, rht_out, AMP_ON, LED);

input clk, rst_n, valid;
input [15:0] lft_in, rht_in;
input signed [11:0] LP_pot, B1_pot, B2_pot, B3_pot, HP_pot, VOL_pot; //assuming signed
output reg [15:0] lft_out, rht_out;
output reg AMP_ON;

reg valid_d, wrt_sig, wrt_en;
wire lft_seq_1024, lft_seq_1536;
wire rht_seq_1024, rht_seq_1536;
wire [15:0] lft_q1024_out, lft_q1536_out;
wire [15:0] rht_q1024_out, rht_q1536_out;
wire [15:0] lft_LP_out, lft_B1_out, lft_B2_out, lft_B3_out, lft_HP_out;
wire [15:0] rht_LP_out, rht_B1_out, rht_B2_out, rht_B3_out, rht_HP_out;
//scaled signals are gonna be signed
wire signed [15:0] lft_LP_scl, lft_B1_scl, lft_B2_scl, lft_B3_scl, lft_HP_scl;
wire signed [15:0] rht_LP_scl, rht_B1_scl, rht_B2_scl, rht_B3_scl, rht_HP_scl;
wire [15:0] lft_sum_out, rht_sum_out;
reg [15:0] lft_sum_out_buf, rht_sum_out_buf;
//3 extra bits for summing,12 for mult 

/**** LEFT CHANNEL****/

queue1024 lft_q1024(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(lft_in),
                    .smpl_out(lft_q1024_out),
                    .wrt_smpl(wrt_en & wrt_sig),
                    .sequencing(lft_seq_1024),
                    .AMP_ON(AMP_ON)
                    );

queue1536 lft_q1536(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(lft_in),
                    .smpl_out(lft_q1536_out),
                    .wrt_smpl(wrt_sig),
                    .sequencing(lft_seq_1536)
                    );

//Feed slower queue output samples to LP_FIR,B1_FIR,B2_FIR
LP_FIR lft_LP(.clk(clk),
              .rst_n(rst_n),
              .sequencing(lft_seq_1024),
              .smpl_in(lft_q1024_out),
              .smpl_out(lft_LP_out)
              );

B1_FIR lft_B1(.clk(clk),
              .rst_n(rst_n),
              .sequencing(lft_seq_1024),
              .smpl_in(lft_q1024_out),
              .smpl_out(lft_B1_out)
             );

B2_FIR lft_B2(.clk(clk),
              .rst_n(rst_n),
              .sequencing(lft_seq_1024),
              .smpl_in(lft_q1024_out),
              .smpl_out(lft_B2_out)
              );

B3_FIR lft_B3(.clk(clk),
              .rst_n(rst_n),
              .sequencing(lft_seq_1536),
              .smpl_in(lft_q1536_out),
              .smpl_out(lft_B3_out)
              );

HP_FIR lft_HP(.clk(clk),
              .rst_n(rst_n),
              .sequencing(lft_seq_1536),
              .smpl_in(lft_q1536_out),
              .smpl_out(lft_HP_out)
              );

band_scale lft_scale_lp(.pot(LP_pot),
                        .clk(clk),
                        .audio(lft_LP_out),
                        .scaled(lft_LP_scl)
                       );

band_scale lft_scale_B1(.pot(B1_pot),
                        .clk(clk),
                        .audio(lft_B1_out),
                        .scaled(lft_B1_scl)
                       );

band_scale lft_scale_B2(.pot(B2_pot),
                        .clk(clk),
                        .audio(lft_B2_out),
                        .scaled(lft_B2_scl)
                       );

band_scale lft_scale_B3(.pot(B3_pot),
                        .clk(clk),
                        .audio(lft_B3_out),
                        .scaled(lft_B3_scl)
                       );

band_scale lft_scale_HP(.pot(HP_pot),
                        .clk(clk),
                        .audio(lft_HP_out),
                        .scaled(lft_HP_scl)
                       );

/**** RIGHT CHANNEL****/

queue1024 rht_q1024(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(rht_in),
                    .smpl_out(rht_q1024_out),
                    .wrt_smpl(wrt_en & wrt_sig),
                    .sequencing(rht_seq_1024),
                    .AMP_ON()
                    );

queue1536 rht_q1536(.clk(clk),
                    .rst_n(rst_n),
                    .new_smpl(rht_in),
                    .smpl_out(rht_q1536_out),
                    .wrt_smpl(wrt_sig),
                    .sequencing(rht_seq_1536)
                    );

LP_FIR rht_LP(.clk(clk),
              .rst_n(rst_n),
              .sequencing(rht_seq_1024),
              .smpl_in(rht_q1024_out),
              .smpl_out(rht_LP_out)
             );

B1_FIR rht_B1(.clk(clk),
              .rst_n(rst_n),
              .sequencing(rht_seq_1024),
              .smpl_in(rht_q1024_out),
              .smpl_out(rht_B1_out)
             );

B2_FIR rht_B2(.clk(clk),
              .rst_n(rst_n),
              .sequencing(rht_seq_1024),
              .smpl_in(rht_q1024_out),
              .smpl_out(rht_B2_out)
             );

B3_FIR rht_B3(.clk(clk),
              .rst_n(rst_n),
              .sequencing(rht_seq_1536),
              .smpl_in(rht_q1536_out),
              .smpl_out(rht_B3_out)
             );

HP_FIR rht_HP(.clk(clk),
              .rst_n(rst_n),
              .sequencing(rht_seq_1536),
              .smpl_in(rht_q1536_out),
              .smpl_out(rht_HP_out)
             );

band_scale rht_scale_lp(.pot(LP_pot),
                        .clk(clk),
                        .audio(rht_LP_out),
                        .scaled(rht_LP_scl)
                       );

band_scale rht_scale_B1(.pot(B1_pot),
                        .clk(clk),
                        .audio(rht_B1_out),
                        .scaled(rht_B1_scl)
                       );

band_scale rht_scale_B2(.pot(B2_pot),
                        .clk(clk),
                        .audio(rht_B2_out),
                        .scaled(rht_B2_scl)
                       );

band_scale rht_scale_B3(.pot(B3_pot),
                        .clk(clk),
                        .audio(rht_B3_out),
                        .scaled(rht_B3_scl)
                       );

band_scale rht_scale_HP(.pot(HP_pot),
                        .clk(clk),
                        .audio(rht_HP_out),
                        .scaled(rht_HP_scl)
                       );

/**** OUTPUT ****/
band_scale_sum lft_scale_vol(.LP_scl(lft_LP_scl),
                             .B1_scl(lft_B1_scl),
                             .B2_scl(lft_B2_scl),
                             .B3_scl(lft_B3_scl),
                             .HP_scl(lft_HP_scl),
                             .out(lft_sum_out)
                            );

band_scale_sum rht_scale_vol(.LP_scl(rht_LP_scl),
                             .B1_scl(rht_B1_scl),
                             .B2_scl(rht_B2_scl),
                             .B3_scl(rht_B3_scl),
                             .HP_scl(rht_HP_scl),
                             .out(rht_sum_out)
                            );

always@(posedge clk, negedge rst_n)
  if(!rst_n) begin
    lft_sum_out_buf <= 16'h0;
    rht_sum_out_buf <= 16'h0;
  end else begin
    lft_sum_out_buf <= lft_sum_out;
    rht_sum_out_buf <= rht_sum_out;
  end


vol_scale lft_scale_vol_final(.pot(VOL_pot),
                               .clk(clk),
                               .audio(lft_sum_out_buf),
                               .scaled(lft_out)
                              );

vol_scale rht_scale_vol_final(.pot(VOL_pot),
                               .clk(clk),
                               .audio(rht_sum_out_buf),
                               .scaled(rht_out)
                              );

/**** TRIGGERS ****/

always @(posedge clk, negedge rst_n)
  if(!rst_n)
    valid_d <= 1'b0;
  else
    valid_d <= valid;

always @(posedge clk, negedge rst_n)
  if(!rst_n)
    wrt_sig <= 1'b0;
  else
    wrt_sig <= valid & ~valid_d;

always @(posedge clk, negedge rst_n) 
  if(!rst_n)
    wrt_en <= 1'b0;
  else if(wrt_sig)
    wrt_en <= ~wrt_en;


/**** LED EFFECTS ****/
 output reg [7:0] LED;
 // synopsys translate_off
 
 wire [15:0] LED_smpl, LED_out;
 wire q_sequencing;
 
queue_LED q_LED(.clk(clk),
                 .rst_n(rst_n),
                 .new_smpl(lft_B1_out),
                 .smpl_out(LED_smpl),
                 .wrt_smpl(wrt_en & wrt_sig),
                 .sequencing(q_sequencing)
                 );
 
LED_avg led_avg(.clk(clk),
                 .rst_n(rst_n),
                 .sequencing(q_sequencing),
                 .smpl_in(LED_smpl),
                 .smpl_out(LED_out)
                 );
 
assign LED = (LED_out[14] == 1) ? 8'hff :
                 (LED_out[13] == 1) ? 8'h7f:
                 (LED_out[12] == 1) ? 8'h3f:
                 (LED_out[11] == 1) ? 8'h1f:
                 (LED_out[10] == 1) ? 8'h0f:
                 (LED_out[9] == 1) ? 8'h07:
                 (LED_out[8] == 1) ? 8'h03: 8'h01;
 
 
// synopsys translate_on

endmodule
