`timescale 1ns / 1ps

// 1/1.5/2ms 펄스 폭에 따른 50Hz 서보 제어.
// 00/11: 새 명령 없이 마지막 목표 위치 유지.
// 01=열기, 10=닫기. 첫 유효 명령 전까지 PWM 출력 안 함.
// CLK_HZ는 1MHz의 양의 정수배로 설정.
// OPEN_US와 CLOSE_US는 0보다 크고 20000us보다 작게 설정.
module servo_control #(
  parameter integer CLK_HZ = 100_000_000,
  parameter integer OPEN_US = 3000, //값 조절에 따른 각변화
  parameter integer CLOSE_US = 1000
)(
  input clk,
  input reset,
  input [1:0] open_close,
  output servo
);

  localparam integer FRAME_TICKS = CLK_HZ / 50;
  localparam integer TICKS_PER_US = CLK_HZ / 1_000_000;
  localparam integer OPEN_TICKS = TICKS_PER_US * OPEN_US;
  localparam integer CLOSE_TICKS = TICKS_PER_US * CLOSE_US;

  reg [31:0] r_pwm_counter;
  reg [31:0] r_target_ticks;
  reg [31:0] r_pulse_ticks;
  reg r_enabled;

  wire w_valid_cmd;
  wire [31:0] w_requested_ticks;

  assign w_valid_cmd = (open_close == 2'b01) ||
    (open_close == 2'b10);

  assign w_requested_ticks = (open_close == 2'b01) ? OPEN_TICKS :
    (open_close == 2'b10) ? CLOSE_TICKS :
    r_target_ticks;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_pwm_counter <= 32'd0;
      r_target_ticks <= CLOSE_TICKS;
      r_pulse_ticks <= CLOSE_TICKS;
      r_enabled <= 1'b0;
    end else begin
      // 1클록 명령으로 목표를 저장하며, 00/11에서는 저장값 유지.
      if (w_valid_cmd)
        r_target_ticks <= w_requested_ticks;

      if (!r_enabled) begin
        r_pwm_counter <= 32'd0;
        if (w_valid_cmd) begin
          r_enabled <= 1'b1;
          r_pulse_ticks <= w_requested_ticks;
        end
      end else if (r_pwm_counter >= FRAME_TICKS - 1) begin
        r_pwm_counter <= 32'd0;
        // 새 목표 위치는 다음 프레임이 시작될 때 적용.
        // 출력 중인 펄스가 잘리거나 늘어나는 현상 방지.
        r_pulse_ticks <= w_requested_ticks;
      end else begin
        r_pwm_counter <= r_pwm_counter + 32'd1;
      end
    end
  end

  assign servo = (!reset && r_enabled)
    ? (r_pwm_counter < r_pulse_ticks) : 1'b0;

endmodule
