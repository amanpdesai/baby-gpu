module tb_gpu_core_smoke;
  logic clk;
  logic reset;
  logic enable;
  logic clear_errors;
  logic cmd_valid;
  logic cmd_ready;
  logic [31:0] cmd_data;
  logic busy;
  logic [7:0] error_status;
  logic mem_req_valid;
  logic mem_req_ready;
  logic mem_req_write;
  logic [31:0] mem_req_addr;
  logic [31:0] mem_req_wdata;
  logic [3:0] mem_req_wmask;

  logic [31:0] framebuffer [0:5];
  int i;

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
      .busy(busy),
      .error_status(error_status),
      .mem_req_valid(mem_req_valid),
      .mem_req_ready(mem_req_ready),
      .mem_req_write(mem_req_write),
      .mem_req_addr(mem_req_addr),
      .mem_req_wdata(mem_req_wdata),
      .mem_req_wmask(mem_req_wmask)
  );

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (!reset && mem_req_valid && mem_req_ready && mem_req_write) begin
      if (mem_req_wmask[0]) begin
        framebuffer[mem_req_addr[31:2]][7:0] <= mem_req_wdata[7:0];
      end
      if (mem_req_wmask[1]) begin
        framebuffer[mem_req_addr[31:2]][15:8] <= mem_req_wdata[15:8];
      end
      if (mem_req_wmask[2]) begin
        framebuffer[mem_req_addr[31:2]][23:16] <= mem_req_wdata[23:16];
      end
      if (mem_req_wmask[3]) begin
        framebuffer[mem_req_addr[31:2]][31:24] <= mem_req_wdata[31:24];
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

  task automatic wait_idle;
    int timeout;
    begin
      timeout = 0;
      while (busy) begin
        step();
        timeout = timeout + 1;
        check(timeout < 200, "GPU core operation timed out");
      end
      step();
    end
  endtask

  function automatic logic [15:0] pixel_at(input int x, input int y);
    logic [31:0] word;
    begin
      word = framebuffer[(y * 4 + x) / 2];
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
    mem_req_ready = 1'b1;
    for (i = 0; i < 6; i = i + 1) begin
      framebuffer[i] = 32'hDEAD_DEAD;
    end

    step();
    reset = 1'b0;
    step();

    send_word(32'h0102_0000);
    send_word(32'h0000_1234);
    wait_idle();

    for (i = 0; i < 12; i = i + 1) begin
      check(pixel_at(i % 4, i / 4) == 16'h1234, "CLEAR updates every framebuffer pixel");
    end

    send_word(32'h0205_0000);
    send_word({16'd1, 16'd1});
    send_word({16'd2, 16'd1});
    send_word(32'h0000_ABCD);
    send_word(32'h0000_0000);
    wait_idle();

    check(pixel_at(0, 1) == 16'h1234, "RECT leaves left neighbor unchanged");
    check(pixel_at(1, 1) == 16'hABCD, "RECT updates first selected pixel");
    check(pixel_at(2, 1) == 16'hABCD, "RECT updates second selected pixel");
    check(pixel_at(3, 1) == 16'h1234, "RECT leaves right neighbor unchanged");
    check(error_status == 8'h00, "smoke command stream has no core errors");

    $display("tb_gpu_core_smoke PASS");
    $finish;
  end
endmodule
