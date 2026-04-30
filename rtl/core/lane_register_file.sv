module lane_register_file #(
    parameter int LANES = 4,
    parameter int REGS = 16,
    parameter int DATA_W = 32,
    parameter int REG_ADDR_W = $clog2(REGS)
) (
    input logic clk,
    input logic reset,

    input logic [REG_ADDR_W-1:0] read_addr_a,
    output logic [(LANES*DATA_W)-1:0] read_data_a,
    input logic [REG_ADDR_W-1:0] read_addr_b,
    output logic [(LANES*DATA_W)-1:0] read_data_b,

    input logic [LANES-1:0] write_enable,
    input logic [REG_ADDR_W-1:0] write_addr,
    input logic [(LANES*DATA_W)-1:0] write_data
);
  logic [DATA_W-1:0] regs [LANES][REGS];

  genvar lane;

  generate
    for (lane = 0; lane < LANES; lane = lane + 1) begin : gen_read
      assign read_data_a[(lane*DATA_W)+:DATA_W] =
          (read_addr_a == '0) ? '0 : regs[lane][read_addr_a];
      assign read_data_b[(lane*DATA_W)+:DATA_W] =
          (read_addr_b == '0) ? '0 : regs[lane][read_addr_b];
    end
  endgenerate

  integer lane_idx;
  integer reg_idx;

  always_ff @(posedge clk) begin
    if (reset) begin
      for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
        for (reg_idx = 0; reg_idx < REGS; reg_idx = reg_idx + 1) begin
          regs[lane_idx][reg_idx] <= '0;
        end
      end
    end else begin
      for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
        if (write_enable[lane_idx] && (write_addr != '0)) begin
          regs[lane_idx][write_addr] <= write_data[(lane_idx*DATA_W)+:DATA_W];
        end
      end
    end
  end
endmodule
