import isa_pkg::*;

module tb_gpu_core_command_store16_kernel;
  import kernel_asm_pkg::*;

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
        mem_rsp_rdata <= mem_req_write ? '0 : memory[mem_req_addr[31:2]];

        if (mem_req_write) begin
          if (mem_req_wmask[0]) begin
            memory[mem_req_addr[31:2]][7:0] <= mem_req_wdata[7:0];
          end
          if (mem_req_wmask[1]) begin
            memory[mem_req_addr[31:2]][15:8] <= mem_req_wdata[15:8];
          end
          if (mem_req_wmask[2]) begin
            memory[mem_req_addr[31:2]][23:16] <= mem_req_wdata[23:16];
          end
          if (mem_req_wmask[3]) begin
            memory[mem_req_addr[31:2]][31:24] <= mem_req_wdata[31:24];
          end
        end
      end
    end
  end

  task automatic step;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $fatal(1, "%s", message);
      end
    end
  endtask

  task automatic write_imem(input logic [7:0] addr, input logic [ISA_WORD_W-1:0] word);
    begin
      imem_write_addr = addr;
      imem_write_data = word;
      imem_write_en = 1'b1;
      step();
      imem_write_en = 1'b0;
      imem_write_addr = '0;
      imem_write_data = '0;
    end
  endtask

  task automatic send_word(input logic [31:0] word);
    begin
      cmd_data = word;
      cmd_valid = 1'b1;
      while (!cmd_ready) begin
        step();
      end
      step();
      cmd_valid = 1'b0;
      cmd_data = '0;
    end
  endtask

  task automatic set_reg(input logic [31:0] addr, input logic [31:0] data);
    begin
      send_word(32'h1003_0000);
      send_word(addr);
      send_word(data);
    end
  endtask

  task automatic wait_idle;
    int timeout;
    begin
      timeout = 0;
      while (busy) begin
        step();
        timeout = timeout + 1;
        check(timeout < 200, "command-driven kernel timed out");
      end
      step();
    end
  endtask

  function automatic logic [15:0] pixel_at(input int x);
    logic [31:0] word;
    begin
      word = memory[x / 2];
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

    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      memory[i] = 32'hDEAD_DEAD;
    end

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

    set_reg(32'h0000_0010, 32'h0000_0000);
    set_reg(32'h0000_0040, 32'h0000_0000);
    set_reg(32'h0000_0044, 32'h0000_0004);
    set_reg(32'h0000_0048, 32'h0000_0001);
    set_reg(32'h0000_004C, 32'h0000_0004);
    set_reg(32'h0000_0050, 32'h0000_0001);
    set_reg(32'h0000_0054, 32'h0000_0000);
    set_reg(32'h0000_0058, 32'h0000_0000);

    send_word(32'h2001_0000);
    wait_idle();

    check(error_status == 8'h00, "command-driven kernel completes without errors");
    check(pixel_at(0) == COLOR, "command kernel writes pixel 0");
    check(pixel_at(1) == COLOR, "command kernel writes pixel 1");
    check(pixel_at(2) == COLOR, "command kernel writes pixel 2");
    check(pixel_at(3) == COLOR, "command kernel writes pixel 3");

    $display("tb_gpu_core_command_store16_kernel PASS");
    $finish;
  end
endmodule
