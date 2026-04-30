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
      .fb_format(fb_format)
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

    $display("tb_register_file PASS");
    $finish;
  end
endmodule
