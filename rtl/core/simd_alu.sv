module simd_alu #(
    parameter int LANES = 4,
    parameter int DATA_W = 32,
    parameter int OP_W = 4
) (
    input logic [OP_W-1:0] op,
    input logic [(LANES*DATA_W)-1:0] operand_a,
    input logic [(LANES*DATA_W)-1:0] operand_b,
    output logic [(LANES*DATA_W)-1:0] result,
    output logic [LANES-1:0] zero
);
  function automatic logic [DATA_W-1:0] eval_lane(
      input logic [OP_W-1:0] lane_op,
      input logic [DATA_W-1:0] lane_a,
      input logic [DATA_W-1:0] lane_b);
    begin
      case (lane_op)
        4'h0: eval_lane = lane_a;
        4'h1: eval_lane = lane_b;
        4'h2: eval_lane = lane_a + lane_b;
        4'h3: eval_lane = lane_a * lane_b;
        4'h4: eval_lane = lane_a - lane_b;
        4'h5: eval_lane = lane_a & lane_b;
        4'h6: eval_lane = lane_a | lane_b;
        4'h7: eval_lane = lane_a ^ lane_b;
        4'h8: eval_lane = lane_a << lane_b[4:0];
        4'h9: eval_lane = lane_a >> lane_b[4:0];
        default: eval_lane = '0;
      endcase
    end
  endfunction

  genvar lane;

  generate
    for (lane = 0; lane < LANES; lane = lane + 1) begin : gen_lane
      assign result[(lane*DATA_W)+:DATA_W] = eval_lane(
          op,
          operand_a[(lane*DATA_W)+:DATA_W],
          operand_b[(lane*DATA_W)+:DATA_W]);
      assign zero[lane] = result[(lane*DATA_W)+:DATA_W] == '0;
    end
  endgenerate
endmodule
