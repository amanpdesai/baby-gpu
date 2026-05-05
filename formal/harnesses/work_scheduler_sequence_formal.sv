module work_scheduler_sequence_formal (
    input logic clk
);
  localparam int LANES = 4;
  localparam int COORD_W = 3;
  localparam int DATA_W = 8;
  localparam int ADDR_W = 8;
  localparam int LANES_PORT_W = LANES;
  localparam int COORD_PORT_W = COORD_W;
  localparam int DATA_PORT_W = DATA_W;
  localparam int ADDR_PORT_W = ADDR_W;
  localparam int COORD_PAYLOAD_W = LANES_PORT_W * COORD_PORT_W;
  localparam int DATA_PAYLOAD_W = LANES_PORT_W * DATA_PORT_W;

  logic reset;
  logic launch_valid;
  logic launch_ready;
  logic [COORD_PORT_W-1:0] launch_grid_x;
  logic [COORD_PORT_W-1:0] launch_grid_y;
  logic [ADDR_PORT_W-1:0] launch_arg_base;

  logic core_launch_valid;
  logic core_launch_ready;
  logic [LANES_PORT_W-1:0] core_launch_active_mask;
  logic [COORD_PAYLOAD_W-1:0] core_launch_global_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_global_id_y;
  logic [COORD_PAYLOAD_W-1:0] core_launch_local_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_local_id_y;
  logic [COORD_PAYLOAD_W-1:0] core_launch_group_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_group_id_y;
  logic [DATA_PAYLOAD_W-1:0] core_launch_linear_global_id;
  logic [ADDR_PORT_W-1:0] core_launch_arg_base;
  logic core_done;
  logic core_error;
  logic busy;
  logic done;
  logic error;
  logic [3:0] cycle_q;
  logic past_valid;

  function automatic logic [COORD_PORT_W-1:0] coord_lane(
      input logic [COORD_PAYLOAD_W-1:0] payload,
      input int unsigned lane_idx
  );
    coord_lane = payload[(lane_idx*COORD_PORT_W)+:COORD_PORT_W];
  endfunction

  function automatic logic [DATA_PORT_W-1:0] data_lane(
      input logic [DATA_PAYLOAD_W-1:0] payload,
      input int unsigned lane_idx
  );
    data_lane = payload[(lane_idx*DATA_PORT_W)+:DATA_PORT_W];
  endfunction

  work_scheduler #(
      .LANES(LANES),
      .COORD_W(COORD_W),
      .DATA_W(DATA_W),
      .ADDR_W(ADDR_W)
  ) dut (
      .clk(clk),
      .reset(reset),
      .launch_valid(launch_valid),
      .launch_ready(launch_ready),
      .launch_grid_x(launch_grid_x),
      .launch_grid_y(launch_grid_y),
      .launch_arg_base(launch_arg_base),
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
      .core_done(core_done),
      .core_error(core_error),
      .busy(busy),
      .done(done),
      .error(error)
  );

  initial begin
    cycle_q = '0;
    past_valid = 1'b0;
  end

  always_comb begin
    reset = (cycle_q == 4'd0);
    launch_valid = (cycle_q == 4'd1);
    launch_grid_x = 3'd3;
    launch_grid_y = 3'd3;
    launch_arg_base = 8'h44;
    core_launch_ready = (cycle_q != 4'd2);
    core_done = (cycle_q == 4'd4) || (cycle_q == 4'd6) || (cycle_q == 4'd8);
    core_error = 1'b0;
  end

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;
    cycle_q <= cycle_q + 4'd1;

    if (past_valid && $past(reset)) begin
      assert(launch_ready);
      assert(!busy);
      assert(!done);
      assert(!error);
      assert(!core_launch_valid);
    end

    if (past_valid && (cycle_q == 4'd2 || cycle_q == 4'd3)) begin
      assert(core_launch_valid);
      assert(busy);
      assert(core_launch_arg_base == 8'h44);
      assert(core_launch_active_mask == 4'b1111);
      assert(data_lane(core_launch_linear_global_id, 0) == 8'd0);
      assert(data_lane(core_launch_linear_global_id, 1) == 8'd1);
      assert(data_lane(core_launch_linear_global_id, 2) == 8'd2);
      assert(data_lane(core_launch_linear_global_id, 3) == 8'd3);
      assert(coord_lane(core_launch_global_id_x, 0) == 3'd0);
      assert(coord_lane(core_launch_global_id_x, 1) == 3'd1);
      assert(coord_lane(core_launch_global_id_x, 2) == 3'd2);
      assert(coord_lane(core_launch_global_id_x, 3) == 3'd0);
      assert(coord_lane(core_launch_global_id_y, 0) == 3'd0);
      assert(coord_lane(core_launch_global_id_y, 1) == 3'd0);
      assert(coord_lane(core_launch_global_id_y, 2) == 3'd0);
      assert(coord_lane(core_launch_global_id_y, 3) == 3'd1);
    end

    if (past_valid && (cycle_q == 4'd5)) begin
      assert(core_launch_valid);
      assert(core_launch_active_mask == 4'b1111);
      assert(data_lane(core_launch_linear_global_id, 0) == 8'd4);
      assert(data_lane(core_launch_linear_global_id, 1) == 8'd5);
      assert(data_lane(core_launch_linear_global_id, 2) == 8'd6);
      assert(data_lane(core_launch_linear_global_id, 3) == 8'd7);
      assert(coord_lane(core_launch_global_id_x, 0) == 3'd1);
      assert(coord_lane(core_launch_global_id_x, 1) == 3'd2);
      assert(coord_lane(core_launch_global_id_x, 2) == 3'd0);
      assert(coord_lane(core_launch_global_id_x, 3) == 3'd1);
      assert(coord_lane(core_launch_global_id_y, 0) == 3'd1);
      assert(coord_lane(core_launch_global_id_y, 1) == 3'd1);
      assert(coord_lane(core_launch_global_id_y, 2) == 3'd2);
      assert(coord_lane(core_launch_global_id_y, 3) == 3'd2);
    end

    if (past_valid && (cycle_q == 4'd7)) begin
      assert(core_launch_valid);
      assert(core_launch_active_mask == 4'b0001);
      assert(data_lane(core_launch_linear_global_id, 0) == 8'd8);
      assert(coord_lane(core_launch_global_id_x, 0) == 3'd2);
      assert(coord_lane(core_launch_global_id_y, 0) == 3'd2);
      assert(coord_lane(core_launch_local_id_x, 0) == 3'd2);
      assert(coord_lane(core_launch_local_id_y, 0) == 3'd0);
      assert(coord_lane(core_launch_group_id_x, 0) == 3'd0);
      assert(coord_lane(core_launch_group_id_y, 0) == 3'd2);
    end

    if (past_valid && (cycle_q == 4'd9)) begin
      assert(done);
      assert(!busy);
      assert(!error);
      assert(!core_launch_valid);
    end

    if (past_valid && (cycle_q == 4'd10)) begin
      assert(launch_ready);
      assert(!busy);
      assert(!done);
      assert(!error);
      assert(!core_launch_valid);
    end

    cover(past_valid && (cycle_q == 4'd7) && core_launch_valid &&
          (core_launch_active_mask == 4'b0001));
    cover(past_valid && (cycle_q == 4'd10) && launch_ready && !busy && !done && !error);
  end
endmodule
