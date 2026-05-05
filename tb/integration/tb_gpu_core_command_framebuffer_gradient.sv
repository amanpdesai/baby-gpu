import isa_pkg::*;

module tb_gpu_core_command_framebuffer_gradient;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 64;
  localparam int IMEM_ADDR_W = 8;
  localparam int GRID_X = 3;
  localparam int GRID_Y = 2;
  localparam logic [31:0] FRAMEBUFFER_BASE = 32'h0000_0040;

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
  logic saw_mem_req;
  logic [31:0] memory [0:MEM_WORDS-1];
  int x;
  int y;

  `include "tb/common/gpu_core_memory_helpers.svh"

  gpu_core #(
    .FB_WIDTH(4),
    .FB_HEIGHT(3),
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
    mem_req_ready = !mem_rsp_valid || mem_rsp_ready;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_rsp_id <= '0;
      saw_mem_req <= 1'b0;
    end else begin
      if (mem_req_valid && mem_req_ready) begin
        mem_rsp_valid <= 1'b1;
        mem_rsp_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
        mem_rsp_id <= mem_req_id;
        saw_mem_req <= 1'b1;

        if (mem_req_write) begin
          write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
        end
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end
    end
  end

  function automatic logic [15:0] expected_pixel(input int px, input int py);
  begin
    expected_pixel = 16'(16'h0060 + px + (py * 16));
  end
  endfunction

  function automatic logic [15:0] pixel_at(input int px, input int py);
    int pixel_idx;
    logic [31:0] word;
  begin
    pixel_idx = (py * 4) + px;
    word = read_memory_word(FRAMEBUFFER_BASE + 32'(pixel_idx * 2));
    if ((pixel_idx % 2) == 0) begin
      pixel_at = word[15:0];
    end else begin
      pixel_at = word[31:16];
    end
  end
  endfunction

  task automatic load_gradient_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:15];
  begin
    $readmemh("tests/kernels/framebuffer_gradient.memh", kernel_words);
    `KGPU_LOAD_PROGRAM(kernel_words)
  end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
mem_rsp_id = '0;
    saw_mem_req = 1'b0;

    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    load_gradient_program();

    set_reg(KGPU_REG_FB_BASE, FRAMEBUFFER_BASE);
    configure_launch(32'h0000_0000, 32'(GRID_X), 32'(GRID_Y), 32'h0000_0000);

    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(400, "command-driven framebuffer gradient timed out");

    check(error_status == 8'h00, "command-driven framebuffer gradient has no errors");
    check(saw_mem_req, "command-driven framebuffer gradient reaches memory path");

    for (y = 0; y < GRID_Y; y = y + 1) begin
      for (x = 0; x < GRID_X; x = x + 1) begin
        check(pixel_at(x, y) == expected_pixel(x, y),
              "command-driven framebuffer gradient pixel matches");
      end
    end

    check(pixel_at(3, 0) == 16'hDEAD, "row 0 padding pixel is untouched");
    check(pixel_at(3, 1) == 16'hDEAD, "row 1 padding pixel is untouched");
    check(pixel_at(0, 2) == 16'hDEAD, "row 2 sentinel pixel is untouched");

    $display("tb_gpu_core_command_framebuffer_gradient PASS");
    $finish;
  end
endmodule
