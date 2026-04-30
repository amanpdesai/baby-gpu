package gpu_pkg;
  localparam int WORD_W = 32;
  localparam int ADDR_W = 32;
  localparam int COLOR_W = 16;
  localparam int COORD_W = 16;

  localparam int FB_WIDTH_DEFAULT = 160;
  localparam int FB_HEIGHT_DEFAULT = 120;
  localparam int RGB565_BYTES_PER_PIXEL = 2;

  typedef enum logic [7:0] {
    GPU_OP_NOP = 8'h00,
    GPU_OP_CLEAR = 8'h01,
    GPU_OP_FILL_RECT = 8'h02,
    GPU_OP_WAIT_IDLE = 8'h03,
    GPU_OP_SET_REGISTER = 8'h10
  } gpu_opcode_e;

  typedef enum logic [1:0] {
    GPU_FB_FORMAT_INVALID = 2'd0,
    GPU_FB_FORMAT_RGB565 = 2'd1,
    GPU_FB_FORMAT_INDEX8 = 2'd2
  } gpu_fb_format_e;

  function automatic logic [WORD_W-1:0] gpu_command_header(
      input logic [7:0] opcode,
      input logic [7:0] word_count,
      input logic [15:0] flags);
    gpu_command_header = {opcode, word_count, flags};
  endfunction
endpackage
