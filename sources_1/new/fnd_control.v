`timescale 1ns / 1ps

// Basys3의 an[3:0], seg[7:0]은 0일 때 켜짐.
// 세그먼트 순서: seg[7]=소수점, seg[6:0]={g,f,e,d,c,b,a}.
// display_time: 이진수 총 초, 최대 99분 59초로 제한.
// display_mode: 00=시간, 01=시간/회전 교대, 10=0000, 11=소등.
module fnd_control #(
  parameter integer CLK_HZ = 100_000_000
)(
  input clk,
  input reset,
  input [15:0] display_time,
  input [1:0] display_mode,
  output reg [3:0] an,
  output reg [7:0] seg
);
  localparam integer SCAN_LIMIT = CLK_HZ / 1000; // 자리당 1ms
  localparam integer ANIM_LIMIT = CLK_HZ / 10; // 회전 단계당 100ms

  reg [31:0] r_scan_cnt;
  reg [1:0] r_sel;
  reg [31:0] r_anim_cnt;
  reg [3:0] r_anim_step;
  reg r_show_animation;
  reg [1:0] r_prev_mode;

  wire [15:0] w_total_seconds;
  wire [6:0] w_minutes;
  wire [5:0] w_seconds;
  wire [3:0] w_min_tens, w_min_ones;
  wire [3:0] w_sec_tens, w_sec_ones;

  assign w_total_seconds = (display_time > 16'd5999)
    ? 16'd5999 : display_time;
  assign w_minutes = w_total_seconds / 16'd60;
  assign w_seconds = w_total_seconds % 16'd60;
  assign w_min_tens = w_minutes / 7'd10;
  assign w_min_ones = w_minutes % 7'd10;
  assign w_sec_tens = w_seconds / 6'd10;
  assign w_sec_ones = w_seconds % 6'd10;

  reg [3:0] digit;
  reg [3:0] scan_an;
  reg [7:0] scan_seg;

  function [7:0] decode_digit;
    input [3:0] value;
    begin
      case (value)
        4'd0: decode_digit = 8'hC0;
        4'd1: decode_digit = 8'hF9;
        4'd2: decode_digit = 8'hA4;
        4'd3: decode_digit = 8'hB0;
        4'd4: decode_digit = 8'h99;
        4'd5: decode_digit = 8'h92;
        4'd6: decode_digit = 8'h82;
        4'd7: decode_digit = 8'hF8;
        4'd8: decode_digit = 8'h80;
        4'd9: decode_digit = 8'h90;
        default: decode_digit = 8'hFF;
      endcase
    end
  endfunction

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_scan_cnt <= 0;
      r_sel <= 0;
    end else begin
      if (r_scan_cnt >= SCAN_LIMIT - 1) begin
        r_scan_cnt <= 0;
        r_sel <= r_sel + 1'b1;
      end else begin
        r_scan_cnt <= r_scan_cnt + 1'b1;
      end
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_anim_cnt <= 0;
      r_anim_step <= 0;
      r_show_animation <= 1'b0;
      r_prev_mode <= 2'b00;
    end else begin
      r_prev_mode <= display_mode;

      if (display_mode != 2'b01 || r_prev_mode != 2'b01) begin
        r_anim_cnt <= 0;
        r_anim_step <= 0;
        r_show_animation <= 1'b0;
      end else if (r_anim_cnt >= ANIM_LIMIT - 1) begin
        r_anim_cnt <= 0;
        if (r_anim_step == 4'd11) begin
          r_anim_step <= 0;
          r_show_animation <= ~r_show_animation;
        end else begin
          r_anim_step <= r_anim_step + 1'b1;
        end
      end else begin
        r_anim_cnt <= r_anim_cnt + 1'b1;
      end
    end
  end

  always @(*) begin
    digit = 4'd0;
    scan_an = 4'b1111;
    case (r_sel)
      2'd0: begin digit = w_sec_ones; scan_an = 4'b1110; end
      2'd1: begin digit = w_sec_tens; scan_an = 4'b1101; end
      2'd2: begin digit = w_min_ones; scan_an = 4'b1011; end
      2'd3: begin digit = w_min_tens; scan_an = 4'b0111; end
    endcase

    scan_seg = decode_digit(digit);
    if (r_sel == 2'd2)
      scan_seg[7] = 1'b0;
  end

  always @(*) begin
    an = 4'b1111;
    seg = 8'hFF;

    if (!reset && r_scan_cnt != 0) begin
      case (display_mode)
        2'b00: begin
          an = scan_an;
          seg = scan_seg;
        end

        2'b01: begin
          if (!r_show_animation) begin
            an = scan_an;
            seg = scan_seg;
          end else begin
            case (r_anim_step)
              4'd0: begin an = 4'b1110; seg = 8'hFE; end
              4'd1: begin an = 4'b1101; seg = 8'hFE; end
              4'd2: begin an = 4'b1011; seg = 8'hFE; end
              4'd3: begin an = 4'b0111; seg = 8'hFE; end
              4'd4: begin an = 4'b0111; seg = 8'hDF; end
              4'd5: begin an = 4'b0111; seg = 8'hEF; end
              4'd6: begin an = 4'b0111; seg = 8'hF7; end
              4'd7: begin an = 4'b1011; seg = 8'hF7; end
              4'd8: begin an = 4'b1101; seg = 8'hF7; end
              4'd9: begin an = 4'b1110; seg = 8'hF7; end
              4'd10: begin an = 4'b1110; seg = 8'hFB; end
              4'd11: begin an = 4'b1110; seg = 8'hFD; end
              default: begin an = 4'b1111; seg = 8'hFF; end
            endcase
          end
        end
        2'b10: begin
          an = scan_an;
          seg = 8'hC0;
        end

        2'b11: begin
          an = 4'b1111;
          seg = 8'hFF;
        end
        default: begin an = 4'b1111; seg = 8'hFF; end
      endcase
    end
  end

endmodule
