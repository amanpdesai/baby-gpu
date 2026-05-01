module tb_command_processor;
  logic clk;
  logic reset;
  logic enable;
  logic clear_errors;
  logic cmd_valid;
  logic cmd_ready;
  logic [31:0] cmd_data;
  logic clear_start;
  logic [15:0] clear_color;
  logic clear_busy;
  logic clear_done;
  logic rect_start;
  logic [15:0] rect_x;
  logic [15:0] rect_y;
  logic [15:0] rect_width;
  logic [15:0] rect_height;
  logic [15:0] rect_color;
  logic rect_busy;
  logic rect_done;
  logic reg_write_valid;
  logic [31:0] reg_write_addr;
  logic [31:0] reg_write_data;
  logic busy;
  logic [7:0] error_status;

  command_processor dut (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .clear_errors(clear_errors),
      .cmd_valid(cmd_valid),
      .cmd_ready(cmd_ready),
      .cmd_data(cmd_data),
      .clear_start(clear_start),
      .clear_color(clear_color),
      .clear_busy(clear_busy),
      .clear_done(clear_done),
      .rect_start(rect_start),
      .rect_x(rect_x),
      .rect_y(rect_y),
      .rect_width(rect_width),
      .rect_height(rect_height),
      .rect_color(rect_color),
      .rect_busy(rect_busy),
      .rect_done(rect_done),
      .reg_write_valid(reg_write_valid),
      .reg_write_addr(reg_write_addr),
      .reg_write_data(reg_write_data),
      .busy(busy),
      .error_status(error_status)
  );

  always #5 clk = ~clk;

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

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    enable = 1'b1;
    clear_errors = 1'b0;
    cmd_valid = 1'b0;
    cmd_data = '0;
    clear_busy = 1'b0;
    clear_done = 1'b0;
    rect_busy = 1'b0;
    rect_done = 1'b0;

    step();
    reset = 1'b0;
    step();

    send_word(32'h0102_0000);
    check(busy, "CLEAR header enters busy state");
    cmd_data = 32'h0000_1357;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "CLEAR color word can dispatch when engine is idle");
    step();
    cmd_valid = 1'b0;
    step();
    check(clear_start && clear_color == 16'h1357, "CLEAR dispatches color");
    step();
    check(busy, "processor waits for clear completion");
    clear_done = 1'b1;
    step();
    clear_done = 1'b0;
    check(!busy, "processor returns idle after clear_done");

    send_word(32'h0205_0000);
    send_word({16'd3, 16'd4});
    send_word({16'd5, 16'd6});
    send_word(32'h0000_BEEF);
    cmd_data = 32'h0000_0000;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "RECT reserved word can dispatch when engine is idle");
    step();
    cmd_valid = 1'b0;
    step();
    check(rect_start, "RECT dispatches start");
    check(rect_x == 16'd3 && rect_y == 16'd4, "RECT captures origin");
    check(rect_width == 16'd5 && rect_height == 16'd6, "RECT captures size");
    check(rect_color == 16'hBEEF, "RECT captures color");
    rect_done = 1'b1;
    step();
    rect_done = 1'b0;
    check(!busy, "processor returns idle after rect_done");

    send_word(32'h1003_0000);
    send_word(32'h0000_0010);
    cmd_data = 32'h0000_0001;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "SET_REGISTER data word accepted");
    step();
    cmd_valid = 1'b0;
    step();
    check(reg_write_valid, "SET_REGISTER emits register write");
    check(reg_write_addr == 32'h0000_0010, "SET_REGISTER captures address");
    check(reg_write_data == 32'h0000_0001, "SET_REGISTER captures data");

    send_word(32'h5501_0000);
    check(error_status[0], "unknown opcode sets sticky error");
    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears sticky errors");

    send_word(32'h0101_0000);
    check(error_status[1], "bad word count sets sticky error");

    clear_errors = 1'b1;
    step();
    clear_errors = 1'b0;
    check(error_status == 8'h00, "clear_errors clears bad word count");

    clear_busy = 1'b1;
    send_word(32'h0301_0000);
    check(busy, "WAIT_IDLE remains busy while draw engine is busy");
    check(!cmd_ready, "WAIT_IDLE blocks new command words");
    clear_busy = 1'b0;
    step();
    check(!busy, "WAIT_IDLE returns idle when draw engines are idle");

    clear_busy = 1'b1;
    send_word(32'h0102_0000);
    cmd_data = 32'h0000_2468;
    cmd_valid = 1'b1;
    #1;
    check(cmd_ready, "CLEAR color word accepted before busy dispatch");
    step();
    check(!clear_start, "busy clear engine suppresses same-cycle clear_start");
    cmd_valid = 1'b0;
    step();
    check(error_status[3], "busy clear engine sets dispatch-busy error");
    check(!clear_start, "busy clear engine suppresses clear_start");
    clear_busy = 1'b0;
    #1;
    check(!busy, "dispatch-busy CLEAR returns command processor idle");

    $display("tb_command_processor PASS");
    $finish;
  end
endmodule
