module tb_special_registers;
  import isa_pkg::*;

  localparam int LANES = 4;
  localparam int DATA_W = 32;
  localparam int COORD_W = 16;
  localparam int ADDR_W = 32;

  logic [ISA_SPECIAL_W-1:0] special_reg_id;
  logic [(LANES*COORD_W)-1:0] lane_id;
  logic [(LANES*COORD_W)-1:0] global_id_x;
  logic [(LANES*COORD_W)-1:0] global_id_y;
  logic [(LANES*DATA_W)-1:0] linear_global_id;
  logic [(LANES*COORD_W)-1:0] group_id_x;
  logic [(LANES*COORD_W)-1:0] group_id_y;
  logic [(LANES*COORD_W)-1:0] local_id_x;
  logic [(LANES*COORD_W)-1:0] local_id_y;
  logic [ADDR_W-1:0] arg_base;
  logic [ADDR_W-1:0] framebuffer_base;
  logic [COORD_W-1:0] framebuffer_width;
  logic [COORD_W-1:0] framebuffer_height;
  logic [(LANES*DATA_W)-1:0] value;
  logic illegal;

  special_registers #(
      .LANES(LANES),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .ADDR_W(ADDR_W)
  ) dut (
      .special_reg_id(special_reg_id),
      .lane_id(lane_id),
      .global_id_x(global_id_x),
      .global_id_y(global_id_y),
      .linear_global_id(linear_global_id),
      .group_id_x(group_id_x),
      .group_id_y(group_id_y),
      .local_id_x(local_id_x),
      .local_id_y(local_id_y),
      .arg_base(arg_base),
      .framebuffer_base(framebuffer_base),
      .framebuffer_width(framebuffer_width),
      .framebuffer_height(framebuffer_height),
      .value(value),
      .illegal(illegal)
  );

  function automatic logic [(LANES*COORD_W)-1:0] pack_coord(
      input logic [COORD_W-1:0] lane0,
      input logic [COORD_W-1:0] lane1,
      input logic [COORD_W-1:0] lane2,
      input logic [COORD_W-1:0] lane3);
    begin
      pack_coord = {lane3, lane2, lane1, lane0};
    end
  endfunction

  function automatic logic [(LANES*DATA_W)-1:0] pack_data(
      input logic [DATA_W-1:0] lane0,
      input logic [DATA_W-1:0] lane1,
      input logic [DATA_W-1:0] lane2,
      input logic [DATA_W-1:0] lane3);
    begin
      pack_data = {lane3, lane2, lane1, lane0};
    end
  endfunction

  function automatic logic [DATA_W-1:0] lane_word(
      input logic [(LANES*DATA_W)-1:0] bus,
      input int lane);
    begin
      lane_word = bus[(lane*DATA_W)+:DATA_W];
    end
  endfunction

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $fatal(1, "%s", message);
      end
    end
  endtask

  task automatic check_lane_values(
      input logic [ISA_SPECIAL_W-1:0] reg_id,
      input logic [DATA_W-1:0] lane0,
      input logic [DATA_W-1:0] lane1,
      input logic [DATA_W-1:0] lane2,
      input logic [DATA_W-1:0] lane3,
      input string message);
    begin
      special_reg_id = reg_id;
      #1;
      check(!illegal, {message, " legal"});
      check(lane_word(value, 0) == lane0, {message, " lane 0"});
      check(lane_word(value, 1) == lane1, {message, " lane 1"});
      check(lane_word(value, 2) == lane2, {message, " lane 2"});
      check(lane_word(value, 3) == lane3, {message, " lane 3"});
    end
  endtask

  initial begin
    lane_id = pack_coord(16'd0, 16'd1, 16'd2, 16'd3);
    global_id_x = pack_coord(16'd10, 16'd11, 16'd12, 16'd13);
    global_id_y = pack_coord(16'd20, 16'd21, 16'd22, 16'd23);
    linear_global_id = pack_data(32'd100, 32'd101, 32'd102, 32'd103);
    group_id_x = pack_coord(16'd2, 16'd2, 16'd3, 16'd3);
    group_id_y = pack_coord(16'd5, 16'd5, 16'd5, 16'd5);
    local_id_x = pack_coord(16'd0, 16'd1, 16'd0, 16'd1);
    local_id_y = pack_coord(16'd0, 16'd0, 16'd1, 16'd1);
    arg_base = 32'h0000_4000;
    framebuffer_base = 32'h0001_0000;
    framebuffer_width = 16'd640;
    framebuffer_height = 16'd480;

    check_lane_values(ISA_SR_LANE_ID, 32'd0, 32'd1, 32'd2, 32'd3, "lane_id");
    check_lane_values(ISA_SR_GLOBAL_ID_X, 32'd10, 32'd11, 32'd12, 32'd13, "global_id_x");
    check_lane_values(ISA_SR_GLOBAL_ID_Y, 32'd20, 32'd21, 32'd22, 32'd23, "global_id_y");
    check_lane_values(ISA_SR_LINEAR_GLOBAL_ID, 32'd100, 32'd101, 32'd102, 32'd103,
                      "linear_global_id");
    check_lane_values(ISA_SR_GROUP_ID_X, 32'd2, 32'd2, 32'd3, 32'd3, "group_id_x");
    check_lane_values(ISA_SR_GROUP_ID_Y, 32'd5, 32'd5, 32'd5, 32'd5, "group_id_y");
    check_lane_values(ISA_SR_LOCAL_ID_X, 32'd0, 32'd1, 32'd0, 32'd1, "local_id_x");
    check_lane_values(ISA_SR_LOCAL_ID_Y, 32'd0, 32'd0, 32'd1, 32'd1, "local_id_y");
    check_lane_values(ISA_SR_ARG_BASE, 32'h0000_4000, 32'h0000_4000, 32'h0000_4000,
                      32'h0000_4000, "arg_base");
    check_lane_values(ISA_SR_FRAMEBUFFER_BASE, 32'h0001_0000, 32'h0001_0000,
                      32'h0001_0000, 32'h0001_0000, "framebuffer_base");
    check_lane_values(ISA_SR_FRAMEBUFFER_WIDTH, 32'd640, 32'd640, 32'd640, 32'd640,
                      "framebuffer_width");
    check_lane_values(ISA_SR_FRAMEBUFFER_HEIGHT, 32'd480, 32'd480, 32'd480, 32'd480,
                      "framebuffer_height");

    special_reg_id = 6'h3F;
    #1;
    check(illegal, "unknown special register is illegal");
    check(value == '0, "unknown special register returns zero");

    $display("tb_special_registers PASS");
    $finish;
  end
endmodule
