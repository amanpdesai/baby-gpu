module tb_work_scheduler;
  localparam int LANES = 4;
  localparam int COORD_W = 8;
  localparam int DATA_W = 16;
  localparam int ADDR_W = 16;
  localparam int SMALL_LANES = 2;
  localparam int SMALL_COORD_W = 4;
  localparam int SMALL_DATA_W = 4;
  localparam int SMALL_ADDR_W = 8;

  logic clk;
  logic reset;
  logic launch_valid;
  logic launch_ready;
  logic [COORD_W-1:0] launch_grid_x;
  logic [COORD_W-1:0] launch_grid_y;
  logic [ADDR_W-1:0] launch_arg_base;
  logic core_launch_valid;
  logic core_launch_ready;
  logic [LANES-1:0] core_launch_active_mask;
  logic [(LANES*COORD_W)-1:0] core_launch_global_id_x;
  logic [(LANES*COORD_W)-1:0] core_launch_global_id_y;
  logic [(LANES*COORD_W)-1:0] core_launch_local_id_x;
  logic [(LANES*COORD_W)-1:0] core_launch_local_id_y;
  logic [(LANES*COORD_W)-1:0] core_launch_group_id_x;
  logic [(LANES*COORD_W)-1:0] core_launch_group_id_y;
  logic [(LANES*DATA_W)-1:0] core_launch_linear_global_id;
  logic [ADDR_W-1:0] core_launch_arg_base;
  logic core_done;
  logic core_error;
  logic busy;
  logic done;
  logic error;

  logic small_launch_valid;
  logic small_launch_ready;
  logic [SMALL_COORD_W-1:0] small_launch_grid_x;
  logic [SMALL_COORD_W-1:0] small_launch_grid_y;
  logic [SMALL_ADDR_W-1:0] small_launch_arg_base;
  logic small_core_launch_valid;
  logic small_core_launch_ready;
  logic [SMALL_LANES-1:0] small_core_launch_active_mask;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_global_id_x;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_global_id_y;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_local_id_x;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_local_id_y;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_group_id_x;
  logic [(SMALL_LANES*SMALL_COORD_W)-1:0] small_core_launch_group_id_y;
  logic [(SMALL_LANES*SMALL_DATA_W)-1:0] small_core_launch_linear_global_id;
  logic [SMALL_ADDR_W-1:0] small_core_launch_arg_base;
  logic small_core_done;
  logic small_core_error;
  logic small_busy;
  logic small_done;
  logic small_error;

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

  work_scheduler #(
      .LANES(SMALL_LANES),
      .COORD_W(SMALL_COORD_W),
      .DATA_W(SMALL_DATA_W),
      .ADDR_W(SMALL_ADDR_W)
  ) overflow_dut (
      .clk(clk),
      .reset(reset),
      .launch_valid(small_launch_valid),
      .launch_ready(small_launch_ready),
      .launch_grid_x(small_launch_grid_x),
      .launch_grid_y(small_launch_grid_y),
      .launch_arg_base(small_launch_arg_base),
      .core_launch_valid(small_core_launch_valid),
      .core_launch_ready(small_core_launch_ready),
      .core_launch_active_mask(small_core_launch_active_mask),
      .core_launch_global_id_x(small_core_launch_global_id_x),
      .core_launch_global_id_y(small_core_launch_global_id_y),
      .core_launch_local_id_x(small_core_launch_local_id_x),
      .core_launch_local_id_y(small_core_launch_local_id_y),
      .core_launch_group_id_x(small_core_launch_group_id_x),
      .core_launch_group_id_y(small_core_launch_group_id_y),
      .core_launch_linear_global_id(small_core_launch_linear_global_id),
      .core_launch_arg_base(small_core_launch_arg_base),
      .core_done(small_core_done),
      .core_error(small_core_error),
      .busy(small_busy),
      .done(small_done),
      .error(small_error)
  );

  always #5 clk = ~clk;

  task automatic step;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $fatal(1, "%s", message);
      end
    end
  endtask

  function automatic [COORD_W-1:0] coord_lane(
      input logic [(LANES*COORD_W)-1:0] bus,
      input int lane
  );
    begin
      coord_lane = bus[(lane*COORD_W)+:COORD_W];
    end
  endfunction

  function automatic [DATA_W-1:0] data_lane(
      input logic [(LANES*DATA_W)-1:0] bus,
      input int lane
  );
    begin
      data_lane = bus[(lane*DATA_W)+:DATA_W];
    end
  endfunction

  task automatic clear_inputs;
    begin
      launch_valid = 1'b0;
      launch_grid_x = '0;
      launch_grid_y = '0;
      launch_arg_base = '0;
      core_launch_ready = 1'b0;
      core_done = 1'b0;
      core_error = 1'b0;

      small_launch_valid = 1'b0;
      small_launch_grid_x = '0;
      small_launch_grid_y = '0;
      small_launch_arg_base = '0;
      small_core_launch_ready = 1'b0;
      small_core_done = 1'b0;
      small_core_error = 1'b0;
    end
  endtask

  task automatic reset_duts;
    begin
      clear_inputs();
      reset = 1'b1;
      step();
      reset = 1'b0;
      step();
      check(launch_ready && !busy && !done && !error, "main scheduler resets idle");
      check(small_launch_ready && !small_busy && !small_done && !small_error,
            "overflow scheduler resets idle");
    end
  endtask

  task automatic launch_main(
      input logic [COORD_W-1:0] grid_x,
      input logic [COORD_W-1:0] grid_y,
      input logic [ADDR_W-1:0] arg_base
  );
    begin
      launch_grid_x = grid_x;
      launch_grid_y = grid_y;
      launch_arg_base = arg_base;
      launch_valid = 1'b1;
      #1;
      check(launch_ready, "valid launch can be accepted while idle");
      step();
      launch_valid = 1'b0;
      #1;
    end
  endtask

  task automatic expect_group_header(
      input logic [LANES-1:0] expected_mask,
      input logic [ADDR_W-1:0] expected_arg_base
  );
    begin
      check(core_launch_valid, "core launch valid asserted");
      check(busy, "scheduler busy while issuing a group");
      check(core_launch_active_mask == expected_mask, "active mask matches");
      check(core_launch_arg_base == expected_arg_base, "arg base is latched into launch payload");
    end
  endtask

  task automatic expect_lane(
      input int lane,
      input int expected_x,
      input int expected_y,
      input int expected_linear
  );
    begin
      check(coord_lane(core_launch_global_id_x, lane) == COORD_W'(expected_x),
            "global_id_x lane mismatch");
      check(coord_lane(core_launch_global_id_y, lane) == COORD_W'(expected_y),
            "global_id_y lane mismatch");
      check(data_lane(core_launch_linear_global_id, lane) == DATA_W'(expected_linear),
            "linear_global_id lane mismatch");
    end
  endtask

  task automatic accept_group;
    begin
      check(core_launch_valid, "group is available for accept");
      core_launch_ready = 1'b1;
      step();
      core_launch_ready = 1'b0;
      check(!core_launch_valid && busy, "scheduler waits for core completion after accept");
    end
  endtask

  task automatic finish_group;
    begin
      core_done = 1'b1;
      step();
      core_done = 1'b0;
      #1;
    end
  endtask

  task automatic finish_kernel_after_last_group;
    begin
      finish_group();
      check(done && !busy && !error, "scheduler pulses done after final group");
      step();
      check(launch_ready && !done && !busy && !error, "scheduler returns idle after done");
    end
  endtask

  task automatic test_exact_multiple;
    begin
      reset_duts();
      launch_main(8'd8, 8'd1, 16'h1234);

      expect_group_header(4'b1111, 16'h1234);
      expect_lane(0, 0, 0, 0);
      expect_lane(1, 1, 0, 1);
      expect_lane(2, 2, 0, 2);
      expect_lane(3, 3, 0, 3);
      accept_group();
      finish_group();

      expect_group_header(4'b1111, 16'h1234);
      expect_lane(0, 4, 0, 4);
      expect_lane(1, 5, 0, 5);
      expect_lane(2, 6, 0, 6);
      expect_lane(3, 7, 0, 7);
      accept_group();
      finish_kernel_after_last_group();
    end
  endtask

  task automatic test_tail_mask;
    begin
      reset_duts();
      launch_main(8'd6, 8'd1, 16'h2000);

      expect_group_header(4'b1111, 16'h2000);
      accept_group();
      finish_group();

      expect_group_header(4'b0011, 16'h2000);
      expect_lane(0, 4, 0, 4);
      expect_lane(1, 5, 0, 5);
      accept_group();
      finish_kernel_after_last_group();
    end
  endtask

  task automatic test_2d_mapping;
    begin
      reset_duts();
      launch_main(8'd3, 8'd2, 16'h3333);

      expect_group_header(4'b1111, 16'h3333);
      expect_lane(0, 0, 0, 0);
      expect_lane(1, 1, 0, 1);
      expect_lane(2, 2, 0, 2);
      expect_lane(3, 0, 1, 3);
      check(coord_lane(core_launch_local_id_x, 0) == 8'd0, "local_id_x lane 0");
      check(coord_lane(core_launch_local_id_x, 1) == 8'd1, "local_id_x lane 1");
      check(coord_lane(core_launch_group_id_y, 3) == 8'd1, "group_id_y follows row");
      accept_group();
      finish_group();

      expect_group_header(4'b0011, 16'h3333);
      expect_lane(0, 1, 1, 4);
      expect_lane(1, 2, 1, 5);
      check(coord_lane(core_launch_group_id_x, 0) == 8'd0, "group_id_x implicit SIMD tile");
      accept_group();
      finish_kernel_after_last_group();
    end
  endtask

  task automatic test_backpressure_stability;
    logic [LANES-1:0] stable_mask;
    logic [(LANES*COORD_W)-1:0] stable_x;
    logic [(LANES*COORD_W)-1:0] stable_y;
    logic [(LANES*DATA_W)-1:0] stable_linear;
    begin
      reset_duts();
      launch_main(8'd5, 8'd1, 16'h4444);

      core_launch_ready = 1'b0;
      #1;
      expect_group_header(4'b1111, 16'h4444);
      stable_mask = core_launch_active_mask;
      stable_x = core_launch_global_id_x;
      stable_y = core_launch_global_id_y;
      stable_linear = core_launch_linear_global_id;

      step();
      check(core_launch_valid && core_launch_active_mask == stable_mask,
            "mask stable through one stalled cycle");
      check(core_launch_global_id_x == stable_x && core_launch_global_id_y == stable_y,
            "global IDs stable through one stalled cycle");
      check(core_launch_linear_global_id == stable_linear,
            "linear IDs stable through one stalled cycle");

      step();
      check(core_launch_valid && core_launch_active_mask == stable_mask,
            "mask stable through second stalled cycle");
      check(core_launch_global_id_x == stable_x && core_launch_global_id_y == stable_y,
            "global IDs stable through second stalled cycle");
      check(core_launch_linear_global_id == stable_linear,
            "linear IDs stable through second stalled cycle");

      accept_group();
      finish_group();
      expect_group_header(4'b0001, 16'h4444);
      accept_group();
      finish_kernel_after_last_group();
    end
  endtask

  task automatic test_zero_grid_error;
    begin
      reset_duts();
      launch_main(8'd0, 8'd4, 16'h5000);
      check(error && !busy && !done, "zero grid_x enters explicit error state");
      check(!launch_ready && !core_launch_valid, "error state rejects more work until reset");

      reset_duts();
      launch_main(8'd4, 8'd0, 16'h5000);
      check(error && !busy && !done, "zero grid_y enters explicit error state");
    end
  endtask

  task automatic test_unsupported_dimension_error;
    begin
      reset_duts();
      small_launch_grid_x = 4'd4;
      small_launch_grid_y = 4'd5;
      small_launch_arg_base = 8'h80;
      small_launch_valid = 1'b1;
      #1;
      check(small_launch_ready, "overflow-sized launch is accepted for explicit error");
      step();
      small_launch_valid = 1'b0;
      #1;
      check(small_error && !small_busy && !small_done,
            "linear_global_id overflow enters explicit error state");
      check(!small_core_launch_valid, "overflow launch never reaches core");
    end
  endtask

  task automatic test_launch_while_busy_rejected;
    begin
      reset_duts();
      launch_main(8'd8, 8'd1, 16'h6000);
      expect_group_header(4'b1111, 16'h6000);

      launch_grid_x = 8'd1;
      launch_grid_y = 8'd1;
      launch_arg_base = 16'hDEAD;
      launch_valid = 1'b1;
      #1;
      check(!launch_ready, "busy scheduler rejects second launch by ready deassertion");
      check(!error, "rejected busy launch does not set error");
      check(core_launch_valid && core_launch_arg_base == 16'h6000,
            "first launch payload remains active while second launch waits");
      step();
      check(!launch_ready && core_launch_arg_base == 16'h6000,
            "busy rejection persists across stalled cycle");
      launch_valid = 1'b0;
      #1;

      accept_group();
      finish_group();
      expect_group_header(4'b1111, 16'h6000);
      accept_group();
      finish_kernel_after_last_group();
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b0;
    clear_inputs();

    test_exact_multiple();
    test_tail_mask();
    test_2d_mapping();
    test_backpressure_stability();
    test_zero_grid_error();
    test_unsupported_dimension_error();
    test_launch_while_busy_rejected();

    $display("tb_work_scheduler PASS");
    $finish;
  end
endmodule
