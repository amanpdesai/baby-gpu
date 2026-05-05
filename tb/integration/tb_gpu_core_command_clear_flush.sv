import isa_pkg::*;

module tb_gpu_core_command_clear_flush;
  import kernel_asm_pkg::*;

  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 8;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] INITIAL_ARG_BASE = 32'h0000_0000;
  localparam logic [31:0] FLUSHED_ARG_BASE = 32'h0000_0040;
  localparam logic [31:0] RECOVERY_ARG_BASE = 32'h0000_0080;

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

  `include "tb/common/gpu_core_memory_helpers.svh"

  gpu_core #(
      .FB_WIDTH(4),
      .FB_HEIGHT(1),
      .FIFO_DEPTH(8)
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

  always #5 clk = ~clk;

  assign mem_req_ready = !pending_rsp && (!mem_rsp_valid || mem_rsp_ready);

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
        mem_rsp_rdata <= '0;
      end

      if (!mem_rsp_valid && pending_rsp && !hold_rsp) begin
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= pending_rdata;
        pending_rsp <= 1'b0;
        pending_rdata <= '0;
      end

      if (mem_req_valid && mem_req_ready) begin
        saw_mem_req <= 1'b1;
        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end else if (hold_rsp) begin
          pending_rsp <= 1'b1;
          pending_rdata <= read_memory_word(mem_req_addr);
        end else begin
          mem_rsp_valid <= 1'b1;
          mem_rsp_rdata <= read_memory_word(mem_req_addr);
        end
      end
    end
  end

  task automatic wait_mem_req(input string message);
    int timeout;
    begin
      timeout = 0;
      while (!saw_mem_req) begin
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
    init_memory(32'hCAFE_0000);

    step();
    reset = 1'b0;
    step();

    load_stalling_load_program();
    configure_1d_launch(32'h0000_0001, INITIAL_ARG_BASE);
    wait_idle(40, "launch register setup drains");

    hold_rsp = 1'b1;
    launch_kernel();
    wait_mem_req("kernel reaches held memory request");

    send_word(KGPU_CMD_WAIT_IDLE);
    set_reg(KGPU_REG_ARG_BASE, FLUSHED_ARG_BASE);
    repeat (4) begin
      step();
      check(dut.register_launch_arg_base == INITIAL_ARG_BASE,
            "queued SET_REGISTER does not retire behind blocked WAIT_IDLE");
    end

    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(dut.register_launch_arg_base == INITIAL_ARG_BASE,
          "clear_errors does not retire flushed queued SET_REGISTER");

    hold_rsp = 1'b0;
    wait_idle(100, "held kernel drains after command clear");
    check(error_status == 8'h00, "command clear leaves no sticky errors");
    check(dut.register_launch_arg_base == INITIAL_ARG_BASE,
          "flushed SET_REGISTER stays discarded after kernel completion");

    set_reg(KGPU_REG_ARG_BASE, RECOVERY_ARG_BASE);
    wait_idle(40, "post-clear command stream accepts new SET_REGISTER");
    step();
    check(dut.register_launch_arg_base == RECOVERY_ARG_BASE,
          "post-clear SET_REGISTER retires after FIFO flush");

    $display("tb_gpu_core_command_clear_flush PASS");
    $finish;
  end
endmodule
