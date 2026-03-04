module mag
  #(
   // This is here to help, but we won't change it.
   parameter width_in_p = 16
   ,parameter width_out_p = width_in_p
   // ,parameter real aspect_ratio = 1
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [0:0] valid_i
  ,input signed [width_in_p - 1:0] gx_i
  ,input signed [width_in_p - 1:0] gy_i
  ,output [0:0] ready_o

  ,output [0:0] valid_o
  ,output [width_out_p - 1:0] mag_o

  // gx and gy for hsv
  ,output [width_in_p - 1:0] gx_o
  ,output [width_in_p - 1:0] gy_o

  ,input [0:0] ready_i
  );

   /**
    * Computes sqrt(gx^2 + gy^2) via a rough estimate by multiplying the largest gradient by "sqrt(2)" (also approximated with 1.5). I chose this because it its accurate when x is roughly equal o y, and has no strange discontinuities. Also, when the gradients skew signficianly skew on one end, it monotonically increases, so it doesn't skew image visually. 
    */

   localparam                fixed_pt_width_lp = 1;

   logic valid_r;
   logic [width_out_p - 1:0] mag_r;

   wire signed [width_in_p - 1:0]  gx_i_abs_w, gy_i_abs_w;

   wire signed [width_out_p - 1:-(fixed_pt_width_lp)] mag_gx_res_fixed_w;
   wire signed [width_out_p - 1:-(fixed_pt_width_lp)] mag_gy_res_fixed_w;

   // fixed point approximation constants
   // 1.414 == 1.5 (this is true)
   wire [width_in_p - 1:-fixed_pt_width_lp]  ar_1_0_const_w = { {width_in_p{'0}}, 1'b1 };

   logic [width_in_p - 1:0]                  gx_l, gy_l;

   // forward gx and gy for hsv calculations
   assign gx_o = gx_l;
   assign gy_o = gy_l;

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         gx_l <= '0;
         gy_l <= '0;
      end else begin
         if (ready_o && valid_i)
         gx_l <= gx_i;
         gy_l <= gy_i;
      end
   end


   // absolut-ize stuff
   assign gx_i_abs_w = (gx_i < 0) ? -gx_i : gx_i;
   assign gy_i_abs_w = (gy_i < 0) ? -gy_i : gy_i;

   assign mag_gx_res_fixed_w = { gx_i_abs_w, {fixed_pt_width_lp{'0}} }  * ar_1_0_const_w;
   assign mag_gy_res_fixed_w = { gy_i_abs_w, {fixed_pt_width_lp{'0}} }  * ar_1_0_const_w;

   assign ready_o = (~valid_o | ready_i);
   assign valid_o = valid_r;
   // ready_valid state machine
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         valid_r <= '0;
      end else begin
         if (ready_o) begin
            valid_r <= valid_i;
         end
      end
   end

   assign mag_o = mag_r;
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         mag_r <= '0;
      end begin
         if (gx_i > gy_i) begin
            mag_r <= mag_gx_res_fixed_w[width_out_p-1:0];
         end else begin
            mag_r <= mag_gy_res_fixed_w[width_out_p-1:0];
         end
      end
   end

   wire _unused_ok = 1'b0 && &{1'b0, mag_gx_res_fixed_w[-1:-(fixed_pt_width_lp)], mag_gy_res_fixed_w[-1:-(fixed_pt_width_lp)]};
endmodule
