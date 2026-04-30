module work_scheduler #(
    parameter int LANES = 4,
    parameter int COORD_W = 16,
    parameter int DATA_W = 32,
    parameter int ADDR_W = 32,
    localparam int LANES_PORT_W = (LANES < 1) ? 1 : LANES,
    localparam int COORD_PORT_W = (COORD_W < 1) ? 1 : COORD_W,
    localparam int DATA_PORT_W = (DATA_W < 1) ? 1 : DATA_W,
    localparam int ADDR_PORT_W = (ADDR_W < 1) ? 1 : ADDR_W,
    localparam int TOTAL_CALC_W = COORD_PORT_W * 2,
    localparam int TOTAL_PORT_W = (TOTAL_CALC_W > DATA_PORT_W) ? TOTAL_CALC_W : DATA_PORT_W
) (
    input logic clk,
    input logic reset,

    input logic launch_valid,
    output logic launch_ready,
    input logic [COORD_PORT_W-1:0] launch_grid_x,
    input logic [COORD_PORT_W-1:0] launch_grid_y,
    input logic [ADDR_PORT_W-1:0] launch_arg_base,

    output logic core_launch_valid,
    input logic core_launch_ready,
    output logic [LANES_PORT_W-1:0] core_launch_active_mask,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_global_id_x,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_global_id_y,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_local_id_x,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_local_id_y,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_group_id_x,
    output logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_group_id_y,
    output logic [(LANES_PORT_W*DATA_PORT_W)-1:0] core_launch_linear_global_id,
    output logic [ADDR_PORT_W-1:0] core_launch_arg_base,

    input logic core_done,
    input logic core_error,

    output logic busy,
    output logic done,
    output logic error
);
  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_ISSUE,
    STATE_WAIT_GROUP,
    STATE_DONE,
    STATE_ERROR
  } state_t;

  state_t state;

  logic [COORD_PORT_W-1:0] grid_x_q;
  logic [COORD_PORT_W-1:0] grid_y_q;
  logic [ADDR_PORT_W-1:0] arg_base_q;
  logic [TOTAL_PORT_W-1:0] total_items_q;
  logic [TOTAL_PORT_W-1:0] current_linear_q;
  logic [TOTAL_PORT_W-1:0] launch_total_items_ext;
  logic [TOTAL_CALC_W-1:0] launch_total_items;
  logic launch_accept;
  logic launch_zero_grid;
  logic launch_total_unsupported;
  logic launch_invalid;
  logic group_accept;
  logic [TOTAL_PORT_W-1:0] next_group_linear;
  logic [COORD_PORT_W-1:0] safe_grid_x;

  assign launch_accept = launch_valid && launch_ready;
  assign group_accept = core_launch_valid && core_launch_ready;
  assign launch_zero_grid = (launch_grid_x == '0) || (launch_grid_y == '0);
  assign launch_total_items = launch_grid_x * launch_grid_y;
  assign launch_total_items_ext = {{(TOTAL_PORT_W-TOTAL_CALC_W){1'b0}}, launch_total_items};
  assign launch_invalid = launch_zero_grid || launch_total_unsupported;
  assign next_group_linear = current_linear_q + TOTAL_PORT_W'(LANES_PORT_W);
  assign safe_grid_x = (grid_x_q == '0) ? COORD_PORT_W'(1) : grid_x_q;

  if (TOTAL_CALC_W > DATA_PORT_W) begin : gen_total_overflow_check
    assign launch_total_unsupported = |launch_total_items[TOTAL_CALC_W-1:DATA_PORT_W];
  end else begin : gen_no_total_overflow_check
    assign launch_total_unsupported = 1'b0;
  end

  assign launch_ready = (state == STATE_IDLE);
  assign core_launch_valid = (state == STATE_ISSUE);
  assign core_launch_arg_base = arg_base_q;
  assign busy = (state == STATE_ISSUE) || (state == STATE_WAIT_GROUP);
  assign done = (state == STATE_DONE);
  assign error = (state == STATE_ERROR);

  for (genvar lane = 0; lane < LANES_PORT_W; lane = lane + 1) begin : gen_lane_payload
    logic [TOTAL_PORT_W-1:0] lane_linear;
    logic [TOTAL_PORT_W-1:0] lane_global_x;
    logic [TOTAL_PORT_W-1:0] lane_global_y;
    logic [TOTAL_PORT_W-1:0] lane_local_x;
    logic [TOTAL_PORT_W-1:0] lane_group_x;

    assign lane_linear = current_linear_q + TOTAL_PORT_W'(lane);
    assign lane_global_x = lane_linear % TOTAL_PORT_W'(safe_grid_x);
    assign lane_global_y = lane_linear / TOTAL_PORT_W'(safe_grid_x);
    assign lane_local_x = lane_global_x % TOTAL_PORT_W'(LANES_PORT_W);
    assign lane_group_x = lane_global_x / TOTAL_PORT_W'(LANES_PORT_W);

    assign core_launch_active_mask[lane] = lane_linear < total_items_q;
    assign core_launch_global_id_x[(lane*COORD_PORT_W)+:COORD_PORT_W] =
        lane_global_x[COORD_PORT_W-1:0];
    assign core_launch_global_id_y[(lane*COORD_PORT_W)+:COORD_PORT_W] =
        lane_global_y[COORD_PORT_W-1:0];
    assign core_launch_local_id_x[(lane*COORD_PORT_W)+:COORD_PORT_W] =
        lane_local_x[COORD_PORT_W-1:0];
    assign core_launch_local_id_y[(lane*COORD_PORT_W)+:COORD_PORT_W] = '0;
    assign core_launch_group_id_x[(lane*COORD_PORT_W)+:COORD_PORT_W] =
        lane_group_x[COORD_PORT_W-1:0];
    assign core_launch_group_id_y[(lane*COORD_PORT_W)+:COORD_PORT_W] =
        lane_global_y[COORD_PORT_W-1:0];
    assign core_launch_linear_global_id[(lane*DATA_PORT_W)+:DATA_PORT_W] =
        lane_linear[DATA_PORT_W-1:0];
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
      grid_x_q <= '0;
      grid_y_q <= '0;
      arg_base_q <= '0;
      total_items_q <= '0;
      current_linear_q <= '0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (launch_accept) begin
            grid_x_q <= launch_grid_x;
            grid_y_q <= launch_grid_y;
            arg_base_q <= launch_arg_base;
            total_items_q <= launch_total_items_ext;
            current_linear_q <= '0;
            if (launch_invalid) begin
              state <= STATE_ERROR;
            end else begin
              state <= STATE_ISSUE;
            end
          end
        end
        STATE_ISSUE: begin
          if (group_accept) begin
            state <= STATE_WAIT_GROUP;
          end
        end
        STATE_WAIT_GROUP: begin
          if (core_error) begin
            state <= STATE_ERROR;
          end else if (core_done) begin
            if (next_group_linear >= total_items_q) begin
              state <= STATE_DONE;
            end else begin
              current_linear_q <= next_group_linear;
              state <= STATE_ISSUE;
            end
          end
        end
        STATE_DONE: begin
          state <= STATE_IDLE;
        end
        STATE_ERROR: begin
          state <= STATE_ERROR;
        end
        default: begin
          state <= STATE_ERROR;
        end
      endcase
    end
  end

  initial begin
    if (LANES < 1) begin
      $fatal(1, "work_scheduler requires LANES >= 1");
    end
    if (COORD_W < 1) begin
      $fatal(1, "work_scheduler requires COORD_W >= 1");
    end
    if (DATA_W < 1) begin
      $fatal(1, "work_scheduler requires DATA_W >= 1");
    end
    if (ADDR_W < 1) begin
      $fatal(1, "work_scheduler requires ADDR_W >= 1");
    end
  end
endmodule
