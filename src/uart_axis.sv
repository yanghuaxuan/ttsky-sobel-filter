module uart_axis
  #(parameter example_p = 0
   ,parameter linewidth_px_p = 16) // Does nothing, just an example. You may use it, extend it, or ignore it.
  (input [0:0] clk_i // 25 MHz Clock
  ,input [0:0] reset_i

  ,input [0:0] rx_serial_i
  ,output [0:0] tx_serial_o


  ,output [5:1] led_o // For debugging
   );


   localparam [31:0] data_width_lp = 8; // Keep this constant. Treat UART as an 8-bit bus, output.
   localparam        sobel_out_width_lp = (data_width_lp * 2) * 2; // sobel streams gx and gy, totaling to 4 bytes
   localparam        data_widened_lp = 24; // r, g, b
   localparam        data_to_narrow_lp = sobel_out_width_lp;
   localparam        data_narrowed_lp = 8;

   // In my soltion, these wires are data coming from (tx), and going
   // to (rx) the UART module. You may pick your own alternate naming
   // scheme.
   localparam int BAUD = 115200;
   localparam [15:0] prescale  =  25000000 / (BAUD * 8);
   // localparam [15:0] prescale  =  27;

   wire [data_width_lp-1:0] m_axis_uart_tdata;
   wire       m_axis_uart_tvalid;
   // wire       m_axis_uart_tready;

   // wire [data_width_lp-1:0] s_axis_uart_tdata;
   // wire       s_axis_uart_tvalid;
   wire       s_axis_uart_tready;

   wire [data_widened_lp-1:0] m_axis_widener_tdata;
   // wire [data_width_lp-1:0] s_axis_widener_tdata;
   wire       m_axis_widener_tvalid;
   wire       m_axis_widener_tkeep;
   wire       s_axis_widener_tready;

   wire [data_width_lp-1:0] m_axis_narrower_tdata;
   wire       m_axis_narrower_tvalid;
   wire       s_axis_narrower_tready;

   wire       fifo_ready_o;
   wire       fifo_valid_o;
   wire [sobel_out_width_lp - 1:0] fifo_data_o;

   wire                       rgb_ready_o;
   wire                       rgb_valid_o;
   wire [data_width_lp - 1:0] rgb_gray_o;

   wire [sobel_out_width_lp - 1:0] sobel_data_o;
   wire       sobel_valid_o;
   wire       sobel_ready_o;
   
   logic [5:1] led_r = '0;

   // debug LEDs
   assign led_o = led_r;
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         led_r[5:1] <= '0;
      end else begin
         if (m_axis_widener_tdata == {8'h03, 8'h20, 8'h06, 8'h12}) begin
            led_r[5:1] <= '1;
         end
         if (m_axis_widener_tdata == {8'hee, 8'hff, 8'hc0, 8'hc0}) begin
            led_r[5:1] <= '0;
         end
      end
   end

   uart #(.DATA_WIDTH(data_width_lp))
   uart_inst1 (
                        // Outputs
                        .s_axis_tready  (s_axis_uart_tready),
                        .m_axis_tdata   (m_axis_uart_tdata),
                        .m_axis_tvalid  (m_axis_uart_tvalid),
                        .txd            (tx_serial_o),
                        .tx_busy        (),
                        .rx_busy        (),
                        .rx_overrun_error(),
                        .rx_frame_error (),
                        // Inputs
                        .clk            (clk_i),
                        .rst            (reset_i),
                        // .s_axis_tdata   (m_axis_uart_tdata),
                        // .s_axis_tvalid  (s_axis_uart_tvalid),
                        // .m_axis_tready  (m_axis_uart_tready),
                        .s_axis_tdata(m_axis_narrower_tdata),
                        .s_axis_tvalid(m_axis_narrower_tvalid),
                        .m_axis_tready  (s_axis_widener_tready),
                        .rxd            (rx_serial_i),
                        .prescale       (prescale));

   // widener
    axis_adapter
     #(// Parameters
       .S_DATA_WIDTH                    (data_width_lp), // data_width_lp bits from serial
       .M_DATA_WIDTH                    (data_widened_lp),
       .S_KEEP_ENABLE                   (0),
       .M_KEEP_ENABLE                   (1),
       .M_KEEP_WIDTH                    (data_widened_lp / data_width_lp),
       .ID_ENABLE                       (0),
       .DEST_ENABLE                     (0),
       .USER_ENABLE                     (0))
   adapter_widener (
                    // Outputs
                    .s_axis_tready      (s_axis_widener_tready),
                    .m_axis_tdata       (m_axis_widener_tdata),
                    .m_axis_tkeep       (m_axis_widener_tkeep),
                    .m_axis_tvalid      (m_axis_widener_tvalid),
                    // .s_axis_tlast       (0),
                    // Inputs
                    .clk                (clk_i),
                    .rst                (reset_i),
                    .s_axis_tdata       (m_axis_uart_tdata),
                    .s_axis_tkeep       ('0),
                    .s_axis_tvalid      (m_axis_uart_tvalid),
                    .s_axis_tlast       ('0),
                    .m_axis_tready      (rgb_ready_o));

   // rgb2gray
   rgb2gray #()
     rgb_inst
       (
        // Outputs
        .ready_o                        (rgb_ready_o),
        .valid_o                        (rgb_valid_o),
        .gray_o                         (rgb_gray_o),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .valid_i                        (m_axis_widener_tvalid),
        .red_i                          (m_axis_widener_tdata[7:0]),
        .blue_i                         (m_axis_widener_tdata[23:16]),
        .green_i                        (m_axis_widener_tdata[15:8]),
        .ready_i                        (sobel_ready_o));

   // sobel
   sobel #(.linewidth_px_p(linewidth_px_p))
    sobel_inst
      (
       // Outputs
       .ready_o                         (sobel_ready_o),
       .valid_o                         (sobel_valid_o),
       .data_o                          (sobel_data_o),
       // Inputs
       .clk_i                           (clk_i),
       .reset_i                         (reset_i),
       .valid_i                         (rgb_valid_o),
       .data_i                          (rgb_gray_o),
       .ready_i                         (fifo_ready_o));

   // narrower takes its sweet time to TX back + uart & adapter does not respect ready_i; put FIFO here
   fifo_1r1w #(.width_p(sobel_out_width_lp), .depth_log2_p(8))
     fifo_inst
       (
        // Outputs
        .ready_o                        (fifo_ready_o),
        .valid_o                        (fifo_valid_o),
        .data_o                         (fifo_data_o),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .data_i                         (sobel_data_o),
        .valid_i                        (sobel_valid_o),
        .ready_i                        (s_axis_narrower_tready));


   // narrower
    axis_adapter
     #(
                    .S_DATA_WIDTH                    (data_to_narrow_lp),
                    .M_DATA_WIDTH                    (data_narrowed_lp),
                    .S_KEEP_ENABLE                   (1),
                    .S_KEEP_WIDTH                    (data_to_narrow_lp / data_width_lp),
                    .M_KEEP_ENABLE                   (0),
                    .ID_ENABLE                       (0),
                    .DEST_ENABLE                     (0),
                    .USER_ENABLE                     (0))
       adapater_narrower (
                    // Outputs
                    .s_axis_tready      (s_axis_narrower_tready),
                    .m_axis_tdata       (m_axis_narrower_tdata),
                    // .m_axis_tkeep       (),
                    .m_axis_tvalid      (m_axis_narrower_tvalid),
                    // .s_axis_tlast       (0),
                    // Inputs
                    .clk                (clk_i),
                    .rst                (reset_i),
                    .s_axis_tdata       (fifo_data_o),
                    .s_axis_tkeep       ('1),
                    .s_axis_tvalid      (fifo_valid_o),
                    .s_axis_tlast       ('0),
                    // .m_axis_tready      (sobel_ready_o));
                    .m_axis_tready      (s_axis_uart_tready));
   
endmodule

