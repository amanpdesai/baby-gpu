module work_scheduler_formal (
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

  (* anyseq *) logic reset;
  (* anyseq *) logic launch_valid;
  logic launch_ready;
  (* anyseq *) logic [COORD_PORT_W-1:0] launch_grid_x;
  (* anyseq *) logic [COORD_PORT_W-1:0] launch_grid_y;
  (* anyseq *) logic [ADDR_PORT_W-1:0] launch_arg_base;

  logic core_launch_valid;
  (* anyseq *) logic core_launch_ready;
  logic [LANES_PORT_W-1:0] core_launch_active_mask;
  logic [COORD_PAYLOAD_W-1:0] core_launch_global_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_global_id_y;
  logic [COORD_PAYLOAD_W-1:0] core_launch_local_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_local_id_y;
  logic [COORD_PAYLOAD_W-1:0] core_launch_group_id_x;
  logic [COORD_PAYLOAD_W-1:0] core_launch_group_id_y;
  logic [DATA_PAYLOAD_W-1:0] core_launch_linear_global_id;
  logic [ADDR_PORT_W-1:0] core_launch_arg_base;
  (* anyseq *) logic core_done;
  (* anyseq *) logic core_error;

  logic busy;
  logic done;
  logic error;
  logic past_valid;

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
    past_valid = 1'b0;
    assume(reset);
  end

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;

    if (!past_valid) begin
      assume(reset);
    end

    if (past_valid && !$past(reset)) begin
      assume(!reset);
    end

    if (launch_valid) begin
      assume(launch_grid_x != '0);
      assume(launch_grid_y != '0);
      assume(launch_grid_x <= COORD_PORT_W'(3));
      assume(launch_grid_y <= COORD_PORT_W'(3));
    end

    if (past_valid && !$past(reset) && $past(launch_valid && !launch_ready)) begin
      assume(launch_valid);
      assume(launch_grid_x == $past(launch_grid_x));
      assume(launch_grid_y == $past(launch_grid_y));
      assume(launch_arg_base == $past(launch_arg_base));
    end

    if (past_valid && reset) begin
      assert(!core_launch_valid);
    end

    if (past_valid && !reset) begin
      assert(!launch_ready || (!busy && !done && !error));
      assert(!(busy && launch_valid && launch_ready));

      if ($past(error) && !$past(reset)) begin
        assert(error);
        assert(!busy);
        assert(!done);
        assert(!launch_ready);
        assert(!core_launch_valid);
      end

      if ($past(core_launch_valid && !core_launch_ready) && !$past(reset)) begin
        assert(core_launch_valid);
        assert(core_launch_active_mask == $past(core_launch_active_mask));
        assert(core_launch_global_id_x == $past(core_launch_global_id_x));
        assert(core_launch_global_id_y == $past(core_launch_global_id_y));
        assert(core_launch_local_id_x == $past(core_launch_local_id_x));
        assert(core_launch_local_id_y == $past(core_launch_local_id_y));
        assert(core_launch_group_id_x == $past(core_launch_group_id_x));
        assert(core_launch_group_id_y == $past(core_launch_group_id_y));
        assert(core_launch_linear_global_id == $past(core_launch_linear_global_id));
        assert(core_launch_arg_base == $past(core_launch_arg_base));
      end

      if (core_launch_valid) begin
        assert(core_launch_active_mask != '0);
      end
    end

    cover(past_valid && !reset && launch_valid && launch_ready);
    cover(past_valid && !reset && core_launch_valid && !core_launch_ready);
    cover(past_valid && !reset && core_launch_valid && (core_launch_active_mask != '0));
    cover(past_valid && !reset && error && !busy && !done && !launch_ready && !core_launch_valid);
  end
endmodule
