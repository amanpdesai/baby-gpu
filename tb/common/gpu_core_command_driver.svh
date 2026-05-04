localparam logic [31:0] KGPU_CMD_WAIT_IDLE = 32'h0301_0000;
localparam logic [31:0] KGPU_CMD_SET_REGISTER = 32'h1003_0000;
localparam logic [31:0] KGPU_CMD_LAUNCH_KERNEL = 32'h2001_0000;

localparam logic [31:0] KGPU_CONTROL_ENABLE = 32'h0000_0001;
localparam logic [31:0] KGPU_CONTROL_SOFT_RESET = 32'h0000_0002;
localparam logic [31:0] KGPU_CONTROL_CLEAR_ERRORS = 32'h0000_0004;

localparam logic [31:0] KGPU_REG_CONTROL = 32'h0000_000C;
localparam logic [31:0] KGPU_REG_FB_BASE = 32'h0000_0010;
localparam logic [31:0] KGPU_REG_PROGRAM_BASE = 32'h0000_0040;
localparam logic [31:0] KGPU_REG_GRID_X = 32'h0000_0044;
localparam logic [31:0] KGPU_REG_GRID_Y = 32'h0000_0048;
localparam logic [31:0] KGPU_REG_GROUP_SIZE_X = 32'h0000_004C;
localparam logic [31:0] KGPU_REG_GROUP_SIZE_Y = 32'h0000_0050;
localparam logic [31:0] KGPU_REG_ARG_BASE = 32'h0000_0054;
localparam logic [31:0] KGPU_REG_LAUNCH_FLAGS = 32'h0000_0058;

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

task automatic write_imem(input logic [7:0] addr, input logic [isa_pkg::ISA_WORD_W-1:0] word);
begin
  imem_write_addr = addr;
  imem_write_data = word;
  imem_write_en = 1'b1;
  step();
  imem_write_en = 1'b0;
  imem_write_addr = '0;
  imem_write_data = '0;
end
endtask

task automatic send_word(input logic [31:0] word);
begin
  cmd_data = word;
  cmd_valid = 1'b1;
  while (!cmd_ready) begin
    step();
  end
  step();
  cmd_valid = 1'b0;
  cmd_data = '0;
end
endtask

task automatic set_reg(input logic [31:0] addr, input logic [31:0] data);
begin
  send_word(KGPU_CMD_SET_REGISTER);
  send_word(addr);
  send_word(data);
end
endtask

task automatic configure_launch(input logic [31:0] program_base,
                                input logic [31:0] grid_x,
                                input logic [31:0] grid_y,
                                input logic [31:0] arg_base);
begin
  set_reg(KGPU_REG_PROGRAM_BASE, program_base);
  set_reg(KGPU_REG_GRID_X, grid_x);
  set_reg(KGPU_REG_GRID_Y, grid_y);
  set_reg(KGPU_REG_GROUP_SIZE_X, 32'h0000_0004);
  set_reg(KGPU_REG_GROUP_SIZE_Y, 32'h0000_0001);
  set_reg(KGPU_REG_ARG_BASE, arg_base);
  set_reg(KGPU_REG_LAUNCH_FLAGS, 32'h0000_0000);
end
endtask

task automatic launch_kernel;
begin
  send_word(KGPU_CMD_LAUNCH_KERNEL);
end
endtask

task automatic wait_idle(input int max_cycles, input string message);
  int timeout;
begin
  timeout = 0;
  while (busy) begin
    step();
    timeout = timeout + 1;
    check(timeout < max_cycles, message);
  end
end
endtask

task automatic wait_error_clear(input int max_cycles, input string message);
  int timeout;
begin
  timeout = 0;
  while (error_status != 8'h00) begin
    step();
    timeout = timeout + 1;
    check(timeout < max_cycles, message);
  end
end
endtask
