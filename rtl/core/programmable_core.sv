import isa_pkg::*;

module programmable_core #(
    parameter int LANES = 4,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int ADDR_W = 32,
    parameter int PC_W = 8,
    parameter int REGS = 16,
    parameter int REG_ADDR_W = $clog2(REGS),
    localparam int LANES_PORT_W = (LANES < 1) ? 1 : LANES,
    localparam int DATA_PORT_W = (DATA_W < ISA_IMM18_W) ? ISA_IMM18_W : DATA_W,
    localparam int COORD_PORT_W = (COORD_W < 1) ? 1 : COORD_W,
    localparam int ADDR_PORT_W = (ADDR_W < 1) ? 1 : ADDR_W,
    localparam int PC_PORT_W = (PC_W < 1) ? 1 : PC_W,
    localparam int REG_ADDR_PORT_W = (REG_ADDR_W < 1) ? 1 : REG_ADDR_W
) (
    input logic clk,
    input logic reset,

    input logic launch_valid,
    output logic launch_ready,
    input logic [COORD_PORT_W-1:0] grid_x,
    input logic [COORD_PORT_W-1:0] grid_y,
    input logic [ADDR_PORT_W-1:0] arg_base,
    input logic [ADDR_PORT_W-1:0] framebuffer_base,
    input logic [COORD_PORT_W-1:0] framebuffer_width,
    input logic [COORD_PORT_W-1:0] framebuffer_height,

    output logic [PC_PORT_W-1:0] instruction_addr,
    input logic [ISA_WORD_W-1:0] instruction,

    output logic busy,
    output logic done,
    output logic error,

    input logic [REG_ADDR_PORT_W-1:0] debug_read_addr,
    output logic [(LANES_PORT_W*DATA_PORT_W)-1:0] debug_read_data
);
  logic core_launch_valid;
  logic core_launch_ready;
  logic [LANES_PORT_W-1:0] core_launch_active_mask;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_lane_id;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_global_id_x;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_global_id_y;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_local_id_x;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_local_id_y;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_group_id_x;
  logic [(LANES_PORT_W*COORD_PORT_W)-1:0] core_launch_group_id_y;
  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] core_launch_linear_global_id;
  logic [ADDR_PORT_W-1:0] core_launch_arg_base;

  logic scheduler_busy;
  logic scheduler_done;
  logic scheduler_error;
  logic simd_busy;
  logic simd_done;
  logic simd_error;

  assign busy = scheduler_busy || simd_busy;
  assign done = scheduler_done;
  assign error = scheduler_error;

  for (genvar lane = 0; lane < LANES_PORT_W; lane = lane + 1) begin : gen_lane_id
    assign core_launch_lane_id[(lane*COORD_PORT_W)+:COORD_PORT_W] = COORD_PORT_W'(lane);
  end

  work_scheduler #(
      .LANES(LANES_PORT_W),
      .COORD_W(COORD_PORT_W),
      .DATA_W(DATA_PORT_W),
      .ADDR_W(ADDR_PORT_W)
  ) u_work_scheduler (
      .clk(clk),
      .reset(reset),
      .launch_valid(launch_valid),
      .launch_ready(launch_ready),
      .launch_grid_x(grid_x),
      .launch_grid_y(grid_y),
      .launch_arg_base(arg_base),
      .core_launch_valid(core_launch_valid),
      .core_launch_ready(core_launch_ready),
      .core_launch_active_mask(core_launch_active_mask),
      .core_launch_global_id_x(core_launch_global_id_x),
      .core_launch_global_id_y(core_launch_global_id_y),
      .core_launch_local_id_x(core_launch_local_id_x),
      .core_launch_local_id_y(core_launch_local_id_y),
      .core_launch_group_id_x(core_launch_group_id_x),
      .core_launch_group_id_y(core_launch_group_id_y),
      .core_launch_linear_global_id(core_launch_linear_global_id),
      .core_launch_arg_base(core_launch_arg_base),
      .core_done(simd_done),
      .core_error(simd_error),
      .busy(scheduler_busy),
      .done(scheduler_done),
      .error(scheduler_error)
  );

  simd_core #(
      .LANES(LANES_PORT_W),
      .DATA_W(DATA_PORT_W),
      .COORD_W(COORD_PORT_W),
      .ADDR_W(ADDR_PORT_W),
      .PC_W(PC_PORT_W),
      .REGS(REGS),
      .REG_ADDR_W(REG_ADDR_PORT_W)
  ) u_simd_core (
      .clk(clk),
      .reset(reset),
      .start(core_launch_valid && core_launch_ready),
      .launch_active_mask(core_launch_active_mask),
      .launch_ready(core_launch_ready),
      .busy(simd_busy),
      .done(simd_done),
      .error(simd_error),
      .instruction_addr(instruction_addr),
      .instruction(instruction),
      .lane_id(core_launch_lane_id),
      .global_id_x(core_launch_global_id_x),
      .global_id_y(core_launch_global_id_y),
      .linear_global_id(core_launch_linear_global_id),
      .group_id_x(core_launch_group_id_x),
      .group_id_y(core_launch_group_id_y),
      .local_id_x(core_launch_local_id_x),
      .local_id_y(core_launch_local_id_y),
      .arg_base(core_launch_arg_base),
      .framebuffer_base(framebuffer_base),
      .framebuffer_width(framebuffer_width),
      .framebuffer_height(framebuffer_height),
      .debug_read_addr(debug_read_addr),
      .debug_read_data(debug_read_data)
  );
endmodule
