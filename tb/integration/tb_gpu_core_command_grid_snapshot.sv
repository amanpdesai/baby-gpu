import isa_pkg::*;

module tb_gpu_core_command_grid_snapshot;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 64;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [31:0] OLD_GRID_X = 32'h0000_0003;
  localparam logic [31:0] OLD_GRID_Y = 32'h0000_0002;
  localparam logic [31:0] NEW_GRID_X = 32'h0000_0001;
  localparam logic [31:0] NEW_GRID_Y = 32'h0000_0001;
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
  logic mem_rsp_valid;
  logic mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;
  logic hold_rsp;
  logic pending_rsp;
  logic saw_mem_req;
  logic accepted_req_write;
  logic [31:0] accepted_req_addr;
  logic [31:0] pending_rdata;
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
    .mem_rsp_valid(mem_rsp_valid),
    .mem_rsp_ready(mem_rsp_ready),
    .mem_rsp_rdata(mem_rsp_rdata)
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
      pending_rsp <= 1'b0;
      pending_rdata <= '0;
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

  function automatic logic [15:0] expected_pixel(input int px, input int py);
  begin
    expected_pixel = 16'(16'h0080 + px + (py * 16));
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

  task automatic wait_for_first_mem_req;
    int timeout;
  begin
    timeout = 0;
    while (!saw_mem_req) begin
      check(timeout < 100, "grid-snapshot initial memory request timeout");
      timeout = timeout + 1;
      step();
    end
    check(!accepted_req_write, "grid-snapshot first memory request is a load");
    check(accepted_req_addr == 32'h0000_0000,
          "grid-snapshot first memory request is the dummy load");
  end
  endtask

  task automatic wait_for_grid_rewrite;
    int timeout;
  begin
    timeout = 0;
    while ((dut.register_launch_grid_x != NEW_GRID_X[15:0]) ||
           (dut.register_launch_grid_y != NEW_GRID_Y[15:0])) begin
      check(timeout < 60, "post-launch GRID_X/Y rewrite reaches register file");
      timeout = timeout + 1;
      step();
    end
    check(busy, "kernel remains active after GRID_X/Y rewrite completes");
    check(hold_rsp, "kernel response remains held after GRID_X/Y rewrite completes");
  end
  endtask

  task automatic load_grid_snapshot_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:17];
  begin
    kernel_words[0] = kgpu_movi(4'd1, 18'd0);
    kernel_words[1] = kgpu_load(4'd2, 4'd1, 18'd0);
    kernel_words[2] = kgpu_movsr(4'd1, ISA_SR_GLOBAL_ID_Y);
    kernel_words[3] = kgpu_movsr(4'd2, ISA_SR_FRAMEBUFFER_WIDTH);
    kernel_words[4] = kgpu_mul(4'd3, 4'd1, 4'd2);
    kernel_words[5] = kgpu_movsr(4'd4, ISA_SR_GLOBAL_ID_X);
    kernel_words[6] = kgpu_add(4'd3, 4'd3, 4'd4);
    kernel_words[7] = kgpu_movi(4'd5, 18'd2);
    kernel_words[8] = kgpu_mul(4'd3, 4'd3, 4'd5);
    kernel_words[9] = kgpu_movsr(4'd6, ISA_SR_FRAMEBUFFER_BASE);
    kernel_words[10] = kgpu_add(4'd7, 4'd6, 4'd3);
    kernel_words[11] = kgpu_movi(4'd8, 18'd16);
    kernel_words[12] = kgpu_mul(4'd1, 4'd1, 4'd8);
    kernel_words[13] = kgpu_movi(4'd8, 18'h80);
    kernel_words[14] = kgpu_add(4'd8, 4'd8, 4'd4);
    kernel_words[15] = kgpu_add(4'd8, 4'd8, 4'd1);
    kernel_words[16] = kgpu_store16(4'd8, 4'd7, 18'd0);
    kernel_words[17] = kgpu_end();
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
    accepted_req_write = 1'b0;
    accepted_req_addr = '0;

    init_memory(32'hDEAD_DEAD);
    memory[0] = 32'h0123_4567;

    step();
    reset = 1'b0;
    step();

    load_grid_snapshot_program();

    hold_rsp = 1'b1;
    set_reg(KGPU_REG_FB_BASE, FRAMEBUFFER_BASE);
    configure_launch(32'h0000_0000, OLD_GRID_X, OLD_GRID_Y, 32'h0000_0000);
    launch_kernel();
    wait_for_first_mem_req();

    set_reg(KGPU_REG_GRID_X, NEW_GRID_X);
    set_reg(KGPU_REG_GRID_Y, NEW_GRID_Y);
    wait_for_grid_rewrite();

    hold_rsp = 1'b0;
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(500, "grid-snapshot kernel timed out");

    check(error_status == 8'h00, "grid-snapshot kernel completes without errors");
    for (y = 0; y < 2; y = y + 1) begin
      for (x = 0; x < 3; x = x + 1) begin
        check(pixel_at(x, y) == expected_pixel(x, y),
              "grid-snapshot original grid pixel matches");
      end
    end
    check(pixel_at(3, 0) == 16'hDEAD, "grid-snapshot row 0 padding untouched");
    check(pixel_at(3, 1) == 16'hDEAD, "grid-snapshot row 1 padding untouched");
    check(pixel_at(0, 2) == 16'hDEAD, "grid-snapshot row 2 sentinel untouched");

    $display("tb_gpu_core_command_grid_snapshot PASS");
    $finish;
  end
endmodule
