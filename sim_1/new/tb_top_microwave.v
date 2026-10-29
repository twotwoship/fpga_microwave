`timescale 1ns / 1ps

module tb_top_microwave;
  parameter SEC = 64'd1_000_000; // 실제 시뮬레이션 조절 1초설정
  reg clk = 0, reset = 1; reg s1 = 0, s2 = 0, key = 0;
  reg open_btn = 0, close_btn = 0, cancel_btn = 0;
  wire servo, buzzer, pwm_motor; wire [1:0] in1_in2; wire [3:0] an;
  wire [7:0] seg;
  top_microwave dut(
    .clk(clk), .reset(reset), .s1(s1), .s2(s2), .key(key),
    .open_btn(open_btn), .close_btn(close_btn), .cancel_btn(cancel_btn),
    .servo(servo), .buzzer(buzzer), .pwm_motor(pwm_motor),
    .in1_in2(in1_in2), .an(an), .seg(seg)
  );
  // 시뮬레이션 타임 설정. 
  defparam dut.u_btn_debouncer.ROTARY_DEBOUNCE_TIME = 2;
  defparam dut.u_btn_debouncer.KEY_DEBOUNCE_TIME = 3;
  defparam dut.u_timer.CLK_HZ = SEC / 10;
  defparam dut.u_main_fsm.CLK_HZ = SEC / 10;
  defparam dut.u_fnd_control.CLK_HZ = SEC / 10;
  defparam dut.u_servo_control.CLK_HZ = 100_000_0;
  defparam dut.u_buzzer_control.SIM_DIV = 1_000_000_000 / SEC;
  always #5 clk = ~clk; // 100MHz

  initial begin
    #100; reset = 0; // CLOSING
    #SEC;           // 닫힘 대기 후 SET_TIME
    // 로타리 10칸: 10초 설정
    repeat (10) begin
      {s1, s2} = 2'b10; #100; {s1, s2} = 2'b11; #100;
      {s1, s2} = 2'b01; #100; {s1, s2} = 2'b00; #100;
    end
    key = 1; #100; key = 0; // RUN
    #(3*SEC);
    key = 1; #100; key = 0; // PAUSE
    #SEC;
    key = 1; #100; key = 0; // RUN 재개
    #(7*SEC);               // 남은 7초가 끝나면 DONE
    #(3*SEC + 1000);        // 종료 점멸 후 SET_TIME
    open_btn = 1; #100; open_btn = 0; // DOOR_OPEN
    #SEC;
    close_btn = 1; #100; close_btn = 0; // CLOSING
    #SEC;                                 // SET_TIME
    $finish;
  end
endmodule
