`timescale 1ns / 1ps

// display_time은 BCD가 아닌 이진수 총 초.
// inc_dec: 00=없음, 01=1초 증가, 10=1초 감소, 11=미사용.
// 로터리 이벤트는 1클록 동안만 출력.
module timer #(
  parameter integer CLK_HZ = 100_000_000
)(
  input clk,
  input reset,
  input run,
  input set_en,
  input clear,
  input [1:0] inc_dec,
  output timeout,
  output [15:0] display_time
);

  localparam [15:0] MAX_TIME = 16'd5999; // 99분 59초
  reg [15:0] r_time;
  reg [31:0] r_clk_cnt;
  assign display_time = r_time;
  // 시간이 0이면 1을 유지하며, 리셋 직후에도 1.
  assign timeout = (r_time == 16'd0);
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_time <= 16'd0;
      r_clk_cnt <= 32'd0;
    end else if (clear || (r_time > MAX_TIME)) begin
      r_time <= 16'd0;
      r_clk_cnt <= 32'd0;
    end else if (set_en) begin
      // 1초 분주와 별개로 매 클록 로터리 이벤트 확인.
      // 시간 설정 중에는 분주 카운터를 초기화해 조리 시작 준비.
      r_clk_cnt <= 32'd0;
      case (inc_dec)
        2'b01: begin
          if (r_time < MAX_TIME)
            r_time <= r_time + 16'd1;
        end
        2'b10: begin
          if (r_time > 16'd0)
            r_time <= r_time - 16'd1;
        end
        default: ; // 이벤트 없음 또는 미사용 코드: 시간 유지.
      endcase
    end else if (run) begin
      if (r_time != 16'd0) begin
        if (r_clk_cnt >= CLK_HZ - 1) begin
          r_clk_cnt <= 32'd0;
          r_time <= r_time - 16'd1;
        end else begin
          r_clk_cnt <= r_clk_cnt + 32'd1;
        end
      end else begin
        r_clk_cnt <= 32'd0;
      end
    end
    // run=0, set_en=0이면 남은 시간과 분주 카운터를 모두 유지.
  end

endmodule
