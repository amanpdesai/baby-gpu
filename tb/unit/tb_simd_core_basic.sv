import isa_pkg::*;

module tb_simd_core_basic;
  localparam int LANES = 4;
  localparam int DATA_W = 32;
  localparam int COORD_W = 16;
  localparam int PC_W = 8;

  logic clk;
  logic reset;
  logic start;
  logic [LANES-1:0] launch_active_mask;
  logic launch_ready;
  logic busy;
  logic done;
  logic core_error;
  logic [PC_W-1:0] instruction_addr;
  logic [ISA_WORD_W-1:0] instruction;
  logic data_req_valid;
  logic data_req_ready;
  logic data_req_write;
  logic [31:0] data_req_addr;
  logic [31:0] data_req_wdata;
  logic [3:0] data_req_wmask;
  logic data_rsp_valid;
  logic data_rsp_ready;
  logic [31:0] data_rsp_rdata;
  logic data_mem_error;
  logic [(LANES*COORD_W)-1:0] lane_id;
  logic [(LANES*COORD_W)-1:0] global_id_x;
  logic [(LANES*COORD_W)-1:0] global_id_y;
  logic [(LANES*DATA_W)-1:0] linear_global_id;
  logic [(LANES*COORD_W)-1:0] group_id_x;
  logic [(LANES*COORD_W)-1:0] group_id_y;
  logic [(LANES*COORD_W)-1:0] local_id_x;
  logic [(LANES*COORD_W)-1:0] local_id_y;
  logic [31:0] arg_base;
  logic [31:0] framebuffer_base;
  logic [COORD_W-1:0] framebuffer_width;
  logic [COORD_W-1:0] framebuffer_height;
  logic [3:0] debug_read_addr;
  logic [(LANES*DATA_W)-1:0] debug_read_data;

  logic [ISA_WORD_W-1:0] imem [0:15];

  simd_core #(
      .LANES(LANES),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .PC_W(PC_W)
  ) dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .launch_active_mask(launch_active_mask),
      .launch_ready(launch_ready),
      .busy(busy),
      .done(done),
      .error(core_error),
      .instruction_addr(instruction_addr),
      .instruction(instruction),
      .data_req_valid(data_req_valid),
      .data_req_ready(data_req_ready),
      .data_req_write(data_req_write),
      .data_req_addr(data_req_addr),
      .data_req_wdata(data_req_wdata),
      .data_req_wmask(data_req_wmask),
      .data_rsp_valid(data_rsp_valid),
      .data_rsp_ready(data_rsp_ready),
      .data_rsp_rdata(data_rsp_rdata),
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
      .debug_read_addr(debug_read_addr),
      .debug_read_data(debug_read_data)
  );

  data_memory #(
      .ADDR_W(32),
      .DATA_W(32),
      .DEPTH_WORDS(64)
  ) u_data_memory (
      .clk(clk),
      .reset(reset),
      .req_valid(data_req_valid),
      .req_ready(data_req_ready),
      .req_write(data_req_write),
      .req_addr(data_req_addr),
      .req_wdata(data_req_wdata),
      .req_wmask(data_req_wmask),
      .rsp_valid(data_rsp_valid),
      .rsp_ready(data_rsp_ready),
      .rsp_rdata(data_rsp_rdata),
      .error(data_mem_error)
  );

  assign instruction = imem[instruction_addr];

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

  function automatic logic [DATA_W-1:0] lane_word(
      input logic [(LANES*DATA_W)-1:0] value,
      input int lane);
    begin
      lane_word = value[(lane*DATA_W)+:DATA_W];
    end
  endfunction

  task automatic clear_program;
    int idx;
    begin
      for (idx = 0; idx < 16; idx = idx + 1) begin
        imem[idx] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
      end
    end
  endtask

  task automatic pulse_start;
    begin
      start = 1'b1;
      step();
      start = 1'b0;
    end
  endtask

  task automatic wait_done;
    int timeout;
    begin
      timeout = 0;
      while (!done && !core_error) begin
        step();
        timeout = timeout + 1;
      check(timeout < 96, "SIMD core timed out");
      end
    end
  endtask

  task automatic expect_next_mem_req(
      input logic expected_write,
      input logic [31:0] expected_addr,
      input string message);
    int timeout;
    begin
      timeout = 0;
      while (!data_req_valid) begin
        step();
        timeout = timeout + 1;
        check(timeout < 96, {message, " request timed out"});
      end

      check(data_req_ready, {message, " request is ready"});
      check(data_req_write == expected_write, {message, " write flag"});
      check(data_req_addr == expected_addr, {message, " address"});
      step();
    end
  endtask

  task automatic expect_all_lanes(input logic [DATA_W-1:0] expected, input string message);
    int lane;
    begin
      for (lane = 0; lane < LANES; lane = lane + 1) begin
        check(lane_word(debug_read_data, lane) == expected, message);
      end
    end
  endtask

  task automatic expect_lane_value(
      input int lane,
      input logic [DATA_W-1:0] expected,
      input string message);
    begin
      check(lane_word(debug_read_data, lane) == expected, message);
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    start = 1'b0;
    launch_active_mask = '1;
    lane_id = {16'd3, 16'd2, 16'd1, 16'd0};
    global_id_x = {16'd13, 16'd12, 16'd11, 16'd10};
    global_id_y = {16'd23, 16'd22, 16'd21, 16'd20};
    linear_global_id = {32'd103, 32'd102, 32'd101, 32'd100};
    group_id_x = '0;
    group_id_y = '0;
    local_id_x = lane_id;
    local_id_y = '0;
    arg_base = 32'h0000_1000;
    framebuffer_base = 32'h0002_0000;
    framebuffer_width = 16'd160;
    framebuffer_height = 16'd120;
    debug_read_addr = 4'd0;
    clear_program();

    step();
    reset = 1'b0;
    step();

    imem[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd5);
    imem[1] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd7);
    imem[2] = isa_pkg::isa_r_type(ISA_OP_ADD, 4'd3, 4'd1, 4'd2);
    imem[3] = isa_pkg::isa_r_type(ISA_OP_MUL, 4'd4, 4'd3, 4'd2);
    imem[4] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "MOVI/ADD/MUL program completes without error");

    debug_read_addr = 4'd3;
    #1;
    expect_all_lanes(32'd12, "ADD result is visible in R3");
    debug_read_addr = 4'd4;
    #1;
    expect_all_lanes(32'd84, "MUL result is visible in R4");
    check(done && !busy, "debug reads are valid in DONE because the core is not busy");
    step();
    check(!done && !busy && !core_error, "core returns to idle after DONE");
    debug_read_addr = 4'd3;
    #1;
    expect_all_lanes(32'd12, "debug read remains valid when idle after DONE");

    clear_program();
    imem[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd15);
    imem[1] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd3);
    imem[2] = isa_pkg::isa_r_type(ISA_OP_SUB, 4'd3, 4'd1, 4'd2);
    imem[3] = isa_pkg::isa_r_type(ISA_OP_AND, 4'd4, 4'd1, 4'd2);
    imem[4] = isa_pkg::isa_r_type(ISA_OP_OR, 4'd5, 4'd1, 4'd2);
    imem[5] = isa_pkg::isa_r_type(ISA_OP_XOR, 4'd6, 4'd1, 4'd2);
    imem[6] = isa_pkg::isa_r_type(ISA_OP_SHL, 4'd7, 4'd2, 4'd2);
    imem[7] = isa_pkg::isa_r_type(ISA_OP_SHR, 4'd8, 4'd1, 4'd2);
    imem[8] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "extended ALU program completes without error");

    debug_read_addr = 4'd3;
    #1;
    expect_all_lanes(32'd12, "SUB result is visible in R3");
    debug_read_addr = 4'd4;
    #1;
    expect_all_lanes(32'd3, "AND result is visible in R4");
    debug_read_addr = 4'd5;
    #1;
    expect_all_lanes(32'd15, "OR result is visible in R5");
    debug_read_addr = 4'd6;
    #1;
    expect_all_lanes(32'd12, "XOR result is visible in R6");
    debug_read_addr = 4'd7;
    #1;
    expect_all_lanes(32'd24, "SHL result is visible in R7");
    debug_read_addr = 4'd8;
    #1;
    expect_all_lanes(32'd1, "SHR result is visible in R8");
    step();

    reset = 1'b1;
    step();
    reset = 1'b0;
    launch_active_mask = '1;
    clear_program();
    imem[0] = isa_pkg::isa_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0);
    imem[1] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "NOP advances PC to following END");
    debug_read_addr = 4'd1;
    #1;
    expect_all_lanes(32'd0, "NOP does not write R1");

    reset = 1'b1;
    step();
    reset = 1'b0;
    launch_active_mask = '1;
    clear_program();
    imem[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd0, 4'd0, 18'd123);
    imem[1] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "MOVI to R0 program completes");
    debug_read_addr = 4'd0;
    #1;
    expect_all_lanes(32'd0, "R0 remains zero through simd_core writeback");

    reset = 1'b1;
    step();
    reset = 1'b0;
    launch_active_mask = 4'b1010;
    clear_program();
    imem[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd42);
    imem[1] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "masked MOVI program completes");
    debug_read_addr = 4'd1;
    #1;
    expect_lane_value(0, 32'd0, "inactive lane 0 suppresses write");
    expect_lane_value(1, 32'd42, "active lane 1 writes");
    expect_lane_value(2, 32'd0, "inactive lane 2 suppresses write");
    expect_lane_value(3, 32'd42, "active lane 3 writes");
    launch_active_mask = '1;

    reset = 1'b1;
    step();
    reset = 1'b0;
    clear_program();
    imem[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd9);
    imem[1] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    check(launch_ready, "launch_ready is high before held launch");
    start = 1'b1;
    step();
    wait_done();
    check(done && start && !core_error, "held launch reaches DONE once");
    step();
    check(!busy && !done && !core_error, "held launch does not relaunch immediately after DONE");
    check(!launch_ready, "held launch is not ready until start deasserts");
    debug_read_addr = 4'd1;
    #1;
    expect_all_lanes(32'd9, "held launch wrote R1 once");
    start = 1'b0;
    step();
    check(launch_ready, "launch_ready returns after start deasserts");

    reset = 1'b1;
    step();
    reset = 1'b0;
    clear_program();
    imem[0] = isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd1, ISA_SR_LANE_ID);
    imem[1] = isa_pkg::isa_r_type(ISA_OP_ADD, 4'd2, 4'd1, 4'd1);
    imem[2] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    wait_done();
    check(done && !core_error, "MOVSR lane_id program completes without error");
    debug_read_addr = 4'd2;
    #1;
    check(lane_word(debug_read_data, 0) == 32'd0, "lane 0 doubled lane_id");
    check(lane_word(debug_read_data, 1) == 32'd2, "lane 1 doubled lane_id");
    check(lane_word(debug_read_data, 2) == 32'd4, "lane 2 doubled lane_id");
    check(lane_word(debug_read_data, 3) == 32'd6, "lane 3 doubled lane_id");

    reset = 1'b1;
    step();
    reset = 1'b0;
    launch_active_mask = '1;
    clear_program();
    imem[0] = isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd1, ISA_SR_LANE_ID);
    imem[1] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd4);
    imem[2] = isa_pkg::isa_r_type(ISA_OP_MUL, 4'd1, 4'd1, 4'd2);
    imem[3] = isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd2, ISA_SR_LANE_ID);
    imem[4] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd3, 4'd0, 18'd10);
    imem[5] = isa_pkg::isa_r_type(ISA_OP_ADD, 4'd2, 4'd2, 4'd3);
    imem[6] = isa_pkg::isa_m_type(ISA_OP_STORE, 4'd2, 4'd1, 18'd16);
    imem[7] = isa_pkg::isa_m_type(ISA_OP_LOAD, 4'd4, 4'd1, 18'd16);
    imem[8] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
    pulse_start();
    expect_next_mem_req(1'b1, 32'd16, "lane 0 STORE uses offset");
    expect_next_mem_req(1'b1, 32'd20, "lane 1 STORE uses offset");
    expect_next_mem_req(1'b1, 32'd24, "lane 2 STORE uses offset");
    expect_next_mem_req(1'b1, 32'd28, "lane 3 STORE uses offset");
    expect_next_mem_req(1'b0, 32'd16, "lane 0 LOAD uses offset");
    expect_next_mem_req(1'b0, 32'd20, "lane 1 LOAD uses offset");
    expect_next_mem_req(1'b0, 32'd24, "lane 2 LOAD uses offset");
    expect_next_mem_req(1'b0, 32'd28, "lane 3 LOAD uses offset");
    wait_done();
    check(done && !core_error, "LOAD/STORE program completes without core error");
    check(!data_mem_error, "LOAD/STORE program leaves data memory error low");
    debug_read_addr = 4'd4;
    #1;
    check(lane_word(debug_read_data, 0) == 32'd10, "lane 0 loads its own stored word");
    check(lane_word(debug_read_data, 1) == 32'd11, "lane 1 loads its own stored word");
    check(lane_word(debug_read_data, 2) == 32'd12, "lane 2 loads its own stored word");
    check(lane_word(debug_read_data, 3) == 32'd13, "lane 3 loads its own stored word");

    reset = 1'b1;
    step();
    reset = 1'b0;
    clear_program();
    imem[0] = isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd1, 6'h3F);
    pulse_start();
    wait_done();
    check(core_error && !done, "illegal special register drives core error");

    reset = 1'b1;
    step();
    reset = 1'b0;
    clear_program();
    imem[0] = {6'h3F, 26'd0};
    pulse_start();
    wait_done();
    check(core_error && !done, "illegal opcode drives core error");

    $display("tb_simd_core_basic PASS");
    $finish;
  end
endmodule
