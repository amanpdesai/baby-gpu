import isa_pkg::*;

module tb_gpu_core_command_store16_fault;
  import kernel_asm_pkg::*;

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
      end else if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
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

    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      memory[i] = 32'hDEAD_DEAD;
    end

    step();
    reset = 1'b0;
    step();

    write_imem(8'd0, kgpu_movi(4'd1, 18'd1));
    write_imem(8'd1, kgpu_movi(4'd2, 18'h02A5B));
    write_imem(8'd2, kgpu_store16(4'd2, 4'd1, 18'd0));
    write_imem(8'd3, kgpu_end());

    set_reg(32'h0000_0040, 32'h0000_0000);
    set_reg(32'h0000_0044, 32'h0000_0001);
    set_reg(32'h0000_0048, 32'h0000_0001);
    set_reg(32'h0000_004C, 32'h0000_0004);
    set_reg(32'h0000_0050, 32'h0000_0001);
    set_reg(32'h0000_0054, 32'h0000_0000);
    set_reg(32'h0000_0058, 32'h0000_0000);

    send_word(32'h2001_0000);
    wait_programmable_error();

    check(error_status == ERR_PROGRAMMABLE, "only programmable error bit is set");
    check(!mem_req_seen, "odd-address STORE16 fault issues no memory request");
    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      check(memory[i] == 32'hDEAD_DEAD, "faulting STORE16 leaves memory unchanged");
    end

    $display("tb_gpu_core_command_store16_fault PASS");
    $finish;
  end
endmodule
