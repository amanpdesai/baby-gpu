module rect_fill_engine #(
    parameter int FB_WIDTH = 160,
    parameter int FB_HEIGHT = 120,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16
) (
    input logic clk,
    input logic reset,

    input logic start,
    input logic [COORD_W-1:0] rect_x,
    input logic [COORD_W-1:0] rect_y,
    input logic [COORD_W-1:0] rect_width,
    input logic [COORD_W-1:0] rect_height,
    input logic [COLOR_W-1:0] rect_color,

    output logic busy,
    output logic done,
    output logic error,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [COORD_W-1:0] pixel_x,
    output logic [COORD_W-1:0] pixel_y,
    output logic [COLOR_W-1:0] pixel_color
);
  localparam logic [COORD_W:0] FB_WIDTH_EXT = (COORD_W + 1)'(FB_WIDTH);
  localparam logic [COORD_W:0] FB_HEIGHT_EXT = (COORD_W + 1)'(FB_HEIGHT);

  logic running;
  logic [COORD_W-1:0] x_origin;
  logic [COORD_W-1:0] x_pos;
  logic [COORD_W-1:0] y_pos;
  logic [COORD_W-1:0] x_last;
  logic [COORD_W-1:0] y_last;
  logic [COLOR_W-1:0] color_reg;

  logic [COORD_W:0] max_width_from_x;
  logic [COORD_W:0] max_height_from_y;
  logic [COORD_W:0] clipped_width;
  logic [COORD_W:0] clipped_height;
  logic no_pixels;

  assign busy = running;
  assign pixel_valid = running;
  assign pixel_x = x_pos;
  assign pixel_y = y_pos;
  assign pixel_color = color_reg;

  always_comb begin
    max_width_from_x = '0;
    max_height_from_y = '0;
    clipped_width = '0;
    clipped_height = '0;

    if ({1'b0, rect_x} < FB_WIDTH_EXT) begin
      max_width_from_x = FB_WIDTH_EXT - {1'b0, rect_x};
      if ({1'b0, rect_width} < max_width_from_x) begin
        clipped_width = {1'b0, rect_width};
      end else begin
        clipped_width = max_width_from_x;
      end
    end

    if ({1'b0, rect_y} < FB_HEIGHT_EXT) begin
      max_height_from_y = FB_HEIGHT_EXT - {1'b0, rect_y};
      if ({1'b0, rect_height} < max_height_from_y) begin
        clipped_height = {1'b0, rect_height};
      end else begin
        clipped_height = max_height_from_y;
      end
    end
  end

  assign no_pixels = (clipped_width == '0) || (clipped_height == '0);

  always_ff @(posedge clk) begin
    if (reset) begin
      running <= 1'b0;
      done <= 1'b0;
      error <= 1'b0;
      x_origin <= '0;
      x_pos <= '0;
      y_pos <= '0;
      x_last <= '0;
      y_last <= '0;
      color_reg <= '0;
    end else begin
      done <= 1'b0;

      if (start && running) begin
        error <= 1'b1;
      end

      if (start && !running) begin
        if (no_pixels) begin
          done <= 1'b1;
        end else begin
          running <= 1'b1;
          x_origin <= rect_x;
          x_pos <= rect_x;
          y_pos <= rect_y;
          x_last <= rect_x + clipped_width[COORD_W-1:0] - {{(COORD_W - 1) {1'b0}}, 1'b1};
          y_last <= rect_y + clipped_height[COORD_W-1:0] - {{(COORD_W - 1) {1'b0}}, 1'b1};
          color_reg <= rect_color;
        end
      end else if (running && pixel_ready) begin
        if ((x_pos == x_last) && (y_pos == y_last)) begin
          running <= 1'b0;
          done <= 1'b1;
        end else if (x_pos == x_last) begin
          x_pos <= x_origin;
          y_pos <= y_pos + {{(COORD_W - 1) {1'b0}}, 1'b1};
        end else begin
          x_pos <= x_pos + {{(COORD_W - 1) {1'b0}}, 1'b1};
        end
      end
    end
  end
endmodule
