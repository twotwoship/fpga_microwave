`timescale 1ns / 1ps
/*
00: 새 명령 없음
01: 문 열기
10: 문 닫기
11: 종료곡
*/
module buzzer_control #(
  parameter integer SIM_DIV = 1
)(input clk, reset, input [1:0] buzzer_cmd, output reg buzzer);
  localparam NOTE_70MS = 26'd7_000_000 / SIM_DIV;
  localparam NOTE_200MS = 26'd20_000_000 / SIM_DIV;
  localparam NOTE_600MS = 26'd60_000_000 / SIM_DIV;
  reg [21:0] half_period; reg [25:0] note_limit; reg [25:0] note_cnt; reg [21:0] freq_cnt;
  reg [2:0] tone_idx; reg [1:0] mode; reg [1:0] cmd_prev; reg active;
  wire new_cmd; wire [2:0] last_tone;
  assign new_cmd = (buzzer_cmd != 2'b00) && (buzzer_cmd != cmd_prev);
  assign last_tone = (mode == 2'b11) ? 3'd7 : 3'd3;
  always @(*) begin
    half_period = 22'd50_000 / SIM_DIV; note_limit = NOTE_70MS;
    case (mode)
      2'b01: begin
        case (tone_idx)
          3'd0: half_period = 22'd50_000 / SIM_DIV; // 1kHz
          3'd1: half_period = 22'd25_000 / SIM_DIV; // 2kHz
          3'd2: half_period = 22'd16_667 / SIM_DIV; // 3kHz
          3'd3: half_period = 22'd12_500 / SIM_DIV; // 4kHz
          default: half_period = 22'd50_000 / SIM_DIV;
        endcase
      end
      2'b10: begin
        case (tone_idx)
          3'd0: half_period = 22'd191_571 / SIM_DIV;
          3'd1: half_period = 22'd151_976 / SIM_DIV;
          3'd2: half_period = 22'd127_551 / SIM_DIV;
          3'd3: half_period = 22'd90_253 / SIM_DIV;
          default: half_period = 22'd191_571 / SIM_DIV;
        endcase
      end
      2'b11: begin
        note_limit = NOTE_200MS;
        case (tone_idx)
          3'd0: half_period = 22'd191_113 / SIM_DIV;
          3'd1: half_period = 22'd151_686 / SIM_DIV;
          3'd2: half_period = 22'd127_551 / SIM_DIV;
          3'd3: half_period = 22'd95_556 / SIM_DIV;
          3'd4: half_period = 22'd127_551 / SIM_DIV;
          3'd5: half_period = 22'd151_686 / SIM_DIV;
          3'd6: half_period = 22'd170_262 / SIM_DIV;
          3'd7: begin
            half_period = 22'd191_113 / SIM_DIV;
            note_limit = NOTE_600MS;
          end
          default: half_period = 22'd191_113 / SIM_DIV;
        endcase
      end
      default: begin
        half_period = 22'd50_000 / SIM_DIV;
        note_limit = NOTE_70MS;
      end
    endcase
  end
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      note_cnt <= 26'd0; freq_cnt <= 22'd0; tone_idx <= 3'd0; mode <= 2'b00;
      cmd_prev <= 2'b00; active <= 1'b0; buzzer <= 1'b0;
    end else begin
      cmd_prev <= buzzer_cmd;
      if (new_cmd) begin
        mode <= buzzer_cmd; active <= 1'b1; tone_idx <= 3'd0;
        note_cnt <= 26'd0; freq_cnt <= 22'd0; buzzer <= 1'b0;
      end
      else if (active) begin
        if (note_cnt >= note_limit - 1'b1) begin
          note_cnt <= 26'd0; freq_cnt <= 22'd0; buzzer <= 1'b0;
          if (tone_idx == last_tone) begin
            active <= 1'b0; tone_idx <= 3'd0;
          end else begin
            tone_idx <= tone_idx + 1'b1;
          end
        end else begin
          note_cnt <= note_cnt + 1'b1;
          if (freq_cnt >= half_period - 1'b1) begin
            freq_cnt <= 22'd0; buzzer <= ~buzzer;
          end else begin
            freq_cnt <= freq_cnt + 1'b1;
          end
        end
      end
      else begin
        buzzer <= 1'b0; freq_cnt <= 22'd0; note_cnt <= 26'd0;
      end
    end
  end
endmodule