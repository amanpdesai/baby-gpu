import isa_pkg::*;

module tb_gpu_core_command_program_base_snapshot;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 128;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] OLD_PROGRAM_BASE = 32'h0000_0005;
  localparam logic [31:0] NEW_PROGRAM_BASE = 32'h0000_0020;
  localparam logic [31:0] OLD_OUT_BASE = 32'h0000_0080;
  localparam logic [31:0] NEW_OUT_BASE = 32'h0000_00A0;
  localparam logic [15:0] OLD_COLOR = 16'h2468;
  localparam logic [15:0] NEW_COLOR = 16'hBEEF;

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
      check(timeout < 100, "program-base-snapshot initial memory request timeout");
      timeout = timeout + 1;
      step();
    end
    check(!accepted_req_write, "program-base-snapshot first memory request is a load");
    check(accepted_req_addr == 32'h0000_0000,
          "program-base-snapshot first memory request is the dummy load");
  end
  endtask

  task automatic wait_for_program_base_rewrite;
    int timeout;
  begin
    timeout = 0;
    while (dut.register_launch_program_base != NEW_PROGRAM_BASE) begin
      check(timeout < 60, "post-launch PROGRAM_BASE rewrite reaches register file");
      timeout = timeout + 1;
      step();
    end
    check(busy, "kernel remains active after PROGRAM_BASE rewrite completes");
    check(hold_rsp, "kernel response remains held after PROGRAM_BASE rewrite completes");
  end
  endtask

  task automatic load_old_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:9];
    begin
      $readmemh("tests/kernels/program_base_snapshot_old.memh", kernel_words);
      `KGPU_LOAD_PROGRAM_AT(OLD_PROGRAM_BASE[7:0], kernel_words)
    end
  endtask

  task automatic load_new_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:7];
    begin
      $readmemh("tests/kernels/program_base_snapshot_new.memh", kernel_words);
      `KGPU_LOAD_PROGRAM_AT(NEW_PROGRAM_BASE[7:0] + 8'd1, kernel_words)
    end
  endtask

  task automatic load_empty_kernel_at(input logic [IMEM_ADDR_W-1:0] addr);
    logic [ISA_WORD_W-1:0] kernel_words [0:0];
    begin
      $readmemh("tests/kernels/empty.memh", kernel_words);
      `KGPU_LOAD_PROGRAM_AT(addr, kernel_words)
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

    step();
    reset = 1'b0;
    step();

    load_empty_kernel_at(8'd0);
    load_empty_kernel_at(OLD_PROGRAM_BASE[7:0] - 8'd1);
    load_empty_kernel_at(NEW_PROGRAM_BASE[7:0]);
    load_old_program();
    load_new_program();

    hold_rsp = 1'b1;
    configure_launch(OLD_PROGRAM_BASE, 32'h0000_0004, 32'h0000_0001, 32'h0000_0000);
    launch_kernel();
    wait_for_first_mem_req();

    set_reg(KGPU_REG_PROGRAM_BASE, NEW_PROGRAM_BASE);
    wait_for_program_base_rewrite();

    hold_rsp = 1'b0;
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(400, "program-base-snapshot kernel timed out");

    check(error_status == 8'h00, "program-base-snapshot kernel completes without errors");
    check(memory[OLD_OUT_BASE[31:2]][15:0] == OLD_COLOR,
          "latched PROGRAM_BASE writes old output pixel 0");
    check(memory[OLD_OUT_BASE[31:2]][31:16] == OLD_COLOR,
          "latched PROGRAM_BASE writes old output pixel 1");
    check(memory[OLD_OUT_BASE[31:2] + 1][15:0] == OLD_COLOR,
          "latched PROGRAM_BASE writes old output pixel 2");
    check(memory[OLD_OUT_BASE[31:2] + 1][31:16] == OLD_COLOR,
          "latched PROGRAM_BASE writes old output pixel 3");
    check(memory[NEW_OUT_BASE[31:2]] == 32'hDEAD_DEAD,
          "post-launch PROGRAM_BASE rewrite output word 0 stays untouched");
    check(memory[NEW_OUT_BASE[31:2] + 1] == 32'hDEAD_DEAD,
          "post-launch PROGRAM_BASE rewrite output word 1 stays untouched");

    $display("tb_gpu_core_command_program_base_snapshot PASS");
    $finish;
  end
endmodule
