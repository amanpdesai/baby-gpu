import isa_pkg::*;

module tb_gpu_core_command_branch_control;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 16;
  localparam int IMEM_ADDR_W = 8;
  localparam int BRANCH_WORDS = 13;
  localparam int DIVERGENT_WORDS = 3;
  localparam logic [7:0] ERR_PROGRAMMABLE = 8'h20;

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
      if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end

      if (mem_req_valid && mem_req_ready) begin
        mem_req_seen <= 1'b1;
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
        mem_rsp_id <= mem_req_id;

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end
    end
  end

  function automatic logic [15:0] halfword_at(input int index);
    logic [31:0] word;
    begin
      word = read_memory_word(32'(index * 2));
      halfword_at = (index % 2) == 0 ? word[15:0] : word[31:16];
    end
  endfunction

  task automatic load_branch_program(input string path);
    logic [ISA_WORD_W-1:0] kernel_words [0:BRANCH_WORDS-1];
    begin
      $readmemh(path, kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic load_divergent_branch_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:DIVERGENT_WORDS-1];
    begin
      $readmemh("tests/kernels/branch_divergent_lane_id.memh", kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic run_visible_branch(
    input string path,
    input logic [15:0] expected,
    input string scenario
  );
    begin
      init_memory(32'hCAFE_CAFE);
      mem_req_seen = 1'b0;
      load_branch_program(path);
      configure_1d_launch(32'h0000_0004, 32'h0000_0000);
      launch_kernel();
      send_word(KGPU_CMD_WAIT_IDLE);
      wait_idle(300, {scenario, " wait_idle timeout"});

      check(error_status == 8'h00, {scenario, " completes without error"});
      check(mem_req_seen, {scenario, " issues visible memory writes"});
      for (int lane = 0; lane < 4; lane++) begin
        check(halfword_at(lane) == expected, {scenario, " writes expected branch value"});
      end
      check(halfword_at(4) == 16'hCAFE, {scenario, " leaves trailing sentinel untouched"});
      check(!busy, {scenario, " leaves gpu_core idle"});
    end
  endtask

  task automatic wait_programmable_error(input string message);
    int timeout;
    begin
      timeout = 0;
      while ((error_status & ERR_PROGRAMMABLE) == 8'h00) begin
        check(timeout < 120, message);
        timeout = timeout + 1;
        step();
      end
    end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    mem_rsp_id = '0;
    mem_req_seen = 1'b0;
    init_memory(32'hCAFE_CAFE);

    step();
    reset = 1'b0;
    step();

    run_visible_branch("tests/kernels/branch_taken_store16.memh",
                       16'h2222,
                       "command taken branch");

    run_visible_branch("tests/kernels/branch_not_taken_store16.memh",
                       16'h1111,
                       "command not-taken branch");

    mem_req_seen = 1'b0;
    load_divergent_branch_program();
    configure_1d_launch(32'h0000_0004, 32'h0000_0000);
    launch_kernel();
    wait_programmable_error("command divergent branch fault timeout");

    check(error_status == ERR_PROGRAMMABLE,
          "command divergent branch sets only programmable error bit");
    check(!mem_req_seen, "command divergent branch issues no memory request");
    check(busy, "command divergent branch keeps gpu_core busy while fault is sticky");

    $display("tb_gpu_core_command_branch_control PASS");
    $finish;
  end
endmodule
