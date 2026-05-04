import isa_pkg::*;

module tb_gpu_core_command_program_base;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 32;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] PROGRAM_BASE = 32'h0000_0005;
  localparam logic [31:0] ARG_BASE = 32'h0000_0020;
  localparam logic [15:0] COLOR = 16'h4C3D;

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
  logic saw_mem_req;
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

  initial begin
    forever #5 clk = ~clk;
  end

  always_comb begin
    mem_req_ready = !mem_rsp_valid || mem_rsp_ready;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      saw_mem_req <= 1'b0;
    end else begin
      if (mem_req_valid && mem_req_ready) begin
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
        saw_mem_req <= 1'b1;

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end
    end
  end

  function automatic logic [15:0] pixel_at(input int x);
    logic [31:0] word;
  begin
    word = read_memory_word(ARG_BASE + 32'(x * 2));
    if ((x % 2) == 0) begin
      pixel_at = word[15:0];
    end else begin
      pixel_at = word[31:16];
    end
  end
  endfunction

  task automatic load_program_base_kernel;
    logic [ISA_WORD_W-1:0] kernel_words [0:7];
  begin
    kernel_words[0] = kgpu_movsr(4'd1, ISA_SR_LINEAR_GLOBAL_ID);
    kernel_words[1] = kgpu_movi(4'd2, 18'd2);
    kernel_words[2] = kgpu_mul(4'd3, 4'd1, 4'd2);
    kernel_words[3] = kgpu_movsr(4'd4, ISA_SR_ARG_BASE);
    kernel_words[4] = kgpu_add(4'd5, 4'd4, 4'd3);
    kernel_words[5] = kgpu_movi(4'd6, 18'(COLOR));
    kernel_words[6] = kgpu_store16(4'd6, 4'd5, 18'd0);
    kernel_words[7] = kgpu_end();
    `KGPU_LOAD_PROGRAM_AT(PROGRAM_BASE[7:0], kernel_words)
  end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    saw_mem_req = 1'b0;

    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    write_imem(8'd0, kgpu_end());
    write_imem(8'd1, kgpu_end());
    load_program_base_kernel();

    configure_launch(PROGRAM_BASE, 32'h0000_0004, 32'h0000_0001, ARG_BASE);

    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(200, "nonzero PROGRAM_BASE command kernel timed out");

    check(error_status == 8'h00, "nonzero PROGRAM_BASE kernel completes without errors");
    check(saw_mem_req, "nonzero PROGRAM_BASE kernel reaches memory path");
    check(pixel_at(0) == COLOR, "nonzero PROGRAM_BASE writes pixel 0");
    check(pixel_at(1) == COLOR, "nonzero PROGRAM_BASE writes pixel 1");
    check(pixel_at(2) == COLOR, "nonzero PROGRAM_BASE writes pixel 2");
    check(pixel_at(3) == COLOR, "nonzero PROGRAM_BASE writes pixel 3");
    check(memory[(ARG_BASE >> 2) - 1] == 32'hDEAD_DEAD,
          "nonzero PROGRAM_BASE leaves preceding sentinel unchanged");
    check(memory[(ARG_BASE >> 2) + 2] == 32'hDEAD_DEAD,
          "nonzero PROGRAM_BASE leaves following sentinel unchanged");

    $display("tb_gpu_core_command_program_base PASS");
    $finish;
  end
endmodule
