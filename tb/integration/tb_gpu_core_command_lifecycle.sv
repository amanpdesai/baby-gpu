import isa_pkg::*;

module tb_gpu_core_command_lifecycle;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 8;
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
  logic hold_rsp;
  logic pending_rsp;
  logic saw_mem_req;
  logic [31:0] pending_rdata;
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
      .mem_rsp_valid(mem_rsp_valid),
      .mem_rsp_ready(mem_rsp_ready),
      .mem_rsp_rdata(mem_rsp_rdata)
  );

  assign mem_req_ready = !pending_rsp && (!mem_rsp_valid || mem_rsp_ready);

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      pending_rsp <= 1'b0;
      pending_rdata <= '0;
      saw_mem_req <= 1'b0;
    end else begin
      if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end

      if (mem_req_valid && mem_req_ready) begin
        saw_mem_req <= 1'b1;
        pending_rsp <= 1'b1;
        pending_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (pending_rsp && !hold_rsp && (!mem_rsp_valid || mem_rsp_ready)) begin
        pending_rsp <= 1'b0;
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= pending_rdata;
      end
    end
  end

  task automatic wait_for_mem_req;
    int timeout;
  begin
    timeout = 0;
    while (!saw_mem_req) begin
      check(timeout < 100, "command lifecycle memory request timeout");
      timeout = timeout + 1;
      step();
    end
  end
  endtask

  task automatic wait_error(input logic [7:0] mask, input string message);
    int timeout;
  begin
    timeout = 0;
    while ((error_status & mask) == 8'h00) begin
      check(timeout < 100, message);
      timeout = timeout + 1;
      step();
    end
  end
  endtask

  task automatic load_stalling_load_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:2];
    begin
      kernel_words[0] = kgpu_movi(4'd1, 18'd0);
      kernel_words[1] = kgpu_load(4'd2, 4'd1, 18'd0);
      kernel_words[2] = kgpu_end();
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    hold_rsp = 1'b0;
    pending_rsp = 1'b0;
    pending_rdata = '0;
    saw_mem_req = 1'b0;

    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      memory[i] = 32'h1000_0000 + 32'(i);
    end

    step();
    reset = 1'b0;
    step();

    load_stalling_load_program();

    hold_rsp = 1'b1;
    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    launch_kernel();
    wait_for_mem_req();

    check(busy, "kernel remains busy while memory response is held");
    launch_kernel();
    wait_error(KGPU_ERR_DISPATCH_BUSY, "second launch while busy sets dispatch-busy");
    check(error_status == KGPU_ERR_DISPATCH_BUSY, "only dispatch-busy is set after busy launch");

    send_word(KGPU_CMD_WAIT_IDLE);
    step();
    check(busy, "WAIT_IDLE keeps gpu_core busy while kernel is active");
    repeat (4) begin
      step();
      check(busy, "WAIT_IDLE remains blocked while memory response is held");
    end

    hold_rsp = 1'b0;
    wait_idle(200, "WAIT_IDLE retires after held memory response completes");
    check(!pending_rsp, "held memory response drains");
    check(error_status == KGPU_ERR_DISPATCH_BUSY, "dispatch-busy remains sticky after kernel completes");

    $display("tb_gpu_core_command_lifecycle PASS");
    $finish;
  end
endmodule
