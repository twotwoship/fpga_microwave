`timescale 1ns / 1ps

module top_microwave(input clk, reset, s1, s2, key, open_btn, close_btn, cancel_btn,
  output servo, buzzer, pwm_motor, output [1:0] in1_in2, output [3:0] an, output [7:0] seg);
  wire w_clean_s1, w_clean_s2, w_clean_key, w_clean_open, w_clean_close, w_clean_cancel;

  btn_debouncer u_btn_debouncer(.clk(clk), .reset(reset), .s1(s1), .s2(s2), .key(key), .open_btn(open_btn),
  .close_btn(close_btn), .cancel_btn(cancel_btn), .clean_s1(w_clean_s1),
  .clean_s2(w_clean_s2), .clean_key(w_clean_key), .clean_open(w_clean_open), .clean_close(w_clean_close), .clean_cancel(w_clean_cancel));

  wire [1:0] w_inc_dec;
  rotary u_rotary(.clk(clk), .reset(reset), .clean_s1(w_clean_s1), .clean_s2(w_clean_s2), .inc_dec(w_inc_dec));

  wire w_run, w_set_en, w_clear, w_timeout; wire [15:0] w_display_time;
  timer u_timer(.clk(clk), .reset(reset), .run(w_run), .set_en(w_set_en), .clear(w_clear), .inc_dec(w_inc_dec),
  .timeout(w_timeout), .display_time(w_display_time));

  wire [1:0] w_display_mode; wire [1:0] w_open_close; wire [1:0] w_buzzer_cmd; wire [1:0] w_pwm_duty;
  main_fsm u_main_fsm(.clk(clk), .reset(reset), .clean_key(w_clean_key), .clean_open(w_clean_open),
  .clean_close(w_clean_close), .clean_cancel(w_clean_cancel),.timeout(w_timeout), .run(w_run), .set_en(w_set_en), .clear(w_clear),
  .display_mode(w_display_mode), .open_close(w_open_close), .buzzer_cmd(w_buzzer_cmd), .pwm_duty(w_pwm_duty));

  fnd_control u_fnd_control(.clk(clk), .reset(reset), .display_time(w_display_time), .display_mode(w_display_mode), .an(an), .seg(seg));
  servo_control u_servo_control(.clk(clk), .reset(reset), .open_close(w_open_close), .servo(servo));
  buzzer_control u_buzzer_control(.clk(clk), .reset(reset), .buzzer_cmd(w_buzzer_cmd), .buzzer(buzzer));
  motor_control u_motor_control(.clk(clk), .reset(reset), .pwm_duty(w_pwm_duty), .pwm_motor(pwm_motor), .in1_in2(in1_in2));

endmodule
