import isa_pkg::*;

module tb_gpu_core_command_launch_snapshot;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 128;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] OLD_ARG_BASE = 32'h0000_0040;
  localparam logic [31:0] NEW_ARG_BASE = 32'h0000_0050;
  localparam logic [31:0] OLD_OUT_BASE = 32'h0000_0080;
  localparam logic [31:0] NEW_OUT_BASE = 32'h0000_00A0;
  localparam logic [15:0] OLD_COLOR = 16'h1357;
  localparam logic [15:0] NEW_COLOR = 16'hCAFE;

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
logic [1:0] mem_req_id;
  logic mem_rsp_valid;
  logic mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;
logic [1:0] mem_rsp_id;
  logic hold_rsp;
  logic pending_rsp;
  logic saw_mem_req;
  logic accepted_req_write;
  logic [31:0] accepted_req_addr;
  logic [31:0] pending_rdata;
logic [1:0] pending_rsp_id;
  logic [31:0] memory [0:MEM_WORDS-1];
  int i;

  `include "tb/common/gpu_core_memory_helpers.svh"

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
        .mem_req_id(mem_req_id),
    .mem_rsp_valid(mem_rsp_valid),
    .mem_rsp_ready(mem_rsp_ready),
    .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_id(mem_rsp_id)
  );

  initial begin
    forever #5 clk = ~clk;
  end

  always_comb begin
    mem_req_ready = !pending_rsp;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_rsp_id <= '0;
      pending_rsp <= 1'b0;
      pending_rdata <= '0;
      pending_rsp_id <= '0;
      saw_mem_req <= 1'b0;
      accepted_req_write <= 1'b0;
      accepted_req_addr <= '0;
    end else begin
      if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end

      if (mem_req_valid && mem_req_ready) begin
        saw_mem_req <= 1'b1;
        accepted_req_write <= mem_req_write;
        accepted_req_addr <= mem_req_addr;
        pending_rsp <= 1'b1;
        pending_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
      pending_rsp_id <= mem_req_id;

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (pending_rsp && !hold_rsp && (!mem_rsp_valid || mem_rsp_ready)) begin
        pending_rsp <= 1'b0;
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= pending_rdata;
      mem_rsp_id <= pending_rsp_id;
      end
    end
  end

  task automatic wait_for_first_mem_req;
    int timeout;
  begin
    timeout = 0;
    while (!saw_mem_req) begin
      check(timeout < 100, "launch-snapshot initial memory request timeout");
      timeout = timeout + 1;
      step();
    end
    check(!accepted_req_write, "launch-snapshot first memory request is a load");
    check(accepted_req_addr == 32'h0000_0000,
          "launch-snapshot first memory request is the dummy load");
  end
  endtask

  task automatic wait_for_arg_base_rewrite;
    int timeout;
  begin
    timeout = 0;
    while (dut.register_launch_arg_base != NEW_ARG_BASE) begin
      check(timeout < 40, "post-launch ARG_BASE rewrite reaches register file");
      timeout = timeout + 1;
      step();
    end
    check(busy, "kernel remains active after ARG_BASE rewrite completes");
    check(hold_rsp, "kernel response remains held after ARG_BASE rewrite completes");
  end
  endtask

  task automatic load_snapshot_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:10];
  begin
    $readmemh("tests/kernels/launch_arg_snapshot_store16.memh", kernel_words);
    `KGPU_LOAD_PROGRAM(kernel_words)
  end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
mem_rsp_id = '0;
    hold_rsp = 1'b0;
    pending_rsp = 1'b0;
    pending_rdata = '0;
  pending_rsp_id = '0;
    saw_mem_req = 1'b0;
    accepted_req_write = 1'b0;
    accepted_req_addr = '0;

    init_memory(32'hDEAD_DEAD);
    memory[0] = 32'hA5A5_5A5A;
    memory[OLD_ARG_BASE[31:2]] = OLD_OUT_BASE;
    memory[OLD_ARG_BASE[31:2] + 1] = 32'(OLD_COLOR);
    memory[NEW_ARG_BASE[31:2]] = NEW_OUT_BASE;
    memory[NEW_ARG_BASE[31:2] + 1] = 32'(NEW_COLOR);

    step();
    reset = 1'b0;
    step();

    load_snapshot_program();

    hold_rsp = 1'b1;
    configure_1d_launch(32'h0000_0004, OLD_ARG_BASE);
    launch_kernel();
    wait_for_first_mem_req();

    set_reg(KGPU_REG_ARG_BASE, NEW_ARG_BASE);
    wait_for_arg_base_rewrite();

    hold_rsp = 1'b0;
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(400, "launch-snapshot kernel timed out");

    check(error_status == 8'h00, "launch-snapshot kernel completes without errors");
    check(memory[OLD_OUT_BASE[31:2]][15:0] == OLD_COLOR,
          "latched ARG_BASE writes old output pixel 0");
    check(memory[OLD_OUT_BASE[31:2]][31:16] == OLD_COLOR,
          "latched ARG_BASE writes old output pixel 1");
    check(memory[OLD_OUT_BASE[31:2] + 1][15:0] == OLD_COLOR,
          "latched ARG_BASE writes old output pixel 2");
    check(memory[OLD_OUT_BASE[31:2] + 1][31:16] == OLD_COLOR,
          "latched ARG_BASE writes old output pixel 3");
    check(memory[NEW_OUT_BASE[31:2]] == 32'hDEAD_DEAD,
          "post-launch ARG_BASE rewrite output word 0 stays untouched");
    check(memory[NEW_OUT_BASE[31:2] + 1] == 32'hDEAD_DEAD,
          "post-launch ARG_BASE rewrite output word 1 stays untouched");

    $display("tb_gpu_core_command_launch_snapshot PASS");
    $finish;
  end
endmodule
