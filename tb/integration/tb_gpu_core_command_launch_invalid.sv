import isa_pkg::*;

module tb_gpu_core_command_launch_invalid;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int IMEM_ADDR_W = 8;

  logic clk;
  logic reset;
  logic enable;
  logic clear_errors;
  logic cmd_valid;
  logic cmd_ready;
  logic [31:0] cmd_data;
  logic imem_write_en;
  logic [7:0] imem_write_addr;
  logic [ISA_WORD_W-1:0] imem_write_data;
  logic busy;
  logic [7:0] error_status;
  logic mem_req_valid;
  logic mem_req_ready;
  logic mem_req_write;
  logic [31:0] mem_req_addr;
  logic [31:0] mem_req_wdata;
  logic [3:0] mem_req_wmask;
  logic mem_rsp_valid;
  logic mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;

  gpu_core #(
      .FB_WIDTH(4),
      .FB_HEIGHT(1),
      .FIFO_DEPTH(16)
  ) dut (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .clear_errors(clear_errors),
      .cmd_valid(cmd_valid),
      .cmd_ready(cmd_ready),
      .cmd_data(cmd_data),
      .imem_write_en(imem_write_en),
      .imem_write_addr(imem_write_addr),
      .imem_write_data(imem_write_data),
      .busy(busy),
      .error_status(error_status),
      .mem_req_valid(mem_req_valid),
      .mem_req_ready(mem_req_ready),
      .mem_req_write(mem_req_write),
      .mem_req_addr(mem_req_addr),
      .mem_req_wdata(mem_req_wdata),
      .mem_req_wmask(mem_req_wmask),
      .mem_rsp_valid(mem_rsp_valid),
      .mem_rsp_ready(mem_rsp_ready),
      .mem_rsp_rdata(mem_rsp_rdata)
  );

  assign mem_req_ready = !mem_rsp_valid || mem_rsp_ready;

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
    end else begin
      if (mem_req_valid && mem_req_ready) begin
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= '0;
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end
    end
  end

  task automatic reset_errors;
  begin
    set_reg(KGPU_REG_CONTROL, KGPU_CONTROL_SOFT_RESET);
    wait_error_clear(20, "soft reset clears invalid launch status");
    repeat (2) begin
      step();
    end
  end
  endtask

  task automatic expect_invalid_launch(input string message);
    int timeout;
  begin
    launch_kernel();
    check(!dut.u_command_processor.launch_start, "invalid launch does not pulse command launch_start");
    timeout = 0;
    while ((error_status & KGPU_ERR_LAUNCH_INVALID) == 8'h00) begin
      check(timeout < 20, message);
      check(!dut.u_command_processor.launch_start, "invalid launch keeps command launch_start low");
      timeout = timeout + 1;
      step();
    end
    check(!dut.u_command_processor.launch_start, "invalid launch never starts programmable core");
    check(error_status == KGPU_ERR_LAUNCH_INVALID, message);
    wait_idle(20, "invalid launch returns idle");
  end
  endtask

  task automatic load_empty_kernel_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:0];
    begin
      kernel_words[0] = kgpu_end();
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;

    step();
    reset = 1'b0;
    step();

    load_empty_kernel_program();

    send_word(32'h5501_0000);
    wait_idle(20, "unknown opcode returns idle");
    check(error_status == KGPU_ERR_UNKNOWN_OPCODE, "unknown opcode reaches gpu_core error status");
    reset_errors();

    send_word(32'h2002_0000);
    check(!dut.u_command_processor.launch_start, "bad-count LAUNCH_KERNEL does not pulse launch_start");
    send_word(KGPU_CMD_SET_REGISTER);
    check(!dut.u_command_processor.launch_start,
          "bad-count LAUNCH_KERNEL skipped payload does not pulse launch_start");
    wait_idle(20, "bad-count LAUNCH_KERNEL skip returns idle");
    check(error_status == KGPU_ERR_BAD_WORD_COUNT,
          "bad-count LAUNCH_KERNEL reaches gpu_core error status");
    reset_errors();

    send_word(32'h2001_0001);
    check(!dut.u_command_processor.launch_start, "reserved LAUNCH_KERNEL does not pulse launch_start");
    wait_idle(20, "reserved LAUNCH_KERNEL returns idle");
    check(error_status == KGPU_ERR_BAD_RESERVED,
          "reserved LAUNCH_KERNEL reaches gpu_core error status");
    reset_errors();

    configure_launch(32'h0000_0000, 32'h0000_0000, 32'h0000_0001, 32'h0000_0000);
    wait_idle(40, "zero-grid launch registers drain");
    expect_invalid_launch("zero GRID_X sets launch-invalid");
    reset_errors();

    configure_launch(32'h0000_0000, 32'h0000_0001, 32'h0000_0000, 32'h0000_0000);
    wait_idle(40, "zero-grid-y launch registers drain");
    expect_invalid_launch("zero GRID_Y sets launch-invalid");
    reset_errors();

    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    set_reg(KGPU_REG_GROUP_SIZE_X, 32'h0000_0008);
    wait_idle(40, "unsupported-group launch registers drain");
    expect_invalid_launch("unsupported GROUP_SIZE_X sets launch-invalid");
    reset_errors();

    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    set_reg(KGPU_REG_GROUP_SIZE_Y, 32'h0000_0002);
    wait_idle(40, "unsupported-group-y launch registers drain");
    expect_invalid_launch("unsupported GROUP_SIZE_Y sets launch-invalid");
    reset_errors();

    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    set_reg(KGPU_REG_LAUNCH_FLAGS, 32'h0000_0001);
    wait_idle(40, "launch-flags registers drain");
    expect_invalid_launch("nonzero LAUNCH_FLAGS sets launch-invalid");
    reset_errors();

    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    wait_idle(40, "valid launch registers drain");
    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(40, "valid launch after invalid attempts completes");
    check(error_status == 8'h00, "valid launch leaves error status clear");

    $display("tb_gpu_core_command_launch_invalid PASS");
    $finish;
  end
endmodule
