import isa_pkg::*;

module tb_gpu_core_command_store16_kernel;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"

  localparam int MEM_WORDS = 16;
  localparam logic [15:0] COLOR = 16'h2A5B;

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
    end else begin
      if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end

      if (mem_req_valid && mem_req_ready) begin
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end
    end
  end

  function automatic logic [15:0] pixel_at(input int x);
    logic [31:0] word;
    begin
      word = read_memory_word(32'(x * 2));
      if ((x % 2) == 0) begin
        pixel_at = word[15:0];
      end else begin
        pixel_at = word[31:16];
      end
    end
  endfunction

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

    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    write_imem(8'd0, kgpu_movsr(4'd1, ISA_SR_LINEAR_GLOBAL_ID));
    write_imem(8'd1, kgpu_movi(4'd2, 18'd2));
    write_imem(8'd2, kgpu_mul(4'd3, 4'd1, 4'd2));
    write_imem(8'd3, kgpu_movsr(4'd4, ISA_SR_FRAMEBUFFER_BASE));
    write_imem(8'd4, kgpu_add(4'd5, 4'd4, 4'd3));
    write_imem(8'd5, kgpu_movi(4'd6, 18'(COLOR)));
    write_imem(8'd6, kgpu_store16(4'd6, 4'd5, 18'd0));
    write_imem(8'd7, kgpu_end());

    set_reg(KGPU_REG_FB_BASE, 32'h0000_0000);
    configure_launch(32'h0000_0000, 32'h0000_0004, 32'h0000_0001, 32'h0000_0000);

    launch_kernel();
    wait_idle(200, "command-driven kernel timed out");

    check(error_status == 8'h00, "command-driven kernel completes without errors");
    check(pixel_at(0) == COLOR, "command kernel writes pixel 0");
    check(pixel_at(1) == COLOR, "command kernel writes pixel 1");
    check(pixel_at(2) == COLOR, "command kernel writes pixel 2");
    check(pixel_at(3) == COLOR, "command kernel writes pixel 3");

    $display("tb_gpu_core_command_store16_kernel PASS");
    $finish;
  end
endmodule
