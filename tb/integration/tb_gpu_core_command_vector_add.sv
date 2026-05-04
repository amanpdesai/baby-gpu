import isa_pkg::*;

module tb_gpu_core_command_vector_add;
  import kernel_asm_pkg::*;
  `include "tb/common/gpu_core_command_driver.svh"

  localparam int MEM_WORDS = 128;
  localparam int ELEMENTS = 6;

  localparam logic [31:0] ARG_BASE = 32'h0000_0000;
  localparam logic [31:0] A_BASE = 32'h0000_0040;
  localparam logic [31:0] B_BASE = 32'h0000_0080;
  localparam logic [31:0] C_BASE = 32'h0000_00C0;

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
  logic [2:0] mem_stall_phase;
  logic pending_valid;
  logic pending_write;
  logic [31:0] pending_addr;
  logic [31:0] pending_wdata;
  logic [3:0] pending_wmask;
  logic [31:0] pending_rdata;
  logic [1:0] pending_delay;
  logic saw_req_stall;
  logic saw_rsp_delay;
  logic [31:0] memory [0:MEM_WORDS-1];
  int i;

  gpu_core #(
      .FB_WIDTH(16),
      .FB_HEIGHT(1),
      .FIFO_DEPTH(32)
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

  assign mem_req_ready = !pending_valid && (!mem_rsp_valid || mem_rsp_ready) &&
                         (mem_stall_phase != 3'd2);

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_stall_phase <= '0;
      pending_valid <= 1'b0;
      pending_write <= 1'b0;
      pending_addr <= '0;
      pending_wdata <= '0;
      pending_wmask <= '0;
      pending_rdata <= '0;
      pending_delay <= '0;
      saw_req_stall <= 1'b0;
      saw_rsp_delay <= 1'b0;
    end else begin
      mem_stall_phase <= mem_stall_phase + 3'd1;

      if (mem_req_valid && !mem_req_ready) begin
        saw_req_stall <= 1'b1;
      end
      if (pending_valid && pending_delay != 2'd0) begin
        saw_rsp_delay <= 1'b1;
      end

      if (mem_rsp_valid && mem_rsp_ready) begin
        mem_rsp_valid <= 1'b0;
      end

      if (pending_valid) begin
        if (pending_delay != 2'd0) begin
          pending_delay <= pending_delay - 2'd1;
        end else if (!mem_rsp_valid || mem_rsp_ready) begin
          pending_valid <= 1'b0;
          mem_rsp_valid <= 1'b1;
          mem_rsp_rdata <= pending_rdata;

          if (pending_write) begin
            if (pending_wmask[0]) begin
              memory[pending_addr[31:2]][7:0] <= pending_wdata[7:0];
            end
            if (pending_wmask[1]) begin
              memory[pending_addr[31:2]][15:8] <= pending_wdata[15:8];
            end
            if (pending_wmask[2]) begin
              memory[pending_addr[31:2]][23:16] <= pending_wdata[23:16];
            end
            if (pending_wmask[3]) begin
              memory[pending_addr[31:2]][31:24] <= pending_wdata[31:24];
            end
          end
        end
      end

      if (mem_req_valid && mem_req_ready) begin
        pending_valid <= 1'b1;
        pending_write <= mem_req_write;
        pending_addr <= mem_req_addr;
        pending_wdata <= mem_req_wdata;
        pending_wmask <= mem_req_wmask;
        pending_rdata <= mem_req_write ? '0 : memory[mem_req_addr[31:2]];
        pending_delay <= mem_req_write ? 2'd1 : 2'd2;
      end
    end
  end

  task automatic load_vector_add_program;
  begin
    write_imem(8'd0, kgpu_movsr(4'd1, ISA_SR_LINEAR_GLOBAL_ID));
    write_imem(8'd1, kgpu_movi(4'd2, 18'd4));
    write_imem(8'd2, kgpu_mul(4'd1, 4'd1, 4'd2));

    write_imem(8'd3, kgpu_movsr(4'd8, ISA_SR_ARG_BASE));
    write_imem(8'd4, kgpu_load(4'd3, 4'd8, 18'd0));
    write_imem(8'd5, kgpu_load(4'd4, 4'd8, 18'd4));
    write_imem(8'd6, kgpu_load(4'd10, 4'd8, 18'd8));
    write_imem(8'd7, kgpu_load(4'd11, 4'd8, 18'd12));

    write_imem(8'd8, kgpu_add(4'd5, 4'd3, 4'd1));
    write_imem(8'd9, kgpu_load(4'd6, 4'd5, 18'd0));
    write_imem(8'd10, kgpu_add(4'd5, 4'd4, 4'd1));
    write_imem(8'd11, kgpu_load(4'd7, 4'd5, 18'd0));
    write_imem(8'd12, kgpu_add(4'd9, 4'd6, 4'd7));
    write_imem(8'd13, kgpu_add(4'd5, 4'd10, 4'd1));
    write_imem(8'd14, kgpu_store(4'd9, 4'd5, 18'd0));
    write_imem(8'd15, kgpu_end());
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

    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      memory[i] = 32'hDEAD_DEAD;
    end

    step();
    reset = 1'b0;
    step();

    load_vector_add_program();

    memory[ARG_BASE[31:2] + 0] = A_BASE;
    memory[ARG_BASE[31:2] + 1] = B_BASE;
    memory[ARG_BASE[31:2] + 2] = C_BASE;
    memory[ARG_BASE[31:2] + 3] = 32'(ELEMENTS);

    for (i = 0; i < ELEMENTS; i = i + 1) begin
      memory[A_BASE[31:2] + i] = 32'd100 + 32'(i);
      memory[B_BASE[31:2] + i] = 32'd1000 + 32'(i * 3);
      memory[C_BASE[31:2] + i] = 32'hCAFE_0000 + 32'(i);
    end
    memory[C_BASE[31:2] + ELEMENTS] = 32'hBEEF_0006;
    memory[C_BASE[31:2] + ELEMENTS + 1] = 32'hBEEF_0007;

    configure_launch(32'h0000_0000, 32'(ELEMENTS), 32'h0000_0001, ARG_BASE);

    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(1000, "gpu_core wait_idle timeout");

    check(error_status == 8'h00, "command vector_add completes without error");
    check(saw_req_stall, "command vector_add observes memory request backpressure");
    check(saw_rsp_delay, "command vector_add observes delayed memory responses");
    for (i = 0; i < ELEMENTS; i = i + 1) begin
      check(memory[C_BASE[31:2] + i] == (32'd1100 + 32'(i * 4)),
            "command vector_add output matches");
    end
    check(memory[C_BASE[31:2] + ELEMENTS] == 32'hBEEF_0006,
          "command vector_add leaves first sentinel unchanged");
    check(memory[C_BASE[31:2] + ELEMENTS + 1] == 32'hBEEF_0007,
          "command vector_add leaves second sentinel unchanged");
    check(!busy, "gpu_core is idle after command vector_add");

    $display("tb_gpu_core_command_vector_add PASS");
    $finish;
  end
endmodule
