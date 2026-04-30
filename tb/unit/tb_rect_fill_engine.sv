module tb_rect_fill_engine;
  logic clk;
  logic reset;
  logic start;
  logic [15:0] rect_x;
  logic [15:0] rect_y;
  logic [15:0] rect_width;
  logic [15:0] rect_height;
  logic [15:0] rect_color;
  logic busy;
  logic done;
  logic error;
  logic pixel_valid;
  logic pixel_ready;
  logic [15:0] pixel_x;
  logic [15:0] pixel_y;
  logic [15:0] pixel_color;
  int accepted;
  logic [15:0] expected_x [0:3];
  logic [15:0] expected_y [0:3];

  rect_fill_engine #(
      .FB_WIDTH(4),
      .FB_HEIGHT(3)
  ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
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
    expected_x[0] = 16'd2;
    expected_y[0] = 16'd1;
    expected_x[1] = 16'd3;
    expected_y[1] = 16'd1;
    expected_x[2] = 16'd2;
    expected_y[2] = 16'd2;
    expected_x[3] = 16'd3;
    expected_y[3] = 16'd2;

    clk = 1'b0;
    reset = 1'b1;
    start = 1'b0;
    rect_x = 16'd2;
    rect_y = 16'd1;
    rect_width = 16'd4;
    rect_height = 16'd3;
    rect_color = 16'hCAFE;
    pixel_ready = 1'b1;
    accepted = 0;

    step();
    reset = 1'b0;
    step();

    start = 1'b1;
    step();
    start = 1'b0;

    while (!done) begin
      if (pixel_valid && pixel_ready) begin
        check(accepted < 4, "rect emits expected number of pixels");
        check(pixel_x == expected_x[accepted], "rect clipped x sequence");
        check(pixel_y == expected_y[accepted], "rect clipped y sequence");
        check(pixel_color == 16'hCAFE, "rect emits configured color");
        accepted = accepted + 1;
      end
      step();
    end

    check(accepted == 4, "rect clips to framebuffer edge");
    check(!busy && !error, "rect finishes without error");

    rect_width = 16'd0;
    start = 1'b1;
    step();
    start = 1'b0;
    check(done && !busy && !pixel_valid, "zero-width rect completes as no-op");

    $display("tb_rect_fill_engine PASS");
    $finish;
  end
endmodule
