module elastic
  #(parameter [31:0] width_p = 8
    /* verilator lint_off WIDTHTRUNC */
   ,parameter [0:0] datapath_gate_p = 0
    /* verilator lint_off WIDTHTRUNC */
   ,parameter [0:0] datapath_reset_p = 0
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

   enum logic [0:0] { IDLE='0, IHVD=1'b1 } state_d_n, state_q_r;
   logic [width_p - 1 : 0] data_d_n, data_q_r;
   logic [0:0]             ready_l, valid_l;

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         state_q_r <= IDLE;
      end else begin
         state_q_r <= state_d_n;
      end

      if (datapath_reset_p && reset_i) begin
         data_q_r <= '0;
      end else if (ready_o && (!datapath_gate_p || valid_i)) begin
         data_q_r <= data_d_n;
      end
   end

   assign data_o = data_q_r;
   // assign data_o = data_d_n;
   assign ready_o = ready_l;
   assign valid_o = valid_l;

   assign data_d_n = data_i;

   always_comb begin
      ready_l = '0;
      valid_l = '0;
      state_d_n = IDLE;

      case (state_q_r)
        IDLE: begin
           ready_l = 1'b1;
           valid_l = 1'b0;
           if (valid_i) state_d_n = IHVD;
           else state_d_n = IDLE;
        end
        IHVD : begin
           valid_l = 1'b1;
           ready_l = '0;

           if (ready_i) begin
              ready_l = 1'b1;
           end

           if (valid_i==1'b1 || ready_i=='0) state_d_n = IHVD;
           else state_d_n = IDLE;
        end
      endcase
   end

endmodule
