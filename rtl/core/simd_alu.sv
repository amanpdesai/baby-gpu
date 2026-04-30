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
  localparam logic [OP_W-1:0] ALU_PASS_A = 4'h0;
  localparam logic [OP_W-1:0] ALU_PASS_B = 4'h1;
  localparam logic [OP_W-1:0] ALU_ADD = 4'h2;
  localparam logic [OP_W-1:0] ALU_MUL = 4'h3;
  localparam logic [OP_W-1:0] ALU_SUB = 4'h4;
  localparam logic [OP_W-1:0] ALU_AND = 4'h5;
  localparam logic [OP_W-1:0] ALU_OR = 4'h6;
  localparam logic [OP_W-1:0] ALU_XOR = 4'h7;
  localparam logic [OP_W-1:0] ALU_SHL = 4'h8;
  localparam logic [OP_W-1:0] ALU_SHR = 4'h9;

  function automatic logic [DATA_W-1:0] eval_lane(
      input logic [OP_W-1:0] lane_op,
      input logic [DATA_W-1:0] lane_a,
      input logic [DATA_W-1:0] lane_b);
    begin
      case (lane_op)
        ALU_PASS_A: eval_lane = lane_a;
        ALU_PASS_B: eval_lane = lane_b;
        ALU_ADD: eval_lane = lane_a + lane_b;
        ALU_MUL: eval_lane = lane_a * lane_b;
        ALU_SUB: eval_lane = lane_a - lane_b;
        ALU_AND: eval_lane = lane_a & lane_b;
        ALU_OR: eval_lane = lane_a | lane_b;
        ALU_XOR: eval_lane = lane_a ^ lane_b;
        ALU_SHL: eval_lane = lane_a << lane_b[4:0];
        ALU_SHR: eval_lane = lane_a >> lane_b[4:0];
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
