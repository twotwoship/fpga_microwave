`timescale 1ns / 1ps

// 리셋과 취소는 시간을 초기화하고 문 닫힘 대기로 진입.
// 닫기 명령 후 CLOSING에서 기다린 뒤 SET_TIME으로 전이.
// 버튼 입력은 디바운스된 레벨이며, 극성 파라미터로 눌림 값을 지정.
// 문이 닫힌 상태에서 닫기 버튼을 누르면 저속/중속/고속 순환.
module main_fsm #(
  parameter integer CLK_HZ = 100_000_000,
  parameter integer CLOSE_WAIT_MS = 500,
  parameter integer DONE_HALF_MS = 500,
  parameter [0:0] KEY_ACTIVE_LOW = 1'b0,
  parameter [0:0] OPEN_ACTIVE_LOW = 1'b0,
  parameter [0:0] CLOSE_ACTIVE_LOW = 1'b0,
  parameter [0:0] CANCEL_ACTIVE_LOW = 1'b0
)(
  input clk, reset,
  input clean_key, clean_open, clean_close, clean_cancel,
  input timeout,
  output reg run, set_en, clear,
  output reg [1:0] display_mode,
  output reg [1:0] open_close,
  output reg [1:0] buzzer_cmd,
  output reg [1:0] pwm_duty
);

  // CLK_HZ는 1000의 양의 배수, 대기 시간은 1ms 이상으로 설정.
  localparam integer CLOSE_TICKS = (CLK_HZ / 1000) * CLOSE_WAIT_MS;
  localparam integer HALF_TICKS = (CLK_HZ / 1000) * DONE_HALF_MS;

  localparam [2:0] SET_TIME = 3'd0,
    RUN = 3'd1,
    PAUSE = 3'd2,
    DOOR_OPEN = 3'd3,
    CLOSING = 3'd4,
    DONE = 3'd5;

  reg [2:0] r_state, next_state;
  reg [3:0] r_prev_buttons;
  reg r_inputs_ready;
  reg [31:0] r_close_count;
  reg [31:0] r_half_count;
  reg [2:0] r_done_phase;
  reg [1:0] r_speed;

  wire [3:0] w_pressed;
  wire w_key_p, w_open_p, w_close_p, w_cancel_p;
  wire w_close_elapsed, w_done_elapsed;
  reg [1:0] sound_event;
  reg [1:0] r_pending_sound;

  assign w_pressed = {
    clean_cancel ^ CANCEL_ACTIVE_LOW,
    clean_close ^ CLOSE_ACTIVE_LOW,
    clean_open ^ OPEN_ACTIVE_LOW,
    clean_key ^ KEY_ACTIVE_LOW
  };
  assign w_key_p = r_inputs_ready && w_pressed[0] && !r_prev_buttons[0];
  assign w_open_p = r_inputs_ready && w_pressed[1] && !r_prev_buttons[1];
  assign w_close_p = r_inputs_ready && w_pressed[2] && !r_prev_buttons[2];
  assign w_cancel_p = r_inputs_ready && w_pressed[3] && !r_prev_buttons[3];

  assign w_close_elapsed = (r_close_count >= CLOSE_TICKS - 1);
  assign w_done_elapsed = (r_done_phase == 3'd5) &&
    (r_half_count >= HALF_TICKS - 1);

  // 버튼의 초기 상태를 저장한 뒤 눌림 에지 검출.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_prev_buttons <= 4'b0000;
      r_inputs_ready <= 1'b0;
    end else begin
      r_prev_buttons <= w_pressed;
      r_inputs_ready <= 1'b1;
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset)
      r_state <= CLOSING;
    else
      r_state <= next_state;
  end

  // 우선순위: 리셋 > 취소 > 문 열기 > 상태별 조건.
  always @(*) begin
    next_state = r_state;
    if (w_cancel_p) begin
      next_state = CLOSING;
    end else if (w_open_p) begin
      next_state = DOOR_OPEN;
    end else begin
      case (r_state)
        SET_TIME, PAUSE: begin
          if (w_key_p && !timeout)
            next_state = RUN;
        end
        RUN: begin
          if (timeout)
            next_state = DONE;
          else if (w_key_p)
            next_state = PAUSE;
        end
        DOOR_OPEN: begin
          if (w_close_p)
            next_state = CLOSING;
        end
        CLOSING: begin
          if (w_close_elapsed)
            next_state = SET_TIME;
        end
        DONE: begin
          if (w_done_elapsed)
            next_state = SET_TIME;
        end
        default: next_state = CLOSING;
      endcase
    end
  end

  // CLOSING 중에도 취소하면 닫힘 대기 시간을 처음부터 다시 측정.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_close_count <= 32'd0;
    end else if (r_state != CLOSING || w_cancel_p || w_open_p) begin
      r_close_count <= 32'd0;
    end else if (!w_close_elapsed) begin
      r_close_count <= r_close_count + 32'd1;
    end
  end

  // 0 표시와 소등을 번갈아 3회 반복(총 6구간).
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_half_count <= 32'd0;
      r_done_phase <= 3'd0;
    end else if (r_state != DONE || w_cancel_p || w_open_p) begin
      r_half_count <= 32'd0;
      r_done_phase <= 3'd0;
    end else if (r_half_count >= HALF_TICKS - 1) begin
      r_half_count <= 32'd0;
      if (r_done_phase < 3'd5)
        r_done_phase <= r_done_phase + 3'd1;
    end else begin
      r_half_count <= r_half_count + 32'd1;
    end
  end

  // 초기 속도는 중속이며, 문이 닫힌 상태에서만 닫기 버튼으로 속도 변경.
  // 취소는 선택 속도를 유지하고, 리셋은 중속으로 초기화.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_speed <= 2'b10;
    end else if (w_close_p && !w_cancel_p && !w_open_p &&
      ((r_state == SET_TIME) || (r_state == PAUSE) ||
      ((r_state == RUN) && !timeout))) begin
      case (r_speed)
        2'b01: r_speed <= 2'b10;
        2'b10: r_speed <= 2'b11;
        2'b11: r_speed <= 2'b01;
        default: r_speed <= 2'b10;
      endcase
    end
  end

  always @(*) begin
    run = 1'b0;
    set_en = 1'b0;
    clear = reset || w_cancel_p;
    display_mode = 2'b00;
    open_close = 2'b00;
    pwm_duty = 2'b00;

    if (!reset) begin
      case (r_state)
        SET_TIME: set_en = !w_cancel_p && !w_open_p;
        RUN: begin
          // 상태가 갱신되기 전에도 버튼/시간 종료 조건으로 즉시 정지.
          run = !timeout && !w_cancel_p && !w_open_p && !w_key_p;
          pwm_duty = run ? r_speed : 2'b00;
          display_mode = 2'b01;
        end
        DOOR_OPEN: open_close = 2'b01;
        CLOSING: open_close = 2'b10;
        DONE: display_mode = r_done_phase[0] ? 2'b11 : 2'b10;
        default: ;
      endcase

      // 명령 출력에도 상태 전이와 같은 우선순위 적용.
      if (w_cancel_p)
        open_close = 2'b10;
      else if (w_open_p)
        open_close = 2'b01;
    end
  end

  // 현재 부저에는 일반 버튼음 전용 명령이 없어 열기음을 재사용.
  // 01=일반 버튼/취소/열기, 10=문 닫기, 11=종료곡.
  always @(*) begin
    sound_event = 2'b00;
    if (w_cancel_p)
      sound_event = 2'b01;
    else if (w_open_p)
      sound_event = 2'b01;
    else if (r_state != DONE && next_state == DONE)
      sound_event = 2'b11;
    else if (w_close_p)
      sound_event = (r_state == DOOR_OPEN) ? 2'b10 : 2'b01;
    else if (w_key_p)
      sound_event = 2'b01;
  end

  // 명령은 1클록 출력하고, 명령 사이에 반드시 00 삽입.
  // 연속 이벤트는 1개를 대기 저장하며, 가득 차면 최신 이벤트 우선.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      buzzer_cmd <= 2'b00;
      r_pending_sound <= 2'b00;
    end else begin
      buzzer_cmd <= 2'b00;
      if (buzzer_cmd != 2'b00) begin
        if (sound_event != 2'b00)
          r_pending_sound <= sound_event;
      end else if (sound_event != 2'b00) begin
        buzzer_cmd <= sound_event;
        r_pending_sound <= 2'b00;
      end else if (r_pending_sound != 2'b00) begin
        buzzer_cmd <= r_pending_sound;
        r_pending_sound <= 2'b00;
      end
    end
  end

endmodule
