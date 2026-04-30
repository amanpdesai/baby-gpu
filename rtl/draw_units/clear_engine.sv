module clear_engine #(
    parameter int FB_WIDTH = 160,
    parameter int FB_HEIGHT = 120,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16
) (
    input logic clk,
    input logic reset,

    input logic start,
    input logic [COLOR_W-1:0] start_color,

    output logic busy,
    output logic done,
    output logic error,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [COORD_W-1:0] pixel_x,
    output logic [COORD_W-1:0] pixel_y,
    output logic [COLOR_W-1:0] pixel_color
);
  logic running;
  logic [COORD_W-1:0] x_pos;
  logic [COORD_W-1:0] y_pos;
  logic [COLOR_W-1:0] color_reg;

  assign busy = running;
  assign pixel_valid = running;
  assign pixel_x = x_pos;
  assign pixel_y = y_pos;
  assign pixel_color = color_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      running <= 1'b0;
      done <= 1'b0;
      error <= 1'b0;
      x_pos <= '0;
      y_pos <= '0;
      color_reg <= '0;
    end else begin
      done <= 1'b0;

      if (start && running) begin
        error <= 1'b1;
      end

      if (start && !running) begin
        running <= 1'b1;
        x_pos <= '0;
        y_pos <= '0;
        color_reg <= start_color;
      end else if (running && pixel_ready) begin
        if ((x_pos == COORD_W'(FB_WIDTH - 1)) && (y_pos == COORD_W'(FB_HEIGHT - 1))) begin
          running <= 1'b0;
          done <= 1'b1;
        end else if (x_pos == COORD_W'(FB_WIDTH - 1)) begin
          x_pos <= '0;
          y_pos <= y_pos + {{(COORD_W - 1) {1'b0}}, 1'b1};
        end else begin
          x_pos <= x_pos + {{(COORD_W - 1) {1'b0}}, 1'b1};
        end
      end
    end
  end
endmodule
