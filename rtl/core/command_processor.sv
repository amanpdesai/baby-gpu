module command_processor #(
    parameter int WORD_W = 32,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16,
    parameter int SUPPORTED_GROUP_SIZE_X = 4,
    parameter int SUPPORTED_GROUP_SIZE_Y = 1
) (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic clear_errors,

    input logic cmd_valid,
    output logic cmd_ready,
    input logic [WORD_W-1:0] cmd_data,

    output logic clear_start,
    output logic [COLOR_W-1:0] clear_color,
    input logic clear_busy,
    input logic clear_done,

    output logic rect_start,
    output logic [COORD_W-1:0] rect_x,
    output logic [COORD_W-1:0] rect_y,
    output logic [COORD_W-1:0] rect_width,
    output logic [COORD_W-1:0] rect_height,
    output logic [COLOR_W-1:0] rect_color,
    input logic rect_busy,
    input logic rect_done,

    output logic launch_start,
    input logic launch_busy,
    input logic [WORD_W-1:0] launch_program_base,
    input logic [COORD_W-1:0] launch_grid_x,
    input logic [COORD_W-1:0] launch_grid_y,
    input logic [COORD_W-1:0] launch_group_size_x,
    input logic [COORD_W-1:0] launch_group_size_y,
    input logic [WORD_W-1:0] launch_arg_base,
    input logic [WORD_W-1:0] launch_flags,
    output logic [WORD_W-1:0] launch_program_base_latched,
    output logic [COORD_W-1:0] launch_grid_x_latched,
    output logic [COORD_W-1:0] launch_grid_y_latched,
    output logic [COORD_W-1:0] launch_group_size_x_latched,
    output logic [COORD_W-1:0] launch_group_size_y_latched,
    output logic [WORD_W-1:0] launch_arg_base_latched,
    output logic [WORD_W-1:0] launch_flags_latched,

    output logic reg_write_valid,
    output logic [WORD_W-1:0] reg_write_addr,
    output logic [WORD_W-1:0] reg_write_data,

    output logic busy,
    output logic [7:0] error_status
);
  localparam logic [7:0] OP_NOP = 8'h00;
  localparam logic [7:0] OP_CLEAR = 8'h01;
  localparam logic [7:0] OP_FILL_RECT = 8'h02;
  localparam logic [7:0] OP_WAIT_IDLE = 8'h03;
  localparam logic [7:0] OP_SET_REGISTER = 8'h10;
  localparam logic [7:0] OP_LAUNCH_KERNEL = 8'h20;

  localparam logic [7:0] ERR_UNKNOWN_OPCODE = 8'h01;
  localparam logic [7:0] ERR_BAD_WORD_COUNT = 8'h02;
  localparam logic [7:0] ERR_BAD_RESERVED = 8'h04;
  localparam logic [7:0] ERR_DISPATCH_BUSY = 8'h08;
  localparam logic [7:0] ERR_LAUNCH_INVALID = 8'h10;

  typedef enum logic [3:0] {
    STATE_IDLE,
    STATE_CLEAR_COLOR,
    STATE_CLEAR_DISPATCH,
    STATE_CLEAR_WAIT,
    STATE_RECT_XY,
    STATE_RECT_WH,
    STATE_RECT_COLOR,
    STATE_RECT_RESERVED,
    STATE_RECT_DISPATCH,
    STATE_RECT_WAIT,
    STATE_SET_REG_ADDR,
    STATE_SET_REG_DATA,
    STATE_SET_REG_PULSE,
    STATE_WAIT_IDLE,
    STATE_SKIP
  } state_e;

  state_e state;
  logic [7:0] opcode;
  logic [7:0] word_count;
  logic [7:0] skip_remaining;

  logic command_take;
  logic draw_idle;
  logic launch_config_invalid;

  assign opcode = cmd_data[31:24];
  assign word_count = cmd_data[23:16];
  assign command_take = cmd_valid && cmd_ready;
  assign draw_idle = !clear_busy && !rect_busy && !launch_busy;
  assign launch_config_invalid =
      (launch_grid_x == '0) ||
      (launch_grid_y == '0) ||
      (launch_group_size_x != COORD_W'(SUPPORTED_GROUP_SIZE_X)) ||
      (launch_group_size_y != COORD_W'(SUPPORTED_GROUP_SIZE_Y)) ||
      (launch_flags != '0);
  assign busy = (state != STATE_IDLE) || clear_busy || rect_busy || launch_busy;

  always_comb begin
    cmd_ready = 1'b0;

    case (state)
      STATE_IDLE: cmd_ready = enable;
      STATE_CLEAR_COLOR: cmd_ready = 1'b1;
      STATE_RECT_XY: cmd_ready = 1'b1;
      STATE_RECT_WH: cmd_ready = 1'b1;
      STATE_RECT_COLOR: cmd_ready = 1'b1;
      STATE_RECT_RESERVED: cmd_ready = 1'b1;
      STATE_SET_REG_ADDR: cmd_ready = 1'b1;
      STATE_SET_REG_DATA: cmd_ready = 1'b1;
      STATE_SKIP: cmd_ready = 1'b1;
      default: cmd_ready = 1'b0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
      clear_start <= 1'b0;
      clear_color <= '0;
      rect_start <= 1'b0;
      rect_x <= '0;
      rect_y <= '0;
      rect_width <= '0;
      rect_height <= '0;
      rect_color <= '0;
      launch_start <= 1'b0;
      launch_program_base_latched <= '0;
      launch_grid_x_latched <= '0;
      launch_grid_y_latched <= '0;
      launch_group_size_x_latched <= '0;
      launch_group_size_y_latched <= '0;
      launch_arg_base_latched <= '0;
      launch_flags_latched <= '0;
      reg_write_valid <= 1'b0;
      reg_write_addr <= '0;
      reg_write_data <= '0;
      error_status <= '0;
      skip_remaining <= '0;
    end else begin
      clear_start <= 1'b0;
      rect_start <= 1'b0;
      launch_start <= 1'b0;
      reg_write_valid <= 1'b0;

      if (clear_errors) begin
        error_status <= '0;
      end

      case (state)
        STATE_IDLE: begin
          if (command_take) begin
            case (opcode)
              OP_NOP: begin
                if (word_count != 8'd1) begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end
              end
              OP_CLEAR: begin
                if (word_count == 8'd2) begin
                  state <= STATE_CLEAR_COLOR;
                end else begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end
              end
              OP_FILL_RECT: begin
                if (word_count == 8'd5) begin
                  state <= STATE_RECT_XY;
                end else begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end
              end
              OP_WAIT_IDLE: begin
                if (word_count == 8'd1) begin
                  state <= draw_idle ? STATE_IDLE : STATE_WAIT_IDLE;
                end else begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end
              end
              OP_SET_REGISTER: begin
                if (word_count == 8'd3) begin
                  state <= STATE_SET_REG_ADDR;
                end else begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end
              end
              OP_LAUNCH_KERNEL: begin
                if (word_count != 8'd1) begin
                  error_status <= error_status | ERR_BAD_WORD_COUNT;
                  skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                  state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
                end else if (cmd_data[15:0] != 16'h0000) begin
                  error_status <= error_status | ERR_BAD_RESERVED;
                end else if (!draw_idle) begin
                  error_status <= error_status | ERR_DISPATCH_BUSY;
                end else if (launch_config_invalid) begin
                  error_status <= error_status | ERR_LAUNCH_INVALID;
                end else begin
                  launch_program_base_latched <= launch_program_base;
                  launch_grid_x_latched <= launch_grid_x;
                  launch_grid_y_latched <= launch_grid_y;
                  launch_group_size_x_latched <= launch_group_size_x;
                  launch_group_size_y_latched <= launch_group_size_y;
                  launch_arg_base_latched <= launch_arg_base;
                  launch_flags_latched <= launch_flags;
                  launch_start <= 1'b1;
                end
              end
              default: begin
                error_status <= error_status | ERR_UNKNOWN_OPCODE;
                skip_remaining <= word_count > 8'd1 ? word_count - 8'd1 : 8'd0;
                state <= word_count > 8'd1 ? STATE_SKIP : STATE_IDLE;
              end
            endcase
          end
        end

        STATE_CLEAR_COLOR: begin
          if (command_take) begin
            clear_color <= cmd_data[COLOR_W-1:0];
            state <= STATE_CLEAR_DISPATCH;
          end
        end

        STATE_CLEAR_DISPATCH: begin
          if (clear_busy) begin
            error_status <= error_status | ERR_DISPATCH_BUSY;
            state <= STATE_IDLE;
          end else begin
            clear_start <= 1'b1;
            state <= STATE_CLEAR_WAIT;
          end
        end

        STATE_CLEAR_WAIT: begin
          if (clear_done) begin
            state <= STATE_IDLE;
          end
        end

        STATE_RECT_XY: begin
          if (command_take) begin
            rect_x <= cmd_data[31:16];
            rect_y <= cmd_data[15:0];
            state <= STATE_RECT_WH;
          end
        end

        STATE_RECT_WH: begin
          if (command_take) begin
            rect_width <= cmd_data[31:16];
            rect_height <= cmd_data[15:0];
            state <= STATE_RECT_COLOR;
          end
        end

        STATE_RECT_COLOR: begin
          if (command_take) begin
            rect_color <= cmd_data[COLOR_W-1:0];
            state <= STATE_RECT_RESERVED;
          end
        end

        STATE_RECT_RESERVED: begin
          if (command_take) begin
            if (cmd_data != '0) begin
              error_status <= error_status | ERR_BAD_RESERVED;
            end

            state <= STATE_RECT_DISPATCH;
          end
        end

        STATE_RECT_DISPATCH: begin
          if (rect_busy) begin
            error_status <= error_status | ERR_DISPATCH_BUSY;
            state <= STATE_IDLE;
          end else begin
            rect_start <= 1'b1;
            state <= STATE_RECT_WAIT;
          end
        end

        STATE_RECT_WAIT: begin
          if (rect_done) begin
            state <= STATE_IDLE;
          end
        end

        STATE_SET_REG_ADDR: begin
          if (command_take) begin
            reg_write_addr <= cmd_data;
            state <= STATE_SET_REG_DATA;
          end
        end

        STATE_SET_REG_DATA: begin
          if (command_take) begin
            reg_write_data <= cmd_data;
            state <= STATE_SET_REG_PULSE;
          end
        end

        STATE_SET_REG_PULSE: begin
          reg_write_valid <= 1'b1;
          state <= STATE_IDLE;
        end

        STATE_WAIT_IDLE: begin
          if (draw_idle) begin
            state <= STATE_IDLE;
          end
        end

        STATE_SKIP: begin
          if (command_take) begin
            if (skip_remaining <= 8'd1) begin
              skip_remaining <= '0;
              state <= STATE_IDLE;
            end else begin
              skip_remaining <= skip_remaining - 8'd1;
            end
          end
        end

        default: begin
          state <= STATE_IDLE;
          error_status <= error_status | ERR_UNKNOWN_OPCODE;
        end
      endcase
    end
  end
endmodule
