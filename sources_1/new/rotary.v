`timescale 1ns / 1ps

module rotary( input clk, reset, clean_s1, clean_s2, output [1:0] inc_dec);
  reg [1:0] r_direction; reg [1:0] r_prev_state; reg signed [3:0] r_step; reg r_initialized;
  assign inc_dec = r_direction;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_direction <= 2'b00; r_prev_state <= 2'b00; r_step <= 4'sd0; r_initialized <= 1'b0;
    end else begin
      r_direction <= 2'b00;
      r_prev_state <= {clean_s1, clean_s2};
      if (!r_initialized) begin
        r_initialized <= 1'b1;
        r_step <= 4'sd0;
      end else begin
        case ({r_prev_state, clean_s1, clean_s2})
          4'b0010, 4'b1011,4'b1101, 4'b0100: begin
            if (r_step == 4'sd3) begin
              r_step <= 4'sd0; r_direction <= 2'b01;
            end else begin
              r_step <= r_step + 4'sd1;
            end
          end
          4'b0001, 4'b0111, 4'b1110, 4'b1000: begin
            if (r_step == -4'sd3) begin
              r_step <= 4'sd0; r_direction <= 2'b10;
            end else begin
              r_step <= r_step - 4'sd1;
            end
          end
          default: begin
            if (r_prev_state != {clean_s1, clean_s2})
              r_step <= 4'sd0;
          end
        endcase
      end
    end
  end
endmodule
