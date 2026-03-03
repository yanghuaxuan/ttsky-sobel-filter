module fifo_1r1w
  #(parameter [31:0] width_p = 8
   // Note: Not depth_p! depth_p should be 1<<depth_log2_p
   ,parameter [31:0] depth_log2_p = 8
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [width_p - 1:0] data_i
  ,input [0:0] valid_i
  ,output [0:0] ready_o 

  ,output [0:0] valid_o 
  ,output [width_p - 1:0] data_o 
  ,input [0:0] ready_i
  );

   logic [depth_log2_p : 0] rd_ptr_n, rd_ptr_q, wr_ptr_n, wr_ptr_q;
   logic [depth_log2_p - 1 : 0] next_read;
   logic [depth_log2_p : 0] count_d_n, count_q_r;
   // logic [0:0]             ready_l, valid_l;

   wire [0:0]               write_en, read_en;
   wire [0:0]               is_full, is_empty;
   wire [0:0]               elastic_fwd_w;

   wire [width_p - 1:0]     mem_data_o, elastic_data_o;

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         rd_ptr_q <= '0;
         wr_ptr_q <= '0;
         count_q_r <= '0;
         // state_q_r <= IDLE;
      end else begin
         rd_ptr_q <= rd_ptr_n;
         wr_ptr_q <= wr_ptr_n;
         count_q_r <= count_d_n;
         // state_q_r <= state_d_n;
      end
   end

   assign read_en = (ready_i && valid_o);
   assign write_en = valid_i && ready_o;

   assign rd_ptr_n = (read_en) ? rd_ptr_q + 1 : rd_ptr_q;
   assign wr_ptr_n = (write_en) ? wr_ptr_q + 1 : wr_ptr_q;

   assign elastic_fwd_w =  ((rd_ptr_q == (wr_ptr_q - 1'b1)) ||
                            (rd_ptr_q == (wr_ptr_q)));

   always_comb begin
      count_d_n = count_q_r + depth_log2_p'(write_en) - depth_log2_p'(read_en);
   end

   // unfortunately, icarus sucks; need to do continuous assign
   // always_comb begin
   //    if (read_en) begin
   //       next_read = rd_ptr_q[depth_log2_p - 1:0] + 1;
   //    end else begin 
   //       next_read = rd_ptr_q[depth_log2_p - 1:0];
   //    end
   // end
   assign next_read = (read_en) ? rd_ptr_q[depth_log2_p - 1:0] + 1 : rd_ptr_q[depth_log2_p - 1:0];

   // assign is_full = count_q_r == {1'b1, {depth_log2_p{1'b0}}};
   // assign is_empty = count_q_r == 0;
   assign is_empty = wr_ptr_q == rd_ptr_q;
   assign is_full = (wr_ptr_q[depth_log2_p] != rd_ptr_q[depth_log2_p]) &&
                    (wr_ptr_q[depth_log2_p - 1:0] == rd_ptr_q[depth_log2_p - 1:0]);

   assign ready_o = ~is_full;
   assign valid_o = ~is_empty;

   ram_1r1w_sync #(.WIDTH_P(width_p), .DEPTH_P(1 << depth_log2_p), .ZERO_INIT(1))
   mem_sync (.clk_i(clk_i),
             .reset_i(reset_i),
             .wr_addr_i(wr_ptr_q[depth_log2_p - 1:0]), .wr_data_i(data_i), .wr_valid_i(write_en),
             .rd_addr_i(next_read), .rd_data_o(mem_data_o), .rd_valid_i(1'b1));

   elastic #(.width_p(width_p), .datapath_gate_p(1'b1))
               elastic_inst (.clk_i(clk_i), .reset_i(reset_i),
                             .data_i(data_i), .data_o(elastic_data_o),
                             .valid_i(write_en),  .valid_o(),
                             .ready_i(1'b1), .ready_o());

   assign data_o = (elastic_fwd_w) ? elastic_data_o : mem_data_o;

endmodule
