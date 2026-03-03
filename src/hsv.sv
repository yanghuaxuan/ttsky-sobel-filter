module hsv
  #(
   // This is here to help, but we won't change it.
   parameter mag_width_p = 16
  ,parameter grad_width_p = 16
  ,parameter hsv_component_width_p = 8
  ,parameter hv_out_width_p = hsv_component_width_p * 2
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [0:0] valid_i
   // You'll get mag_i from the magnitude module. The magnitude module
   // will also need to provide gx and gy_i to this module -- passing
   // them through unmodified.
  ,input [mag_width_p - 1:0] mag_i
  ,input signed [grad_width_p - 1:0] gx_i
  ,input signed [grad_width_p - 1:0] gy_i
  ,output [0:0] ready_o

  ,output [0:0] valid_o
  ,output [hv_out_width_p - 1:0] hv_o
  ,input [0:0] ready_i
  );
   /**
    * Approximates arctan(y/x) by exploiting various arctan properties, resulting in only needing a couple of values in our "LUT". The disadvantage is that the LUT is actually a mux tree, which means accuracy is proportional to delay.
    */

   wire at_quad_2_w;
   wire [grad_width_p - 1:0] gx_abs_w, gy_abs_w;
   wire do_reflect_w;

   // wire en_w;
   logic valid_r;

   logic signed [grad_width_p - 1:0] gx_r, gy_r;

   wire [grad_width_p - 1:0] lut_abs_x_w, lut_abs_y_w;
   logic [hsv_component_width_p - 1:0] fine_l;

   logic [hsv_component_width_p - 1:0]        hue_l;
   wire [hsv_component_width_p - 1:0]        hue_el_w;
   wire [hsv_component_width_p - 1:0]        val_w;

   wire [grad_width_p - 1:0] el_lut_abs_x_w, el_lut_abs_y_w;

   wire [grad_width_p * 2 - 1:0]            el_comb_killer_data_w;

   // stage 1 ready_valid state machine
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         valid_r <= '0;
      end else begin
         if (ready_o) begin
            valid_r <= valid_i;
         end
      end
   end

   // gate input path to alleviate timing issues
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         gx_r <= '0;
         gy_r <= '0;
      end else begin
         gx_r <= gx_i;
         gy_r <= gy_i;
      end
   end

   // sigmoid LUT
   ram_1r1w_sync #(.WIDTH_P(hsv_component_width_p), .DEPTH_P(2048), .SIGMOID_INIT_P(1))
     sigmoid_lut
       (
        // Outputs
        .rd_data_o                      (val_w),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .rd_valid_i                     (valid_i),
        .rd_addr_i                      (mag_i[10:0]) // acceptable truncation
        );

   assign gx_abs_w = (gx_r < 0) ? -gx_r : gx_r;
   assign gy_abs_w = (gy_r < 0) ? -gy_r : gy_r;

   // at quadrant 2?
   assign at_quad_2_w = ((gx_r > 0) && (gy_r > 0)) || ((gx_r < 0) && (gy_r < 0));
   // should reflect at 45 degree slope?
   assign do_reflect_w = (gy_abs_w > gx_abs_w);

   // mux tree "LUT"
   assign lut_abs_x_w = (do_reflect_w) ? gy_abs_w : gx_abs_w;
   assign lut_abs_y_w = (do_reflect_w) ? gx_abs_w : gy_abs_w;

   // we need a pipeline to reduce combinational delay :(
   elastic #(.width_p(grad_width_p * 2))
     elastic_comb_killer
       (
        // Outputs
        .ready_o                        (ready_o),
        .valid_o                        (valid_o),
        .data_o                         (el_comb_killer_data_w),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .data_i                         ({lut_abs_x_w, lut_abs_y_w}),
        .valid_i                        (valid_i),
        .ready_i                        (ready_i));

   assign el_lut_abs_y_w = el_comb_killer_data_w[grad_width_p - 1:0];
   assign el_lut_abs_x_w = el_comb_killer_data_w[2 * grad_width_p - 1:grad_width_p];

   // weird binary decision tree to approximate at range 0-45
   always_comb begin
      if (el_lut_abs_y_w > ((el_lut_abs_x_w >> 2) + (el_lut_abs_x_w >> 3) + (el_lut_abs_x_w >> 5))) begin
         if (el_lut_abs_y_w > ((el_lut_abs_x_w >> 1) + (el_lut_abs_x_w >> 3) + (el_lut_abs_x_w >> 4))) begin
            fine_l = { {hsv_component_width_p-6{'0}}, 6'd39};
         end else begin
            fine_l = { {hsv_component_width_p-6{'0}}, 6'd28};
         end
      end else begin
         if (el_lut_abs_y_w > ((el_lut_abs_x_w >> 3) + (el_lut_abs_x_w >> 4))) begin
            fine_l = { {hsv_component_width_p-6{'0}}, 6'd17};
         end else begin
            fine_l = { {hsv_component_width_p-6{'0}}, 6'd6};
         end
      end
   end

   always_comb begin
      hue_l = fine_l;
      if (do_reflect_w) begin
         hue_l = 90 - fine_l;
      end
      if (at_quad_2_w) begin
         hue_l = 180 - hue_l;
      end
   end

   assign hv_o[hsv_component_width_p - 1:0] = hue_l;
   assign hv_o[hsv_component_width_p * 2 - 1:hsv_component_width_p] = val_w;
endmodule
