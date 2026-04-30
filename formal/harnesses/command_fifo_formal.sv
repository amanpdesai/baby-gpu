module command_fifo_formal (
    input logic clk
);
  localparam int DATA_W = 8;
  localparam int DEPTH = 4;
  localparam int COUNT_W = $clog2(DEPTH + 1);

  (* anyseq *) logic reset;
  (* anyseq *) logic flush;
  (* anyseq *) logic in_valid;
  logic in_ready;
  (* anyseq *) logic [DATA_W-1:0] in_data;
  logic out_valid;
  (* anyseq *) logic out_ready;
  logic [DATA_W-1:0] out_data;
  logic full;
  logic empty;
  logic [COUNT_W-1:0] count;
  logic past_valid;

  command_fifo #(
      .DATA_W(DATA_W),
      .DEPTH(DEPTH),
      .COUNT_W(COUNT_W)
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

  initial begin
    assume(reset);
    past_valid = 1'b0;
    assume(!past_valid);
  end

  always @(posedge clk) begin
    past_valid <= 1'b1;

    if (!past_valid) begin
      assume(reset);
    end

    if (past_valid && $past(reset || flush)) begin
      assert(count == '0);
      assert(empty);
      assert(!full);
      assert(!out_valid);
    end

    cover(count == COUNT_W'(DEPTH));
    cover(past_valid && $past(count == COUNT_W'(DEPTH)) && count == '0);
  end

  always_comb begin
    if (past_valid) begin
      assert(count <= COUNT_W'(DEPTH));
      assert(full == (count == COUNT_W'(DEPTH)));
      assert(empty == (count == '0));
      assert(in_ready == (!flush && (!full || (out_valid && out_ready))));
      assert(out_valid == !empty);
    end
  end
endmodule
