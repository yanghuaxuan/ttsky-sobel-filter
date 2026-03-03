module rgb2gray
  #(
   // This is here to help, but we won't change it.
   parameter width_p = 8
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [0:0] valid_i
  ,input [width_p - 1:0] red_i
  ,input [width_p - 1:0] blue_i
  ,input [width_p - 1:0] green_i
  ,output [0:0] ready_o

  ,output [0:0] valid_o
  ,output [width_p - 1:0] gray_o
  ,input [0:0] ready_i
  );

   // The testbench uses this function to test your code. How many
   // fractional bits are needed to enode these values?

   // gray = 0.2989 * r + 0.5870 * g + 0.1140 * b

   // Your code here
   localparam fixed_bits = 11;

   logic valid_d, valid_q_r;
   localparam [width_p - 1:-fixed_bits] r_scale = { {8{1'b0}}, 11'b01001100101 };
   localparam [width_p - 1:-fixed_bits] g_scale = { {8{1'b0}}, 11'b10010110011 };
   localparam [width_p - 1:-fixed_bits] b_scale = { {8{1'b0}}, 11'b00011101010 };
   logic [width_p - 1:-fixed_bits * 2]  gray_r;

   assign valid_o = valid_q_r;
   assign ready_o = !valid_o | (ready_i);
   assign gray_o = gray_r[7:0];

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         gray_r <= '0;
      end else begin
         if (valid_i && ready_o) begin
            gray_r <= { red_i, 11'b0 } * r_scale + { green_i, 11'b0 } * g_scale + { blue_i, 11'b0 } * b_scale;
         end
      end
   end

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         valid_q_r <= '0;
      end else begin
         valid_q_r <= valid_d;
      end
   end

   always_comb begin
      valid_d = valid_i | (~ready_o & valid_q_r);
   end

   wire _unused_ok = 1'b0 && &{ 1'b0, gray_r[-1:-22] };
endmodule
