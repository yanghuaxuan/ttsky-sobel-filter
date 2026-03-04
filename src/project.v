/*
 * Copyright (c) 2026 Jason Yang
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_yanghuaxuan_sobel_hsv (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire rx_serial_i = ui_in[0];
   wire tx_serial_o = uo_out[0];
   wire reset_r; // Non inverted reset for internal logic

   assign reset_r = ~rst_n;
       
   uart_axis #(.linewidth_px_p(640))
     uart_axis_i
       (.clk_i                          (clk),
        .reset_i                        (reset_r),

        .rx_serial_i                    (rx_serial_i),
        .tx_serial_o                    (tx_serial_o)
        );

endmodule
