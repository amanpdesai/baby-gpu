import isa_pkg::*;

module tb_gpu_core_command_illegal_instruction;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int IMEM_ADDR_W = 8;
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
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_req_seen <= 1'b0;
    end else if (mem_req_valid && mem_req_ready) begin
      mem_req_seen <= 1'b1;
    end
  end

  task automatic load_one_word_program(input string path);
    logic [ISA_WORD_W-1:0] kernel_words [0:0];
    begin
      $readmemh(path, kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  task automatic wait_programmable_error(input string message);
    int timeout;
    begin
      timeout = 0;
      while ((error_status & ERR_PROGRAMMABLE) == 8'h00) begin
        check(timeout < 200, message);
        timeout = timeout + 1;
        step();
      end
    end
  endtask

  task automatic wait_dispatch_busy(input string message);
    int timeout;
    begin
      timeout = 0;
      while ((error_status & KGPU_ERR_DISPATCH_BUSY) == 8'h00) begin
        check(timeout < 20, message);
        timeout = timeout + 1;
        step();
      end
    end
  endtask

  task automatic soft_reset_and_check(input string scenario);
    begin
      set_reg(KGPU_REG_CONTROL, KGPU_CONTROL_SOFT_RESET);
      wait_error_clear(20, {scenario, " soft reset clears status"});
      check(!busy, {scenario, " soft reset returns gpu_core idle"});
    end
  endtask

  task automatic run_malformed_instruction(input string path, input string scenario);
    begin
      mem_req_seen = 1'b0;
      load_one_word_program(path);
      configure_1d_launch(32'h0000_0001, 32'h0000_0000);
      launch_kernel();
      wait_programmable_error({scenario, " programmable error timeout"});

      check(error_status == ERR_PROGRAMMABLE,
            {scenario, " sets only programmable error bit"});
      check(!mem_req_seen, {scenario, " issues no memory request"});
      check(busy, {scenario, " leaves gpu_core busy while fault is sticky"});
    end
  endtask

  initial begin
    init_command_driver();
    mem_req_ready = 1'b1;
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    mem_rsp_id = '0;
    mem_req_seen = 1'b0;

    step();
    reset = 1'b0;
    step();

    run_malformed_instruction("tests/kernels/illegal_opcode_raw.memh",
                              "illegal opcode");

    launch_kernel();
    wait_dispatch_busy("launch during sticky programmable error timeout");
    check(error_status == (ERR_PROGRAMMABLE | KGPU_ERR_DISPATCH_BUSY),
          "launch during sticky programmable error reports dispatch busy");
    check(!mem_req_seen, "rejected launch after illegal instruction issues no request");

    soft_reset_and_check("illegal opcode");

    run_malformed_instruction("tests/kernels/illegal_special_register_raw.memh",
                              "illegal special register");
    soft_reset_and_check("illegal special register");

    run_malformed_instruction("tests/kernels/reserved_cmp_payload_raw.memh",
                              "reserved CMP payload");
    soft_reset_and_check("reserved CMP payload");

    mem_req_seen = 1'b0;
    load_one_word_program("tests/kernels/empty.memh");
    configure_1d_launch(32'h0000_0001, 32'h0000_0000);
    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(100, "empty kernel completes after illegal-instruction recovery");

    check(error_status == 8'h00, "empty kernel recovery leaves error clear");
    check(!mem_req_seen, "empty kernel recovery issues no memory request");

    $display("tb_gpu_core_command_illegal_instruction PASS");
    $finish;
  end
endmodule
