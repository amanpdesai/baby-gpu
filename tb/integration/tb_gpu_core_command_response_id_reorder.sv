module tb_gpu_core_command_response_id_reorder;
  import isa_pkg::*;

  localparam int MEM_WORDS = 8;
  localparam int IMEM_ADDR_W = 8;
  localparam logic [15:0] CLEAR_COLOR = 16'h1111;
  localparam logic [15:0] KERNEL_COLOR = 16'h2A5B;

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

  int writer_pending;
  int programmable_pending;
  int accepted_writer;
  int accepted_programmable;
  bit saw_programmable_response_before_writer_drain;
  logic [31:0] memory [0:MEM_WORDS-1];

  `include "tb/common/gpu_core_command_driver.svh"
  `include "tb/common/gpu_core_memory_helpers.svh"
  `include "tb/common/kernel_program_loader.svh"

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

  assign mem_req_ready = !reset && !mem_rsp_valid;

  always #5 clk = ~clk;

  always_ff @(posedge clk) begin
    if (reset) begin
      writer_pending <= 0;
      programmable_pending <= 0;
      accepted_writer <= 0;
      accepted_programmable <= 0;
    end else if (mem_req_valid && mem_req_ready) begin
      if (mem_req_id[1]) begin
        programmable_pending <= programmable_pending + 1;
        accepted_programmable <= accepted_programmable + 1;
      end else begin
        writer_pending <= writer_pending + 1;
        accepted_writer <= accepted_writer + 1;
      end

      if (mem_req_write) begin
        write_memory_masked(mem_req_addr, mem_req_wdata, mem_req_wmask);
      end
    end
  end

  task automatic release_response(input logic [1:0] id);
    begin
      mem_rsp_id = id;
      mem_rsp_rdata = '0;
      mem_rsp_valid = 1'b1;
      #1;
      check(mem_rsp_ready, "released response accepted");
      step();
      mem_rsp_valid = 1'b0;
      mem_rsp_id = '0;
      mem_rsp_rdata = '0;
      if (id[1]) begin
        programmable_pending--;
      end else begin
        writer_pending--;
      end
      step();
    end
  endtask

  task automatic wait_for_writer_requests(input int expected);
    int timeout;
    begin
      timeout = 0;
      while (accepted_writer < expected) begin
        step();
        timeout++;
        check(timeout < 100, "writer request accept timeout");
      end
    end
  endtask

  task automatic wait_for_programmable_request;
    int timeout;
    begin
      timeout = 0;
      while (accepted_programmable == 0) begin
        step();
        timeout++;
        check(timeout < 100, "programmable request accept timeout");
      end
    end
  endtask

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

  task automatic load_store16_kernel_program;
    logic [ISA_WORD_W-1:0] kernel_words [0:7];
    begin
      $readmemh("tests/kernels/store16_linear.memh", kernel_words);
      `KGPU_LOAD_PROGRAM(kernel_words)
    end
  endtask

  initial begin
    init_command_driver();
    mem_rsp_valid = 1'b0;
    mem_rsp_rdata = '0;
    mem_rsp_id = '0;
    writer_pending = 0;
    programmable_pending = 0;
    accepted_writer = 0;
    accepted_programmable = 0;
    saw_programmable_response_before_writer_drain = 1'b0;
    init_memory(32'hDEAD_DEAD);

    step();
    reset = 1'b0;
    step();

    send_word(32'h0102_0000);
    send_word({16'h0000, CLEAR_COLOR});
    wait_for_writer_requests(4);
    check(writer_pending == 4, "clear writes remain pending");
    check(pixel_at(0) == CLEAR_COLOR, "clear updates pixel 0 before responses");
    check(pixel_at(3) == CLEAR_COLOR, "clear updates pixel 3 before responses");

    load_store16_kernel_program();
    set_reg(KGPU_REG_FB_BASE, 32'h0000_0000);
    configure_1d_launch(32'h0000_0004, 32'h0000_0000);
    launch_kernel();

    repeat (6) begin
      step();
      check(accepted_programmable == 0, "tracker-full writer responses block programmable request acceptance");
    end

    release_response(2'b00);
    check(writer_pending == 3, "one writer response drained");
    wait_for_programmable_request();
    check(programmable_pending == 1, "first programmable response is pending");
    check(writer_pending == 3, "older writer responses remain pending before programmable response");

    release_response(2'b10);
    saw_programmable_response_before_writer_drain = (writer_pending != 0);

    while (writer_pending > 0) begin
      release_response(2'b00);
    end

    while (busy || programmable_pending != 0) begin
      if (programmable_pending > 0) begin
        release_response(2'b10);
      end else begin
        step();
      end
    end

    check(saw_programmable_response_before_writer_drain, "programmable response returned before older writer responses");
    check(error_status == 8'h00, "response-ID reorder test leaves error clear");
    check(pixel_at(0) == KERNEL_COLOR, "kernel response with source ID updates pixel 0");
    check(pixel_at(1) == KERNEL_COLOR, "kernel completes after reordered response");
    check(pixel_at(2) == KERNEL_COLOR, "kernel completes pixel 2");
    check(pixel_at(3) == KERNEL_COLOR, "kernel completes pixel 3");

    $display("tb_gpu_core_command_response_id_reorder PASS");
    $finish;
  end
endmodule
