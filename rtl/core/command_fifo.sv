module command_fifo #(
    parameter int DATA_W = 32,
    parameter int DEPTH = 16,
    parameter int COUNT_W = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic reset,
    input logic flush,

    input logic in_valid,
    output logic in_ready,
    input logic [DATA_W-1:0] in_data,

    output logic out_valid,
    input logic out_ready,
    output logic [DATA_W-1:0] out_data,

    output logic full,
    output logic empty,
    output logic [COUNT_W-1:0] count
);
  localparam int PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam logic [PTR_W-1:0] LAST_PTR = PTR_W'(DEPTH - 1);
  localparam logic [COUNT_W-1:0] DEPTH_COUNT = COUNT_W'(DEPTH);

  logic [DATA_W-1:0] mem [DEPTH];
  logic [PTR_W-1:0] rd_ptr;
  logic [PTR_W-1:0] wr_ptr;
  logic push;
  logic pop;

  function automatic logic [PTR_W-1:0] ptr_next(input logic [PTR_W-1:0] ptr);
    if (ptr == LAST_PTR) begin
      ptr_next = '0;
    end else begin
      ptr_next = ptr + 1'b1;
    end
  endfunction

  assign empty = count == '0;
  assign full = count == DEPTH_COUNT;
  assign out_valid = !empty;
  assign out_data = mem[rd_ptr];
  assign pop = out_valid && out_ready;
  assign in_ready = !flush && (!full || pop);
  assign push = in_valid && in_ready;

  always_ff @(posedge clk) begin
    if (reset || flush) begin
      rd_ptr <= '0;
      wr_ptr <= '0;
      count <= '0;
    end else begin
      if (push) begin
        mem[wr_ptr] <= in_data;
        wr_ptr <= ptr_next(wr_ptr);
      end

      if (pop) begin
        rd_ptr <= ptr_next(rd_ptr);
      end

      case ({push, pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end
endmodule
