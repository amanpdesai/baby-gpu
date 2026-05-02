module tb_framebuffer_writer;
  logic pixel_valid;
  logic pixel_ready;
  logic [15:0] pixel_x;
  logic [15:0] pixel_y;
  logic [15:0] pixel_color;
  logic [31:0] fb_base;
  logic [15:0] fb_width;
  logic [15:0] fb_height;
  logic [31:0] stride_bytes;
  logic mem_req_valid;
  logic mem_req_ready;
  logic mem_req_write;
  logic [31:0] mem_req_addr;
  logic [31:0] mem_req_wdata;
  logic [3:0] mem_req_wmask;
  logic [31:0] stalled_addr;
  logic [31:0] stalled_wdata;
  logic [3:0] stalled_wmask;

  framebuffer_writer dut (
      .pixel_valid(pixel_valid),
      .pixel_ready(pixel_ready),
      .pixel_x(pixel_x),
      .pixel_y(pixel_y),
      .pixel_color(pixel_color),
      .fb_base(fb_base),
      .fb_width(fb_width),
      .fb_height(fb_height),
      .stride_bytes(stride_bytes),
      .mem_req_valid(mem_req_valid),
      .mem_req_ready(mem_req_ready),
      .mem_req_write(mem_req_write),
      .mem_req_addr(mem_req_addr),
      .mem_req_wdata(mem_req_wdata),
      .mem_req_wmask(mem_req_wmask)
  );

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $fatal(1, "%s", message);
      end
    end
  endtask

  initial begin
    fb_base = 32'd0;
    fb_width = 16'd4;
    fb_height = 16'd3;
    stride_bytes = 32'd8;
    pixel_valid = 1'b1;
    mem_req_ready = 1'b1;

    pixel_x = 16'd0;
    pixel_y = 16'd1;
    pixel_color = 16'h00F0;
    #1;
    check(mem_req_valid && pixel_ready && mem_req_write, "writer accepts in-bounds low-lane pixel");
    check(mem_req_addr == 32'd8, "low-lane pixel aligned address");
    check(mem_req_wdata == 32'h0000_00F0, "low-lane pixel write data");
    check(mem_req_wmask == 4'b0011, "low-lane write mask");

    pixel_x = 16'd1;
    pixel_y = 16'd2;
    pixel_color = 16'hABCD;
    #1;
    check(mem_req_valid && pixel_ready, "writer accepts in-bounds high-lane pixel");
    check(mem_req_addr == 32'd16, "high-lane pixel aligned address");
    check(mem_req_wdata == 32'hABCD_0000, "high-lane pixel write data");
    check(mem_req_wmask == 4'b1100, "high-lane write mask");

    fb_base = 32'd4;
    stride_bytes = 32'd16;
    pixel_x = 16'd2;
    pixel_y = 16'd1;
    pixel_color = 16'h1357;
    #1;
    check(mem_req_valid && pixel_ready, "writer accepts nonzero-base low-lane pixel");
    check(mem_req_addr == 32'd24, "nonzero-base low-lane aligned address");
    check(mem_req_wdata == 32'h0000_1357, "nonzero-base low-lane write data");
    check(mem_req_wmask == 4'b0011, "nonzero-base low-lane write mask");

    fb_base = 32'd2;
    pixel_x = 16'd0;
    pixel_y = 16'd1;
    pixel_color = 16'h2468;
    #1;
    check(mem_req_valid && pixel_ready, "writer accepts nonzero-base high-lane pixel");
    check(mem_req_addr == 32'd16, "nonzero-base high-lane aligned address");
    check(mem_req_wdata == 32'h2468_0000, "nonzero-base high-lane write data");
    check(mem_req_wmask == 4'b1100, "nonzero-base high-lane write mask");

    fb_base = 32'd0;
    stride_bytes = 32'd8;
    mem_req_ready = 1'b0;
    #1;
    check(mem_req_valid && !pixel_ready, "writer backpressures valid in-bounds pixel");
    stalled_addr = mem_req_addr;
    stalled_wdata = mem_req_wdata;
    stalled_wmask = mem_req_wmask;
    #1;
    check(mem_req_valid && !pixel_ready, "writer remains stalled while memory is not ready");
    check(mem_req_addr == stalled_addr, "writer stalled address remains stable");
    check(mem_req_wdata == stalled_wdata, "writer stalled write data remains stable");
    check(mem_req_wmask == stalled_wmask, "writer stalled write mask remains stable");
    mem_req_ready = 1'b1;
    #1;
    check(mem_req_valid && pixel_ready, "writer handshakes stalled pixel when memory becomes ready");
    check(mem_req_addr == stalled_addr, "writer accepted address matches stalled payload");
    check(mem_req_wdata == stalled_wdata, "writer accepted write data matches stalled payload");
    check(mem_req_wmask == stalled_wmask, "writer accepted write mask matches stalled payload");

    mem_req_ready = 1'b0;
    pixel_x = 16'd7;
    pixel_y = 16'd0;
    #1;
    check(!mem_req_valid && pixel_ready, "writer drops out-of-bounds pixels without stalling");

    pixel_x = 16'd0;
    pixel_y = 16'd3;
    #1;
    check(!mem_req_valid && pixel_ready, "writer drops out-of-bounds y pixels without stalling");

    $display("tb_framebuffer_writer PASS");
    $finish;
  end
endmodule
