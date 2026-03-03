module top
  (input         clk
  ,input         rst_n
  ,input  [7:0]  ui_in
  ,output [7:0]  uo_out
  ,inout  [7:0]  uio
  );

   wire rx_serial_i = ui_in[0];
   wire tx_serial_o = uo_out[0];
   logic reset_r; // Non inverted reset for internal logic

   assign reset_r = ~rst_n;
       
   uart_axis #(.linewidth_px_p(640))
     uart_axis_i
       (.clk_i                          (clk),
        .reset_i                        (reset_r),

        .rx_serial_i                    (rx_serial_i),
        .tx_serial_o                    (tx_serial_o)
        );

endmodule
