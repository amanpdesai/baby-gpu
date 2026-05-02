module clear_engine_formal (
    input logic clk
);
  localparam int FB_WIDTH = 2;
  localparam int FB_HEIGHT = 2;
  localparam int COORD_W = 2;
  localparam int COLOR_W = 16;

  (* anyseq *) logic reset;
  (* anyseq *) logic start;
  (* anyseq *) logic [COLOR_W-1:0] start_color;
  (* anyseq *) logic pixel_ready;

  logic busy;
  logic done;
  logic error;
  logic pixel_valid;
  logic [COORD_W-1:0] pixel_x;
  logic [COORD_W-1:0] pixel_y;
  logic [COLOR_W-1:0] pixel_color;

  clear_engine #(
      .FB_WIDTH(FB_WIDTH),
      .FB_HEIGHT(FB_HEIGHT),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
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

  logic past_valid;

  initial begin
    past_valid = 1'b0;
  end

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;

    if (!past_valid) begin
      assume(reset);
      assume(!start);
      assume(!pixel_ready);
    end else begin
      assume(!reset);
    end

    if (past_valid) begin
      assert(pixel_valid == busy);
      assert(pixel_x < COORD_W'(FB_WIDTH));
      assert(pixel_y < COORD_W'(FB_HEIGHT));
    end

    if (past_valid && $past(reset)) begin
      assert(!busy);
      assert(!done);
      assert(!error);
      assert(!pixel_valid);
      assert(pixel_x == '0);
      assert(pixel_y == '0);
      assert(pixel_color == '0);
    end

    if (past_valid && !$past(reset) && $past(start) && !$past(busy)) begin
      assert(busy);
      assert(pixel_valid);
      assert(pixel_x == '0);
      assert(pixel_y == '0);
      assert(pixel_color == $past(start_color));
    end

    if (past_valid && !$past(reset) && $past(busy) && !$past(pixel_ready)) begin
      assert(busy);
      assert(pixel_x == $past(pixel_x));
      assert(pixel_y == $past(pixel_y));
      assert(pixel_color == $past(pixel_color));
    end

    if (past_valid && !$past(reset) && $past(busy) && $past(pixel_ready)
        && ($past(pixel_x) == COORD_W'(FB_WIDTH - 1))
        && ($past(pixel_y) == COORD_W'(FB_HEIGHT - 1))) begin
      assert(done);
      assert(!busy);
    end

    if (past_valid && !$past(reset) && $past(error) && !reset) begin
      assert(error);
    end

    if (past_valid && !$past(reset) && $past(start) && $past(busy)) begin
      assert(error);
    end
  end
endmodule
