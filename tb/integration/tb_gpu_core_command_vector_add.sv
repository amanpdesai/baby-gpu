import isa_pkg::*;

module tb_gpu_core_command_vector_add;
  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/kernel_program_loader.svh"

  localparam int MEM_WORDS = 128;
  localparam int IMEM_ADDR_W = 8;
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
logic [1:0] mem_req_id;
  logic mem_rsp_valid;
  logic mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;
logic [1:0] mem_rsp_id;
  logic [2:0] mem_stall_phase;
  logic pending_valid;
  logic pending_write;
  logic [31:0] pending_addr;
  logic [31:0] pending_wdata;
  logic [3:0] pending_wmask;
  logic [31:0] pending_rdata;
logic [1:0] pending_rsp_id;
logic [1:0] pending_delay;
logic saw_req_stall;
logic saw_rsp_delay;
logic saw_programmable_mem_id;
logic [31:0] memory [0:MEM_WORDS-1];
  int i;
  `include "tb/common/gpu_core_memory_helpers.svh"

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
        .mem_req_id(mem_req_id),
      .mem_rsp_valid(mem_rsp_valid),
      .mem_rsp_ready(mem_rsp_ready),
      .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_id(mem_rsp_id)
  );

  assign mem_req_ready = !pending_valid && (!mem_rsp_valid || mem_rsp_ready) &&
                         (mem_stall_phase != 3'd2);

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      mem_rsp_valid <= 1'b0;
      mem_rsp_rdata <= '0;
      mem_rsp_id <= '0;
      mem_stall_phase <= '0;
      pending_valid <= 1'b0;
      pending_write <= 1'b0;
      pending_addr <= '0;
      pending_wdata <= '0;
      pending_wmask <= '0;
      pending_rdata <= '0;
      pending_rsp_id <= '0;
      pending_delay <= '0;
      saw_req_stall <= 1'b0;
      saw_rsp_delay <= 1'b0;
      saw_programmable_mem_id <= 1'b0;
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
          mem_rsp_id <= pending_rsp_id;

          if (pending_write) begin
            write_memory_masked(pending_addr, pending_wdata, pending_wmask);
          end
        end
      end

      if (mem_req_valid && mem_req_ready) begin
        if (mem_req_id[1]) begin
          saw_programmable_mem_id <= 1'b1;
        end
        pending_valid <= 1'b1;
        pending_write <= mem_req_write;
        pending_addr <= mem_req_addr;
        pending_wdata <= mem_req_wdata;
        pending_wmask <= mem_req_wmask;
        pending_rdata <= mem_req_write ? '0 : read_memory_word(mem_req_addr);
        pending_rsp_id <= mem_req_id;
        pending_delay <= mem_req_write ? 2'd1 : 2'd2;
      end
    end
  end

  task automatic load_vector_add_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:15];
  begin
    $readmemh("tests/kernels/vector_add.memh", kernel_words);
    `KGPU_LOAD_PROGRAM(kernel_words)
  end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
mem_rsp_id = '0;

    init_memory(32'hDEAD_DEAD);

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

    configure_1d_launch(32'(ELEMENTS), ARG_BASE);

    launch_kernel();
    send_word(KGPU_CMD_WAIT_IDLE);
    wait_idle(1000, "gpu_core wait_idle timeout");

    check(error_status == 8'h00, "command vector_add completes without error");
check(saw_req_stall, "command vector_add observes memory request backpressure");
check(saw_rsp_delay, "command vector_add observes delayed memory responses");
check(saw_programmable_mem_id, "command vector_add uses external programmable memory IDs");
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
