module tb_command_fifo;
  logic clk;
  logic reset;
  logic flush;
  logic in_valid;
  logic in_ready;
  logic [31:0] in_data;
  logic out_valid;
  logic out_ready;
  logic [31:0] out_data;
  logic full;
  logic empty;
  logic [2:0] count;

  command_fifo #(
      .DATA_W(32),
      .DEPTH(4)
  ) dut (
      .clk(clk),
      .reset(reset),
      .flush(flush),
      .in_valid(in_valid),
      .in_ready(in_ready),
      .in_data(in_data),
      .out_valid(out_valid),
      .out_ready(out_ready),
      .out_data(out_data),
      .full(full),
      .empty(empty),
      .count(count)
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

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    flush = 1'b0;
    in_valid = 1'b0;
    in_data = '0;
    out_ready = 1'b0;

    step();
    reset = 1'b0;
    step();
    check(empty && !full && !out_valid && count == 3'd0, "reset leaves FIFO empty");

    in_data = 32'h1111_0001;
    in_valid = 1'b1;
    step();
    in_valid = 1'b0;
    check(out_valid && out_data == 32'h1111_0001 && count == 3'd1, "single push visible");

    step();
    check(out_valid && out_data == 32'h1111_0001 && count == 3'd1, "output stable while stalled");

    in_valid = 1'b1;
    in_data = 32'h2222_0002;
    step();
    in_data = 32'h3333_0003;
    step();
    in_data = 32'h4444_0004;
    step();
    in_valid = 1'b0;
    check(full && count == 3'd4 && !in_ready, "FIFO reports full");

    out_ready = 1'b1;
    in_valid = 1'b1;
    in_data = 32'h5555_0005;
    #1;
    check(in_ready, "full FIFO accepts push when popping");
    step();
    in_valid = 1'b0;
    check(full && count == 3'd4 && out_data == 32'h2222_0002, "simultaneous push and pop keeps count");

    step();
    check(out_data == 32'h3333_0003, "second stored word pops in order");
    step();
    check(out_data == 32'h4444_0004, "third stored word pops in order");
    step();
    check(out_data == 32'h5555_0005, "simultaneous pushed word pops last");
    step();
    check(empty && !out_valid, "FIFO drains empty");

    in_valid = 1'b1;
    in_data = 32'hAAAA_000A;
    step();
    flush = 1'b1;
    in_valid = 1'b0;
    step();
    flush = 1'b0;
    check(empty && !out_valid && count == 3'd0, "flush clears FIFO");

    flush = 1'b1;
    in_valid = 1'b1;
    in_data = 32'hBBBB_000B;
    #1;
    check(!in_ready, "flush blocks incoming push");
    step();
    flush = 1'b0;
    in_valid = 1'b0;
    check(empty && !out_valid && count == 3'd0, "flush ignores incoming push");

    out_ready = 1'b0;
    in_valid = 1'b1;
    in_data = 32'hCCCC_000C;
    step();
    in_data = 32'hDDDD_000D;
    step();
    in_valid = 1'b0;
    check(out_valid && out_data == 32'hCCCC_000C && count == 3'd2,
          "two words queued before priority flush");

    flush = 1'b1;
    out_ready = 1'b1;
    in_valid = 1'b1;
    in_data = 32'hEEEE_000E;
    #1;
    check(!in_ready, "flush blocks simultaneous push while popping");
    step();
    flush = 1'b0;
    out_ready = 1'b0;
    in_valid = 1'b0;
    check(empty && !out_valid && count == 3'd0,
          "flush has priority over simultaneous push and pop");

    in_valid = 1'b1;
    in_data = 32'hFFFF_000F;
    step();
    in_valid = 1'b0;
    check(out_valid && out_data == 32'hFFFF_000F && count == 3'd1,
          "post-priority-flush push emits only fresh data");

    $display("tb_command_fifo PASS");
    $finish;
  end
endmodule
