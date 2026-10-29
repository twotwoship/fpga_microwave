`timescale 1ns / 1ps
// pwm_duty: 00=정지, 01=25%, 10=80%, 11=100%.
// DIRECTION: 10=정방향, 01=역방향
module motor_control #(
  parameter integer CLK_HZ = 100_000_000,
  parameter integer PWM_HZ = 20_000,
  parameter [1:0] DIRECTION = 2'b10
)(
  input clk,
  input reset,
  input [1:0] pwm_duty,
  output pwm_motor,
  output [1:0] in1_in2
);

  localparam integer PWM_PERIOD = CLK_HZ / PWM_HZ;

  reg [31:0] r_pwm_counter;
  reg [31:0] duty_count;

  always @(*) begin
    case (pwm_duty)
      2'b00: duty_count = 0;
      2'b01: duty_count = PWM_PERIOD / 4;
      2'b10: duty_count = (PWM_PERIOD / 5)*4;
      2'b11: duty_count = PWM_PERIOD;
      default: duty_count = 0;
    endcase
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_pwm_counter <= 32'd0;
    end else if (pwm_duty == 2'b00) begin
      r_pwm_counter <= 32'd0;
    end else if (r_pwm_counter >= PWM_PERIOD - 1) begin
      r_pwm_counter <= 32'd0;
    end else begin
      r_pwm_counter <= r_pwm_counter + 32'd1;
    end
  end

  assign pwm_motor = (!reset && pwm_duty != 2'b00)
    ? (r_pwm_counter < duty_count) : 1'b0;

  assign in1_in2 = (!reset && pwm_duty != 2'b00)
    ? DIRECTION : 2'b00;

endmodule
