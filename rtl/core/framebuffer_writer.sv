module framebuffer_writer #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16
) (
    input logic pixel_valid,
    output logic pixel_ready,
    input logic [COORD_W-1:0] pixel_x,
    input logic [COORD_W-1:0] pixel_y,
    input logic [COLOR_W-1:0] pixel_color,

    input logic [ADDR_W-1:0] fb_base,
    input logic [COORD_W-1:0] fb_width,
    input logic [COORD_W-1:0] fb_height,
    input logic [ADDR_W-1:0] stride_bytes,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_W-1:0] mem_req_addr,
    output logic [DATA_W-1:0] mem_req_wdata,
    output logic [(DATA_W/8)-1:0] mem_req_wmask
);
  logic in_bounds;
  logic [ADDR_W-1:0] byte_addr;

  assign in_bounds = (pixel_x < fb_width) && (pixel_y < fb_height);
  assign byte_addr = fb_base + (ADDR_W'(pixel_y) * stride_bytes) + (ADDR_W'(pixel_x) << 1);
  assign mem_req_valid = pixel_valid && in_bounds;
  assign mem_req_write = 1'b1;
  assign mem_req_addr = {byte_addr[ADDR_W-1:2], 2'b00};
  assign mem_req_wdata = byte_addr[1] ? {pixel_color, 16'h0000} : {16'h0000, pixel_color};
  assign mem_req_wmask = byte_addr[1] ? 4'b1100 : 4'b0011;
  assign pixel_ready = in_bounds ? mem_req_ready : 1'b1;
endmodule
