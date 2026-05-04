module tb_command_processor;
  logic clk;
  logic reset;
  logic enable;
  logic clear_errors;
  logic cmd_valid;
  logic cmd_ready;
  logic [31:0] cmd_data;
  logic clear_start;
  logic [15:0] clear_color;
  logic clear_busy;
  logic clear_done;
  logic rect_start;
  logic [15:0] rect_x;
  logic [15:0] rect_y;
  logic [15:0] rect_width;
  logic [15:0] rect_height;
  logic [15:0] rect_color;
  logic rect_busy;
  logic rect_done;
  logic launch_start;
  logic launch_busy;
  logic [31:0] launch_program_base;
  logic [15:0] launch_grid_x;
  logic [15:0] launch_grid_y;
  logic [15:0] launch_group_size_x;
  logic [15:0] launch_group_size_y;
  logic [31:0] launch_arg_base;
  logic [31:0] launch_flags;
  logic [31:0] launch_program_base_latched;
  logic [15:0] launch_grid_x_latched;
  logic [15:0] launch_grid_y_latched;
  logic [15:0] launch_group_size_x_latched;
  logic [15:0] launch_group_size_y_latched;
  logic [31:0] launch_arg_base_latched;
  logic [31:0] launch_flags_latched;
  logic reg_write_valid;
  logic [31:0] reg_write_addr;
  logic [31:0] reg_write_data;
  logic busy;
  logic [7:0] error_status;

  command_processor dut (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .clear_errors(clear_errors),
      .cmd_valid(cmd_valid),
      .cmd_ready(cmd_ready),
      .cmd_data(cmd_data),
      .clear_start(clear_start),
      .clear_color(clear_color),
      .clear_busy(clear_busy),
      .clear_done(clear_done),
      .rect_start(rect_start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
      .rect_busy(rect_busy),
      .rect_done(rect_done),
      .launch_start(launch_start),
      .launch_busy(launch_busy),
      .launch_program_base(launch_program_base),
      .launch_grid_x(launch_grid_x),
      .launch_grid_y(launch_grid_y),
      .launch_group_size_x(launch_group_size_x),
      .launch_group_size_y(launch_group_size_y),
      .launch_arg_base(launch_arg_base),
      .launch_flags(launch_flags),
      .launch_program_base_latched(launch_program_base_latched),
      .launch_grid_x_latched(launch_grid_x_latched),
      .launch_grid_y_latched(launch_grid_y_latched),
      .launch_group_size_x_latched(launch_group_size_x_latched),
      .launch_group_size_y_latched(launch_group_size_y_latched),
      .launch_arg_base_latched(launch_arg_base_latched),
      .launch_flags_latched(launch_flags_latched),
      .reg_write_valid(reg_write_valid),
      .reg_write_addr(reg_write_addr),
      .reg_write_data(reg_write_data),
      .busy(busy),
      .error_status(error_status)
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

  task automatic send_word(input logic [31:0] word);
    begin
      cmd_data = word;
      cmd_valid = 1'b1;
      while (!cmd_ready) begin
        step();
      end
      step();
      cmd_valid = 1'b0;
      cmd_data = '0;
    end
  endtask

  task automatic clear_error_status;
    begin
      clear_errors = 1'b1;
      step();
      clear_errors = 1'b0;
      check(error_status == 8'h00, "clear_errors clears sticky command errors");
    end
  endtask

  task automatic restore_valid_launch_config;
    begin
      launch_grid_x = 16'd8;
      launch_grid_y = 16'd2;
      launch_group_size_x = 16'd4;
      launch_group_size_y = 16'd1;
      launch_flags = 32'h0000_0000;
    end
  endtask

  task automatic expect_invalid_launch(input string message);
    begin
      send_word(32'h2001_0000);
      check(!launch_start, message);
      check(error_status[4], "invalid launch config sets launch-invalid error");
      clear_error_status();
      restore_valid_launch_config();
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    enable = 1'b1;
    clear_errors = 1'b0;
    cmd_valid = 1'b0;
    cmd_data = '0;
    clear_busy = 1'b0;
    clear_done = 1'b0;
    rect_busy = 1'b0;
    rect_done = 1'b0;
    launch_busy = 1'b0;
    launch_program_base = 32'h0000_0020;
    launch_grid_x = 16'd8;
    launch_grid_y = 16'd2;
    launch_group_size_x = 16'd4;
    launch_group_size_y = 16'd1;
    launch_arg_base = 32'h0000_0100;
    launch_flags = 32'h0000_0000;

    step();
    reset = 1'b0;
    step();

    send_word(32'h0102_0000);
    check(busy, "CLEAR header enters busy state");
    cmd_data = 32'h0000_1357;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "CLEAR color word can dispatch when engine is idle");
    step();
    cmd_valid = 1'b0;
    step();
    check(clear_start && clear_color == 16'h1357, "CLEAR dispatches color");
    step();
    check(busy, "processor waits for clear completion");
    clear_done = 1'b1;
    step();
    clear_done = 1'b0;
    check(!busy, "processor returns idle after clear_done");

    send_word(32'h0205_0000);
    send_word({16'd3, 16'd4});
    send_word({16'd5, 16'd6});
    send_word(32'h0000_BEEF);
    cmd_data = 32'h0000_0000;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "RECT reserved word can dispatch when engine is idle");
    step();
    cmd_valid = 1'b0;
    step();
    check(rect_start, "RECT dispatches start");
    check(rect_x == 16'd3 && rect_y == 16'd4, "RECT captures origin");
    check(rect_width == 16'd5 && rect_height == 16'd6, "RECT captures size");
    check(rect_color == 16'hBEEF, "RECT captures color");
    rect_done = 1'b1;
    step();
    rect_done = 1'b0;
    check(!busy, "processor returns idle after rect_done");

    send_word(32'h1003_0000);
    send_word(32'h0000_0010);
    cmd_data = 32'h0000_0001;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "SET_REGISTER data word accepted");
    step();
    cmd_valid = 1'b0;
    step();
    check(reg_write_valid, "SET_REGISTER emits register write");
    check(reg_write_addr == 32'h0000_0010, "SET_REGISTER captures address");
    check(reg_write_data == 32'h0000_0001, "SET_REGISTER captures data");

    send_word(32'h2001_0000);
    check(launch_start, "LAUNCH_KERNEL emits one-cycle start");
    check(launch_program_base_latched == 32'h0000_0020, "LAUNCH_KERNEL latches program base");
    check(launch_grid_x_latched == 16'd8, "LAUNCH_KERNEL latches grid x");
    check(launch_grid_y_latched == 16'd2, "LAUNCH_KERNEL latches grid y");
    check(launch_group_size_x_latched == 16'd4, "LAUNCH_KERNEL latches group size x");
    check(launch_group_size_y_latched == 16'd1, "LAUNCH_KERNEL latches group size y");
    check(launch_arg_base_latched == 32'h0000_0100, "LAUNCH_KERNEL latches arg base");
    check(launch_flags_latched == 32'h0000_0000, "LAUNCH_KERNEL latches launch flags");
    check(error_status == 8'h00, "valid LAUNCH_KERNEL leaves errors clear");
    step();
    check(!launch_start, "LAUNCH_KERNEL start pulse clears after one cycle");

    launch_busy = 1'b1;
    cmd_data = 32'h0301_0000;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "WAIT_IDLE accepts while launch path is busy");
    step();

    cmd_data = 32'h1003_0000;
    repeat (3) begin
      #1;
      check(!cmd_ready, "WAIT_IDLE blocks following command while launch path is busy");
      check(!reg_write_valid, "WAIT_IDLE emits no register write while blocked");
      step();
    end

    launch_busy = 1'b0;
    step();
    #1;
    check(!reg_write_valid, "WAIT_IDLE drain edge emits no register write");
    check(cmd_ready, "command after WAIT_IDLE is accepted after launch path idles");
    step();

    cmd_data = 32'h0000_0054;
    #1;
    check(cmd_ready, "SET_REGISTER address after WAIT_IDLE accepted");
    step();

    cmd_data = 32'h0000_0240;
    #1;
    check(cmd_ready, "SET_REGISTER data after WAIT_IDLE accepted");
    step();
    cmd_valid = 1'b0;
    step();
    check(reg_write_valid, "SET_REGISTER behind WAIT_IDLE retires after launch path idles");
    check(reg_write_addr == 32'h0000_0054, "WAIT_IDLE preserves queued register address");
    check(reg_write_data == 32'h0000_0240, "WAIT_IDLE preserves queued register data");

    send_word(32'h2002_0000);
    check(!launch_start, "bad-count LAUNCH_KERNEL does not start");
    send_word(32'h0000_CAFE);
    check(error_status[1], "bad-count LAUNCH_KERNEL sets bad-word-count error");
    send_word(32'h0001_0000);
    check(error_status[1] && !launch_start, "bad-count LAUNCH_KERNEL skip realigns next command");
    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;

    send_word(32'h2001_0001);
    check(!launch_start, "reserved-flag LAUNCH_KERNEL does not start");
    check(error_status[2], "reserved-flag LAUNCH_KERNEL sets bad-reserved error");
    clear_error_status();

    launch_grid_x = 16'd0;
    expect_invalid_launch("zero-grid-x LAUNCH_KERNEL does not start");

    launch_grid_y = 16'd0;
    expect_invalid_launch("zero-grid-y LAUNCH_KERNEL does not start");

    launch_group_size_x = 16'd8;
    expect_invalid_launch("unsupported-group-x LAUNCH_KERNEL does not start");

    launch_group_size_y = 16'd2;
    expect_invalid_launch("unsupported-group-y LAUNCH_KERNEL does not start");

    launch_flags = 32'h0000_0001;
    expect_invalid_launch("unsupported-flags LAUNCH_KERNEL does not start");

    launch_busy = 1'b1;
    send_word(32'h2001_0000);
    check(!launch_start, "busy LAUNCH_KERNEL does not start");
    check(error_status[3], "busy LAUNCH_KERNEL sets dispatch-busy error");
    launch_busy = 1'b0;
    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;

    send_word(32'h5501_0000);
    check(error_status[0], "unknown opcode sets sticky error");
    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears sticky errors");

    send_word(32'h0101_0000);
    check(error_status[1], "bad word count sets sticky error");

    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears bad word count");

    send_word(32'h0205_0000);
    send_word({16'd7, 16'd8});
    send_word({16'd9, 16'd10});
    send_word(32'h0000_ABCD);
    cmd_data = 32'h0000_0001;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "RECT reserved word with nonzero bits is accepted");
    step();
    cmd_valid = 1'b0;
    step();
    check(error_status[2], "RECT nonzero reserved word sets bad-reserved error");
    check(rect_start && rect_color == 16'hABCD, "RECT reserved-word error still dispatches rectangle");
    rect_done = 1'b1;
    step();
    rect_done = 1'b0;

    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears rect reserved error");

    clear_busy = 1'b1;
    send_word(32'h0301_0000);
    check(busy, "WAIT_IDLE remains busy while draw engine is busy");
    check(!cmd_ready, "WAIT_IDLE blocks new command words");
    clear_busy = 1'b0;
    step();
    check(!busy, "WAIT_IDLE returns idle when draw engines are idle");

    launch_busy = 1'b1;
    send_word(32'h0301_0000);
    check(busy, "WAIT_IDLE remains busy while launch engine is busy");
    check(!cmd_ready, "WAIT_IDLE blocks new command words during launch busy");
    launch_busy = 1'b0;
    step();
    check(!busy, "WAIT_IDLE returns idle when launch engine is idle");

    clear_busy = 1'b1;
    send_word(32'h0102_0000);
    cmd_data = 32'h0000_2468;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "CLEAR color word accepted before busy dispatch");
    step();
    check(!clear_start, "busy clear engine suppresses same-cycle clear_start");
    cmd_valid = 1'b0;
    step();
    check(error_status[3], "busy clear engine sets dispatch-busy error");
    check(!clear_start, "busy clear engine suppresses clear_start");
    clear_busy = 1'b0;
    #1;
    check(!busy, "dispatch-busy CLEAR returns command processor idle");

    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears clear dispatch-busy");

    rect_busy = 1'b1;
    send_word(32'h0205_0000);
    send_word({16'd1, 16'd2});
    send_word({16'd3, 16'd4});
    send_word(32'h0000_5A5A);

    cmd_data = 32'h0000_0000;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "RECT reserved word accepted before busy dispatch");
    step();
    check(!rect_start, "busy rect engine suppresses same-cycle rect_start");
    cmd_valid = 1'b0;
    step();
    check(error_status[3], "busy rect engine sets dispatch-busy error");
    check(!rect_start, "busy rect engine suppresses rect_start");
    rect_busy = 1'b0;
    #1;
    check(!busy, "dispatch-busy RECT returns command processor idle");

    $display("tb_command_processor PASS");
    $finish;
  end
endmodule
