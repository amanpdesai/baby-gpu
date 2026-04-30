module gpu_core #(
    parameter int FB_WIDTH = 160,
    parameter int FB_HEIGHT = 120,
    parameter int FIFO_DEPTH = 16,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16
) (
    input logic clk,
    input logic reset,
    input logic enable,
    input logic clear_errors,

    input logic cmd_valid,
    output logic cmd_ready,
    input logic [DATA_W-1:0] cmd_data,

    output logic busy,
    output logic [7:0] error_status,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_W-1:0] mem_req_addr,
    output logic [DATA_W-1:0] mem_req_wdata,
    output logic [(DATA_W/8)-1:0] mem_req_wmask
);
  localparam int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1);
  localparam logic [ADDR_W-1:0] FB_BASE = '0;
  localparam logic [COORD_W-1:0] FB_WIDTH_CONST = COORD_W'(FB_WIDTH);
  localparam logic [COORD_W-1:0] FB_HEIGHT_CONST = COORD_W'(FB_HEIGHT);
  localparam logic [ADDR_W-1:0] FB_STRIDE_BYTES = ADDR_W'(FB_WIDTH * 2);

  logic fifo_valid;
  logic fifo_ready;
  logic [DATA_W-1:0] fifo_data;
  logic fifo_empty;
  logic [FIFO_COUNT_W-1:0] fifo_count;
  logic [7:0] cp_error_status;

  logic cp_busy;
  logic clear_start;
  logic [COLOR_W-1:0] clear_color;
  logic clear_busy;
  logic clear_done;
  logic clear_error;
  logic clear_pixel_valid;
  logic clear_pixel_ready;
  logic [COORD_W-1:0] clear_pixel_x;
  logic [COORD_W-1:0] clear_pixel_y;
  logic [COLOR_W-1:0] clear_pixel_color;

  logic rect_start;
  logic [COORD_W-1:0] rect_x;
  logic [COORD_W-1:0] rect_y;
  logic [COORD_W-1:0] rect_width;
  logic [COORD_W-1:0] rect_height;
  logic [COLOR_W-1:0] rect_color;
  logic rect_busy;
  logic rect_done;
  logic rect_error;
  logic rect_pixel_valid;
  logic rect_pixel_ready;
  logic [COORD_W-1:0] rect_pixel_x;
  logic [COORD_W-1:0] rect_pixel_y;
  logic [COLOR_W-1:0] rect_pixel_color;

  logic writer_pixel_valid;
  logic writer_pixel_ready;
  logic [COORD_W-1:0] writer_pixel_x;
  logic [COORD_W-1:0] writer_pixel_y;
  logic [COLOR_W-1:0] writer_pixel_color;

  assign busy = cp_busy || !fifo_empty;
  assign error_status = cp_error_status | {clear_error, rect_error, 6'b000000};

  command_fifo #(
      .DATA_W(DATA_W),
      .DEPTH(FIFO_DEPTH)
  ) u_command_fifo (
      .clk(clk),
      .reset(reset),
      .flush(clear_errors),
      .in_valid(cmd_valid),
      .in_ready(cmd_ready),
      .in_data(cmd_data),
      .out_valid(fifo_valid),
      .out_ready(fifo_ready),
      .out_data(fifo_data),
      .full(),
      .empty(fifo_empty),
      .count(fifo_count)
  );

  command_processor #(
      .WORD_W(DATA_W),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_command_processor (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .clear_errors(clear_errors),
      .cmd_valid(fifo_valid),
      .cmd_ready(fifo_ready),
      .cmd_data(fifo_data),
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
      .reg_write_valid(),
      .reg_write_addr(),
      .reg_write_data(),
      .busy(cp_busy),
      .error_status(cp_error_status)
  );

  clear_engine #(
      .FB_WIDTH(FB_WIDTH),
      .FB_HEIGHT(FB_HEIGHT),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_clear_engine (
      .clk(clk),
      .reset(reset),
      .start(clear_start),
      .start_color(clear_color),
      .busy(clear_busy),
      .done(clear_done),
      .error(clear_error),
      .pixel_valid(clear_pixel_valid),
      .pixel_ready(clear_pixel_ready),
      .pixel_x(clear_pixel_x),
      .pixel_y(clear_pixel_y),
      .pixel_color(clear_pixel_color)
  );

  rect_fill_engine #(
      .FB_WIDTH(FB_WIDTH),
      .FB_HEIGHT(FB_HEIGHT),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_rect_fill_engine (
      .clk(clk),
      .reset(reset),
      .start(rect_start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
      .busy(rect_busy),
      .done(rect_done),
      .error(rect_error),
      .pixel_valid(rect_pixel_valid),
      .pixel_ready(rect_pixel_ready),
      .pixel_x(rect_pixel_x),
      .pixel_y(rect_pixel_y),
      .pixel_color(rect_pixel_color)
  );

  assign writer_pixel_valid = clear_pixel_valid || rect_pixel_valid;
  assign writer_pixel_x = clear_pixel_valid ? clear_pixel_x : rect_pixel_x;
  assign writer_pixel_y = clear_pixel_valid ? clear_pixel_y : rect_pixel_y;
  assign writer_pixel_color = clear_pixel_valid ? clear_pixel_color : rect_pixel_color;
  assign clear_pixel_ready = clear_pixel_valid ? writer_pixel_ready : 1'b0;
  assign rect_pixel_ready = (!clear_pixel_valid && rect_pixel_valid) ? writer_pixel_ready : 1'b0;

  framebuffer_writer #(
      .ADDR_W(ADDR_W),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .COLOR_W(COLOR_W)
  ) u_framebuffer_writer (
      .pixel_valid(writer_pixel_valid),
      .pixel_ready(writer_pixel_ready),
      .pixel_x(writer_pixel_x),
      .pixel_y(writer_pixel_y),
      .pixel_color(writer_pixel_color),
      .fb_base(FB_BASE),
      .fb_width(FB_WIDTH_CONST),
      .fb_height(FB_HEIGHT_CONST),
      .stride_bytes(FB_STRIDE_BYTES),
      .mem_req_valid(mem_req_valid),
      .mem_req_ready(mem_req_ready),
      .mem_req_write(mem_req_write),
      .mem_req_addr(mem_req_addr),
      .mem_req_wdata(mem_req_wdata),
      .mem_req_wmask(mem_req_wmask)
  );

endmodule
