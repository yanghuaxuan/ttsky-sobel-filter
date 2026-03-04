module uart_axis
  #(parameter example_p = 0
   ,parameter linewidth_px_p = 16
   ,parameter clock_freq_mhz_p = 25
   ,parameter baud_rate_p = 115200
   )
  (input [0:0] clk_i 
  ,input [0:0] reset_i

  ,input [0:0] rx_serial_i
  ,output [0:0] tx_serial_o


  ,output [5:1] led_o // For debugging
   );


   localparam [31:0] data_width_lp = 8; // Keep this constant. Treat UART as an 8-bit bus, output.
   localparam        sobel_out_width_lp = (data_width_lp * 2) * 2; // sobel streams gx and gy, totaling to 4 bytes
   localparam        mag_in_width_lp = data_width_lp * 2;
   localparam        mag_out_width_lp = data_width_lp * 2;
   localparam        data_widened_lp = 24; // r, g, b
   localparam        data_narrowed_lp = 8;
   localparam        hsv_out_width_lp = 16;

   localparam        data_to_narrow_lp = hsv_out_width_lp;

   localparam [15:0] prescale  =  25e6 / (baud_rate_p * 8);
   // localparam [15:0] prescale  =  27;

   wire [data_width_lp-1:0] m_axis_uart_tdata_w;
   wire       m_axis_uart_tvalid_w;
   wire       s_s_axis_uart_tready_w;

   wire [data_widened_lp - 1:0] m_axis_widener_tdata_w;
   wire       m_axis_widener_tvalid_w;
   wire       s_axis_widener_tready_w;

   wire [data_narrowed_lp - 1:0] m_axis_narrower_tdata_w;
   wire       m_axis_narrower_tvalid_w;
   wire       s_axis_narrower_tready_w;

   wire       fifo_comb_killer_ready_o_w;
   wire       fifo_comb_killer_valid_o_w;
   wire [sobel_out_width_lp - 1:0] fifo_comb_killer_data_o_w;

   wire                       rgb_ready_o_w;
   wire                       rgb_valid_o_w;
   wire [data_width_lp - 1:0] rgb_gray_o_w;

   wire [sobel_out_width_lp - 1:0] sobel_data_o_w;
   wire       sobel_valid_o_w;
   wire       sobel_ready_o_w;

   wire       mag_valid_o_w;
   wire       mag_ready_o_w;
   wire [mag_out_width_lp - 1:0] mag_out_o_w;
   wire [data_width_lp * 2 - 1:0] mag_gx_o_w;
   wire [data_width_lp * 2 - 1:0] mag_gy_o_w;

   wire                          hsv_valid_o_w;
   wire                          hsv_ready_o_w;
   wire [hsv_out_width_lp - 1:0] hsv_data_o_w;

   logic [5:1] led_r = '0;

   // debug LEDs
   assign led_o = led_r;
   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         led_r[5:1] <= '0;
      end else begin
         led_r[5:1] <= '0;
         if (m_axis_uart_tvalid_w) begin
            led_r[5:1] <= 5'b1000;
         end
      end
   end

   uart #(.DATA_WIDTH(data_width_lp))
   uart_inst1 (
                        // Outputs
                        .s_axis_tready  (s_s_axis_uart_tready_w),
                        .m_axis_tdata   (m_axis_uart_tdata_w),
                        .m_axis_tvalid  (m_axis_uart_tvalid_w),
                        .txd            (tx_serial_o),
                        // Inputs
                        .clk            (clk_i),
                        .rst            (reset_i),
                        .s_axis_tdata(m_axis_narrower_tdata_w),
                        .s_axis_tvalid(m_axis_narrower_tvalid_w),
                        .m_axis_tready  (s_axis_widener_tready_w),
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
                    .s_axis_tready      (s_axis_widener_tready_w),
                    .m_axis_tdata       (m_axis_widener_tdata_w),
                    .m_axis_tkeep       (),
                    .m_axis_tvalid      (m_axis_widener_tvalid_w),
                    // Inputs
                    .clk                (clk_i),
                    .rst                (reset_i),
                    .s_axis_tdata       (m_axis_uart_tdata_w),
                    .s_axis_tkeep       ('0),
                    .s_axis_tvalid      (m_axis_uart_tvalid_w),
                    .s_axis_tlast       ('0),
                    .m_axis_tready      (rgb_ready_o_w));

   // rgb2gray
   rgb2gray #()
     rgb_inst
       (
        // Outputs
        .ready_o                        (rgb_ready_o_w),
        .valid_o                        (rgb_valid_o_w),
        .gray_o                         (rgb_gray_o_w),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .valid_i                        (m_axis_widener_tvalid_w),
        .red_i                          (m_axis_widener_tdata_w[7:0]),
        .blue_i                         (m_axis_widener_tdata_w[23:16]),
        .green_i                        (m_axis_widener_tdata_w[15:8]),
        .ready_i                        (sobel_ready_o_w));

   // sobel
   sobel #(.linewidth_px_p(linewidth_px_p))
    sobel_inst
      (
       // Outputs
       .ready_o                         (sobel_ready_o_w),
       .valid_o                         (sobel_valid_o_w),
       .data_o                          (sobel_data_o_w),
       // Inputs
       .clk_i                           (clk_i),
       .reset_i                         (reset_i),
       .valid_i                         (rgb_valid_o_w),
       .data_i                          (rgb_gray_o_w),
       .ready_i                         (fifo_comb_killer_ready_o_w));

   // was only meant to help out the narrower so the ready chain does not propagate to the widener, which does not respect ready signals; now also a hack to decouple combinational chain from sobel -> mag
   fifo_1r1w #(.width_p(sobel_out_width_lp), .depth_log2_p(8))
     fifo_comb_killer
       (
        // Outputs
        .ready_o                        (fifo_comb_killer_ready_o_w),
        .valid_o                        (fifo_comb_killer_valid_o_w),
        .data_o                         (fifo_comb_killer_data_o_w),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .data_i                         (sobel_data_o_w),
        .valid_i                        (sobel_valid_o_w),
        .ready_i                        (mag_ready_o_w));


   mag #(.width_in_p(mag_in_width_lp))
   mag_inst(
            // Outputs
            .ready_o                    (mag_ready_o_w),
            .valid_o                    (mag_valid_o_w),
            .mag_o                      (mag_out_o_w),
            .gx_o                       (mag_gx_o_w), // for hsv
            .gy_o                       (mag_gy_o_w), // for hsv
            // Inputs
            .clk_i                      (clk_i),
            .reset_i                    (reset_i),
            .valid_i                    (fifo_comb_killer_valid_o_w),
            .gx_i                       (fifo_comb_killer_data_o_w[15:0]),
            .gy_i                       (fifo_comb_killer_data_o_w[31:16]),
            .ready_i                    (hsv_ready_o_w));

   hsv #()
     hsv_inst
       (
        // Outputs
        .ready_o                        (hsv_ready_o_w),
        .valid_o                        (hsv_valid_o_w),
        .hv_o                           (hsv_data_o_w),
        // Inputs
        .clk_i                          (clk_i),
        .reset_i                        (reset_i),
        .valid_i                        (mag_valid_o_w),
        .mag_i                          (mag_out_o_w),
        .gx_i                           (mag_gx_o_w),
        .gy_i                           (mag_gy_o_w),
        .ready_i                        (s_axis_narrower_tready_w));

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
                    .s_axis_tready      (s_axis_narrower_tready_w),
                    .m_axis_tdata       (m_axis_narrower_tdata_w),
                    .m_axis_tvalid      (m_axis_narrower_tvalid_w),
                    // Inputs
                    .clk                (clk_i),
                    .rst                (reset_i),
                    .s_axis_tdata       (hsv_data_o_w),
                    .s_axis_tkeep       ('1),
                    .s_axis_tvalid      (hsv_valid_o_w),
                    .s_axis_tlast       ('0),
                    .m_axis_tready      (s_s_axis_uart_tready_w));
   
endmodule

