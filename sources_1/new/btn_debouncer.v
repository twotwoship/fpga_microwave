`timescale 1ns / 1ps

module btn_debouncer#( parameter ROTARY_DEBOUNCE_TIME = 200_000, parameter KEY_DEBOUNCE_TIME = 1_000_000)
  (input clk, reset, s1, s2, key, open_btn, close_btn, cancel_btn,
  output clean_s1, clean_s2, clean_key, clean_open, clean_close, clean_cancel);

  debouncer #(.DEBOUNCE_LIMIT(ROTARY_DEBOUNCE_TIME))u_s1_debouncer(.clk(clk), .reset(reset), .noisy_btn(s1), .clean_btn(clean_s1));
  debouncer #(.DEBOUNCE_LIMIT(ROTARY_DEBOUNCE_TIME))u_s2_debouncer(.clk(clk), .reset(reset), .noisy_btn(s2), .clean_btn(clean_s2));
  debouncer #(.DEBOUNCE_LIMIT(KEY_DEBOUNCE_TIME))u_key_debouncer(.clk(clk), .reset(reset), .noisy_btn(key), .clean_btn(clean_key));
  debouncer #(.DEBOUNCE_LIMIT(KEY_DEBOUNCE_TIME))u_open_btn_debouncer(.clk(clk), .reset(reset), .noisy_btn(open_btn), .clean_btn(clean_open));
  debouncer #(.DEBOUNCE_LIMIT(KEY_DEBOUNCE_TIME))u_close_btn_debouncer(.clk(clk), .reset(reset), .noisy_btn(close_btn), .clean_btn(clean_close));
  debouncer #(.DEBOUNCE_LIMIT(KEY_DEBOUNCE_TIME))u_cancel_btn_debouncer(.clk(clk), .reset(reset), .noisy_btn(cancel_btn), .clean_btn(clean_cancel));

endmodule
// 입력이 설정된 시간 동안 유지되면 안정된 버튼 레벨로 출력.
module debouncer #(parameter DEBOUNCE_LIMIT = 20'd999_999) (
  input clk,
  input reset,
  input noisy_btn, // 채터링이 포함된 버튼 입력
  output reg clean_btn
);
  reg [19:0] r_count;
  reg r_btn_state=0;

  always @(posedge clk or posedge reset) begin
    if (reset) begin // 1일 때 초기화
      r_count <= 0;
      r_btn_state <= 0;
      clean_btn <= 0;
    end else if (noisy_btn == r_btn_state) begin // 입력이 기존 상태와 같으면 카운터 초기화
      r_count <= 0;
    end else begin
      if (r_count < DEBOUNCE_LIMIT) // 변경된 입력이 유지된 시간 측정
        r_count <= r_count + 1;
      else begin // 설정한 시간 동안 유지되면 출력 갱신
        r_btn_state <= noisy_btn;
        clean_btn <= noisy_btn;
        r_count <= 0; // 다음 입력 변경을 위해 카운터 초기화
      end
    end
  end
endmodule
