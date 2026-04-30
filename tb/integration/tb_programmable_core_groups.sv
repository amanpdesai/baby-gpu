import isa_pkg::*;

module tb_programmable_core_groups;
  localparam int LANES = 4;
  localparam int DATA_W = 32;
  localparam int COORD_W = 16;
  localparam int ADDR_W = 32;
  localparam int PC_W = 8;
  localparam int REGS = 16;
  localparam int REG_ADDR_W = $clog2(REGS);
  localparam int IMEM_ADDR_W = PC_W;

  logic clk;
  logic reset;
  logic launch_valid;
  logic launch_ready;
  logic [COORD_W-1:0] grid_x;
  logic [COORD_W-1:0] grid_y;
  logic [ADDR_W-1:0] arg_base;
  logic [ADDR_W-1:0] framebuffer_base;
  logic [COORD_W-1:0] framebuffer_width;
  logic [COORD_W-1:0] framebuffer_height;
  logic [PC_W-1:0] instruction_addr;
  logic [ISA_WORD_W-1:0] instruction;
  logic busy;
  logic done;
  logic error;
  logic data_req_valid;
  logic data_req_ready;
  logic data_req_write;
  logic [ADDR_W-1:0] data_req_addr;
  logic [31:0] data_req_wdata;
  logic [3:0] data_req_wmask;
  logic data_rsp_valid;
  logic data_rsp_ready;
  logic [31:0] data_rsp_rdata;
  logic [REG_ADDR_W-1:0] debug_read_addr;
  logic [(LANES*DATA_W)-1:0] debug_read_data;
  logic imem_write_en;
  logic [IMEM_ADDR_W-1:0] imem_write_addr;
  logic [ISA_WORD_W-1:0] imem_write_data;
  logic imem_fetch_error;

  programmable_core #(
      .LANES(LANES),
      .DATA_W(DATA_W),
      .COORD_W(COORD_W),
      .ADDR_W(ADDR_W),
      .PC_W(PC_W),
      .REGS(REGS),
      .REG_ADDR_W(REG_ADDR_W)
  ) dut (
      .clk(clk),
      .reset(reset),
      .launch_valid(launch_valid),
      .launch_ready(launch_ready),
      .grid_x(grid_x),
      .grid_y(grid_y),
      .arg_base(arg_base),
      .framebuffer_base(framebuffer_base),
      .framebuffer_width(framebuffer_width),
      .framebuffer_height(framebuffer_height),
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
      .busy(busy),
      .done(done),
      .error(error),
      .debug_read_addr(debug_read_addr),
      .debug_read_data(debug_read_data)
  );

  assign data_req_ready = 1'b1;
  assign data_rsp_valid = 1'b0;
  assign data_rsp_rdata = '0;

  instruction_memory #(
      .WORD_W(ISA_WORD_W),
      .ADDR_W(IMEM_ADDR_W)
  ) imem (
      .clk(clk),
      .write_en(imem_write_en),
      .write_addr(imem_write_addr),
      .write_data(imem_write_data),
      .fetch_addr(instruction_addr),
      .fetch_instruction(instruction),
      .fetch_error(imem_fetch_error)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [DATA_W-1:0] lane_data(input int lane);
    lane_data = debug_read_data[(lane*DATA_W)+:DATA_W];
  endfunction

  task automatic step();
    @(posedge clk);
    #1;
  endtask

  task automatic write_imem(input logic [IMEM_ADDR_W-1:0] addr,
                            input logic [ISA_WORD_W-1:0] word);
    begin
      imem_write_en = 1'b1;
      imem_write_addr = addr;
      imem_write_data = word;
      step();
      imem_write_en = 1'b0;
      imem_write_addr = '0;
      imem_write_data = '0;
      step();
    end
  endtask

  task automatic launch(input logic [COORD_W-1:0] launch_grid_x,
                        input logic [COORD_W-1:0] launch_grid_y);
    int cycles;
    begin
      grid_x = launch_grid_x;
      grid_y = launch_grid_y;
      launch_valid = 1'b1;
      cycles = 0;
      while (!launch_ready) begin
        check(!error, "core stays out of error while waiting to launch");
        check(cycles < 20, "launch_ready timeout");
        cycles = cycles + 1;
        step();
      end
      step();
      launch_valid = 1'b0;
    end
  endtask

  task automatic wait_done();
    int cycles;
    begin
      cycles = 0;
      while (!done) begin
        check(!error, "core stays out of error while running");
        check(!imem_fetch_error, "instruction fetch remains in range");
        check(cycles < 200, "programmable core timeout");
        cycles = cycles + 1;
        step();
      end
      check(!error, "programmable core completes without error");
      step();
    end
  endtask

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $error("CHECK FAILED: %s", message);
        $fatal(1);
      end
    end
  endtask

  initial begin
    reset = 1'b1;
    launch_valid = 1'b0;
    grid_x = '0;
    grid_y = '0;
    arg_base = 32'h0000_1000;
    framebuffer_base = 32'h0002_0000;
    framebuffer_width = 16'd64;
    framebuffer_height = 16'd32;
    debug_read_addr = '0;
    imem_write_en = 1'b0;
    imem_write_addr = '0;
    imem_write_data = '0;

    step();
    write_imem(8'd0, isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd1, ISA_SR_LINEAR_GLOBAL_ID));
    write_imem(8'd1, isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd2, ISA_SR_GLOBAL_ID_X));
    write_imem(8'd2, isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd3, ISA_SR_GLOBAL_ID_Y));
    write_imem(8'd3, isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0));

    reset = 1'b0;
    step();

    launch(16'd5, 16'd1);
    wait_done();

    debug_read_addr = 4'd1;
    #1;
    check(lane_data(0) == 32'd4, "second group writes lane 0 linear_global_id");
    check(lane_data(1) == 32'd1, "inactive tail lane 1 preserves prior linear_global_id");
    check(lane_data(2) == 32'd2, "inactive tail lane 2 preserves prior linear_global_id");
    check(lane_data(3) == 32'd3, "inactive tail lane 3 preserves prior linear_global_id");

    debug_read_addr = 4'd2;
    #1;
    check(lane_data(0) == 32'd4, "second group writes lane 0 global_id_x");
    check(lane_data(1) == 32'd1, "inactive tail lane 1 preserves prior global_id_x");
    check(lane_data(2) == 32'd2, "inactive tail lane 2 preserves prior global_id_x");
    check(lane_data(3) == 32'd3, "inactive tail lane 3 preserves prior global_id_x");

    debug_read_addr = 4'd3;
    #1;
    check(lane_data(0) == 32'd0, "global_id_y is zero for the second group");
    check(lane_data(1) == 32'd0, "inactive tail lane 1 preserves prior global_id_y");
    check(lane_data(2) == 32'd0, "inactive tail lane 2 preserves prior global_id_y");
    check(lane_data(3) == 32'd0, "inactive tail lane 3 preserves prior global_id_y");

    check(!busy, "programmable core returns idle after grouped launch");
    check(launch_ready, "programmable core can accept another launch");
    check(!error, "programmable core leaves error low");

    $display("tb_programmable_core_groups PASS");
    $finish;
  end
endmodule
