import isa_pkg::*;

module tb_gpu_core_command_predicated_memory;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 64;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] STORE_BASE = 32'h0000_0040;

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
  logic mem_req_seen;
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

  assign mem_req_ready = !mem_rsp_valid || mem_rsp_ready;

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_rsp_id <= '0;
      mem_req_seen <= 1'b0;
    end else begin
      if (mem_req_valid && mem_req_ready) begin
        mem_req_seen <= 1'b1;
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
        mem_rsp_id <= mem_req_id;

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end
    end
  end

  task automatic load_pstore_lane_lt2_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:7];
    begin
      $readmemh("tests/kernels/pstore_lane_lt2.memh", kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic load_pstore_never_taken_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:2];
    begin
      $readmemh("tests/kernels/pstore_never_taken.memh", kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic load_pstore16_all_false_misaligned_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:7];
    begin
      $readmemh("tests/kernels/pstore16_all_false_misaligned.memh", kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic run_current_program(input string scenario);
    begin
      configure_1d_launch(32'h0000_0004, 32'h0000_0000);
      launch_kernel();
      send_word(KGPU_CMD_WAIT_IDLE);
      wait_idle(300, {scenario, " wait_idle timeout"});

      check(error_status == 8'h00, {scenario, " completes without error"});
      check(!busy, {scenario, " leaves gpu_core idle"});
    end
  endtask

  task automatic expect_store_words(
    input logic [31:0] word0,
    input logic [31:0] word1,
    input logic [31:0] word2,
    input logic [31:0] word3,
    input string scenario
  );
    begin
      check(read_memory_word(STORE_BASE + 32'd0) == word0, {scenario, " word 0"});
      check(read_memory_word(STORE_BASE + 32'd4) == word1, {scenario, " word 1"});
      check(read_memory_word(STORE_BASE + 32'd8) == word2, {scenario, " word 2"});
      check(read_memory_word(STORE_BASE + 32'd12) == word3, {scenario, " word 3"});
    end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    mem_rsp_id = '0;
    mem_req_seen = 1'b0;
    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    memory[STORE_BASE[31:2] + 0] = 32'hAAAA_AAAA;
    memory[STORE_BASE[31:2] + 1] = 32'hBBBB_BBBB;
    memory[STORE_BASE[31:2] + 2] = 32'hCCCC_CCCC;
    memory[STORE_BASE[31:2] + 3] = 32'hDDDD_DDDD;

    mem_req_seen = 1'b0;
    load_pstore_lane_lt2_program();
    run_current_program("command PSTORE lane<2");
    check(mem_req_seen, "command PSTORE lane<2 issues selected memory requests");
    expect_store_words(32'h0000_05A5,
                       32'h0000_05A5,
                       32'hCCCC_CCCC,
                       32'hDDDD_DDDD,
                       "command PSTORE lane<2");

    mem_req_seen = 1'b0;
    load_pstore_never_taken_program();
    run_current_program("command all-false PSTORE");
    check(!mem_req_seen, "command all-false PSTORE issues no memory request");
    expect_store_words(32'h0000_05A5,
                       32'h0000_05A5,
                       32'hCCCC_CCCC,
                       32'hDDDD_DDDD,
                       "command all-false PSTORE");

    mem_req_seen = 1'b0;
    load_pstore16_all_false_misaligned_program();
    run_current_program("command all-false misaligned PSTORE16");
    check(!mem_req_seen, "command all-false misaligned PSTORE16 issues no memory request");
    expect_store_words(32'h0000_05A5,
                       32'h0000_05A5,
                       32'hCCCC_CCCC,
                       32'hDDDD_DDDD,
                       "command all-false misaligned PSTORE16");

    $display("tb_gpu_core_command_predicated_memory PASS");
    $finish;
  end
endmodule
