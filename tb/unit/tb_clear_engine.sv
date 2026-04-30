module tb_clear_engine;
  logic clk;
  logic reset;
  logic start;
  logic [15:0] start_color;
  logic busy;
  logic done;
  logic error;
  logic pixel_valid;
  logic pixel_ready;
  logic [15:0] pixel_x;
  logic [15:0] pixel_y;
  logic [15:0] pixel_color;
  int accepted;

  clear_engine #(
      .FB_WIDTH(4),
      .FB_HEIGHT(3)
  ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .start_color(start_color),
      .busy(busy),
      .done(done),
      .error(error),
      .pixel_valid(pixel_valid),
      .pixel_ready(pixel_ready),
      .pixel_x(pixel_x),
      .pixel_y(pixel_y),
      .pixel_color(pixel_color)
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

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    start = 1'b0;
    start_color = 16'h1234;
    pixel_ready = 1'b0;
    accepted = 0;

    step();
    reset = 1'b0;
    step();

    start = 1'b1;
    step();
    start = 1'b0;
    check(busy && pixel_valid && pixel_x == 16'd0 && pixel_y == 16'd0, "clear starts at origin");

    pixel_ready = 1'b0;
    step();
    check(pixel_valid && pixel_x == 16'd0 && pixel_y == 16'd0, "clear holds pixel on stall");

    pixel_ready = 1'b1;
    while (!done) begin
      if (pixel_valid && pixel_ready) begin
        check(pixel_color == 16'h1234, "clear emits configured color");
        check(pixel_x == (accepted % 4), "clear x sequence");
        check(pixel_y == (accepted / 4), "clear y sequence");
        accepted = accepted + 1;
      end
      step();
    end

    check(accepted == 12, "clear emits one pixel per framebuffer location");
    check(!busy && !error, "clear finishes without error");
    $display("tb_clear_engine PASS");
    $finish;
  end
endmodule
