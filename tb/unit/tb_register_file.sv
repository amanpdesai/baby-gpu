module tb_register_file;
  logic clk;
  logic reset;
  logic write_valid;
  logic [31:0] write_addr;
  logic [31:0] write_data;
  logic read_valid;
  logic [31:0] read_addr;
  logic [31:0] read_data;
  logic status_busy;
  logic [7:0] status_errors;
  logic core_enable;
  logic soft_reset_pulse;
  logic clear_errors_pulse;
  logic test_pattern_enable;
  logic [31:0] fb_base;
  logic [15:0] fb_width;
  logic [15:0] fb_height;
  logic [1:0] fb_format;
  logic [31:0] launch_program_base;
  logic [15:0] launch_grid_x;
  logic [15:0] launch_grid_y;
  logic [15:0] launch_group_size_x;
  logic [15:0] launch_group_size_y;
  logic [31:0] launch_arg_base;
  logic [31:0] launch_flags;

  register_file #(
      .FB_WIDTH_DEFAULT(4),
      .FB_HEIGHT_DEFAULT(3)
  ) dut (
      .clk(clk),
      .reset(reset),
      .write_valid(write_valid),
      .write_addr(write_addr),
      .write_data(write_data),
      .read_valid(read_valid),
      .read_addr(read_addr),
      .read_data(read_data),
      .status_busy(status_busy),
      .status_errors(status_errors),
      .core_enable(core_enable),
      .soft_reset_pulse(soft_reset_pulse),
      .clear_errors_pulse(clear_errors_pulse),
      .test_pattern_enable(test_pattern_enable),
      .fb_base(fb_base),
      .fb_width(fb_width),
      .fb_height(fb_height),
      .fb_format(fb_format),
      .launch_program_base(launch_program_base),
      .launch_grid_x(launch_grid_x),
      .launch_grid_y(launch_grid_y),
      .launch_group_size_x(launch_group_size_x),
      .launch_group_size_y(launch_group_size_y),
      .launch_arg_base(launch_arg_base),
      .launch_flags(launch_flags)
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

  task automatic write_reg(input logic [31:0] addr, input logic [31:0] data);
    begin
      write_addr = addr;
      write_data = data;
      write_valid = 1'b1;
      step();
      write_valid = 1'b0;
      write_addr = '0;
      write_data = '0;
    end
  endtask

  task automatic read_reg(input logic [31:0] addr);
    begin
      read_addr = addr;
      read_valid = 1'b1;
      #1;
      read_valid = 1'b0;
      read_addr = '0;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    write_valid = 1'b0;
    write_addr = '0;
    write_data = '0;
    read_valid = 1'b0;
    read_addr = '0;
    status_busy = 1'b0;
    status_errors = 8'h00;

    step();
    reset = 1'b0;
    step();

    check(!core_enable, "control enable resets low");
    check(fb_width == 16'd4 && fb_height == 16'd3, "framebuffer dimensions reset to defaults");
    check(fb_format == 2'd1, "framebuffer format resets to RGB565");
    check(launch_program_base == 32'h0000_0000, "PROGRAM_BASE resets to zero");
    check(launch_grid_x == 16'd0 && launch_grid_y == 16'd0, "GRID dimensions reset to zero");
    check(launch_group_size_x == 16'd4 && launch_group_size_y == 16'd1,
          "GROUP_SIZE resets to one current warp");
    check(launch_arg_base == 32'h0000_0000, "ARG_BASE resets to zero");
    check(launch_flags == 32'h0000_0000, "LAUNCH_FLAGS resets to zero");

    read_reg(32'h0000_0000);
    check(read_data == 32'h4250_4755, "GPU_ID readback");

    status_busy = 1'b1;
    status_errors = 8'hA5;
    read_reg(32'h0000_0008);
    check(read_data == 32'h0000_014B, "STATUS packs busy and errors");

    write_reg(32'h0000_000C, 32'h0000_001F);
    check(core_enable && test_pattern_enable, "CONTROL stores persistent bits");
    check(soft_reset_pulse && clear_errors_pulse, "CONTROL emits one-cycle pulses");
    step();
    check(!soft_reset_pulse && !clear_errors_pulse, "CONTROL pulses clear after one cycle");
    read_reg(32'h0000_000C);
    check(read_data == 32'h0000_0019, "CONTROL readback omits pulse bits");

    write_reg(32'h0000_0010, 32'h0000_0040);
    write_reg(32'h0000_0014, 32'h0000_0008);
    write_reg(32'h0000_0018, 32'h0000_0006);
    check(fb_base == 32'h0000_0040, "FRAMEBUFFER_BASE updates");
    check(fb_width == 16'd8 && fb_height == 16'd6, "FRAMEBUFFER dimensions update");

    write_reg(32'h0000_0014, 32'h0000_0000);
    write_reg(32'h0000_001C, 32'h0000_0002);
    check(fb_width == 16'd8, "zero width write is ignored");
    check(fb_format == 2'd1, "unsupported format write is ignored");

    write_reg(32'h0000_0028, 32'h0000_0003);
    read_reg(32'h0000_0028);
    check(read_data == 32'h0000_0003, "INTERRUPT_ENABLE readback");

    write_reg(32'h0000_0040, 32'h0000_0014);
    write_reg(32'h0000_0044, 32'h0000_0008);
    write_reg(32'h0000_0048, 32'h0000_0003);
    write_reg(32'h0000_004C, 32'h0000_0002);
    write_reg(32'h0000_0050, 32'h0000_0004);
    write_reg(32'h0000_0054, 32'h0000_0200);
    write_reg(32'h0000_0058, 32'hA5A5_0003);
    check(launch_program_base == 32'h0000_0014, "PROGRAM_BASE updates");
    check(launch_grid_x == 16'd8 && launch_grid_y == 16'd3, "GRID registers update");
    check(launch_group_size_x == 16'd2 && launch_group_size_y == 16'd4,
          "GROUP_SIZE registers update");
    check(launch_arg_base == 32'h0000_0200, "ARG_BASE updates");
    check(launch_flags == 32'hA5A5_0003, "LAUNCH_FLAGS updates");

    write_reg(32'h0000_004C, 32'h0000_0000);
    write_reg(32'h0000_0050, 32'h0000_0000);
    check(launch_group_size_x == 16'd2 && launch_group_size_y == 16'd4,
          "zero GROUP_SIZE writes are ignored");

    read_reg(32'h0000_0040);
    check(read_data == 32'h0000_0014, "PROGRAM_BASE readback");
    read_reg(32'h0000_0044);
    check(read_data == 32'h0000_0008, "GRID_X readback");
    read_reg(32'h0000_0048);
    check(read_data == 32'h0000_0003, "GRID_Y readback");
    read_reg(32'h0000_004C);
    check(read_data == 32'h0000_0002, "GROUP_SIZE_X readback");
    read_reg(32'h0000_0050);
    check(read_data == 32'h0000_0004, "GROUP_SIZE_Y readback");
    read_reg(32'h0000_0054);
    check(read_data == 32'h0000_0200, "ARG_BASE readback");
    read_reg(32'h0000_0058);
    check(read_data == 32'hA5A5_0003, "LAUNCH_FLAGS readback");

    write_reg(32'h0000_00FC, 32'hFFFF_FFFF);
    read_reg(32'h0000_000C);
    check(read_data == 32'h0000_0019, "unknown write preserves CONTROL state");
    check(fb_base == 32'h0000_0040 && fb_width == 16'd8 && fb_height == 16'd6,
          "unknown write preserves framebuffer state");
    check(fb_format == 2'd1, "unknown write preserves framebuffer format");
    check(launch_program_base == 32'h0000_0014 && launch_grid_x == 16'd8 &&
          launch_grid_y == 16'd3, "unknown write preserves launch dimensions");
    check(launch_group_size_x == 16'd2 && launch_group_size_y == 16'd4,
          "unknown write preserves launch group size");
    check(launch_arg_base == 32'h0000_0200 && launch_flags == 32'hA5A5_0003,
          "unknown write preserves launch payload registers");

    read_reg(32'h0000_00FC);
    check(read_data == 32'h0000_0000, "unknown register reads as zero");

    $display("tb_register_file PASS");
    $finish;
  end
endmodule
