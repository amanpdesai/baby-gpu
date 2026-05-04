import isa_pkg::*;

module tb_gpu_core_command_store16_fault;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"

  localparam int MEM_WORDS = 8;
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
  logic mem_rsp_valid;
  logic mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;
  logic mem_req_seen;
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

  assign mem_req_ready = !mem_rsp_valid || mem_rsp_ready;

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_req_seen <= 1'b0;
    end else begin
      if (mem_req_valid && mem_req_ready) begin
        mem_req_seen <= 1'b1;
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end
    end
  end

  task automatic wait_programmable_error;
    int timeout;
  begin
    timeout = 0;
    while ((error_status & ERR_PROGRAMMABLE) == 8'h00) begin
      check(timeout < 200, "programmable STORE16 fault timeout");
      timeout = timeout + 1;
      step();
    end
  end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    enable = 1'b1;
    clear_errors = 1'b0;
    cmd_valid = 1'b0;
    cmd_data = '0;
    imem_write_en = 1'b0;
    imem_write_addr = '0;
    imem_write_data = '0;
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    mem_req_seen = 1'b0;

    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    write_imem(8'd0, kgpu_movi(4'd1, 18'd1));
    write_imem(8'd1, kgpu_movi(4'd2, 18'h02A5B));
    write_imem(8'd2, kgpu_store16(4'd2, 4'd1, 18'd0));
    write_imem(8'd3, kgpu_end());

    configure_launch(32'h0000_0000, 32'h0000_0001, 32'h0000_0001, 32'h0000_0000);

    launch_kernel();
    wait_programmable_error();

    check(error_status == ERR_PROGRAMMABLE, "only programmable error bit is set");
    check(!mem_req_seen, "odd-address STORE16 fault issues no memory request");
    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      check(memory[i] == 32'hDEAD_DEAD, "faulting STORE16 leaves memory unchanged");
    end

    set_reg(KGPU_REG_CONTROL, KGPU_CONTROL_SOFT_RESET);
    wait_error_clear(20, "soft reset clears programmable fault status");

    mem_req_seen = 1'b0;
    write_imem(8'd0, kgpu_movi(4'd1, 18'd0));
    write_imem(8'd1, kgpu_movi(4'd2, 18'h02A5B));
    write_imem(8'd2, kgpu_store16(4'd2, 4'd1, 18'd0));
    write_imem(8'd3, kgpu_end());

    configure_launch(32'h0000_0000, 32'h0000_0001, 32'h0000_0001, 32'h0000_0000);

    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(200, "gpu_core recovery wait_idle timeout");

    check(error_status == 8'h00, "recovered STORE16 completes without error");
    check(mem_req_seen, "recovered STORE16 issues a memory request");
    check(memory[0][15:0] == 16'h2A5B, "recovered STORE16 writes low halfword");
    check(memory[0][31:16] == 16'hDEAD, "recovered STORE16 preserves high halfword");

    $display("tb_gpu_core_command_store16_fault PASS");
    $finish;
  end
endmodule
