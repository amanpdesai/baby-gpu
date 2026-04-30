module simd_alu_formal (
    input logic clk
);
    // Bounded proof configuration: small data width keeps bit-vector multiply
    // cheap while still checking all implemented opcodes across multiple lanes.
    localparam int LANES = 3;
    localparam int DATA_W = 8;
    localparam int OP_W = 4;

    (* anyseq *) logic [OP_W-1:0] op;
    (* anyseq *) logic [(LANES*DATA_W)-1:0] operand_a;
    (* anyseq *) logic [(LANES*DATA_W)-1:0] operand_b;
    logic [(LANES*DATA_W)-1:0] result;
    logic [LANES-1:0] zero;

    simd_alu #(
        .LANES(LANES),
        .DATA_W(DATA_W),
        .OP_W(OP_W)
    ) dut (
        .op(op),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result),
        .zero(zero)
    );

    genvar lane;

    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : lane_checks
            logic [DATA_W-1:0] lane_a;
            logic [DATA_W-1:0] lane_b;
            logic [DATA_W-1:0] lane_result;
            logic [(DATA_W*2)-1:0] product;

            assign lane_a = operand_a[(lane*DATA_W)+:DATA_W];
            assign lane_b = operand_b[(lane*DATA_W)+:DATA_W];
            assign lane_result = result[(lane*DATA_W)+:DATA_W];
            assign product = lane_a * lane_b;

            always_comb begin
                unique case (op)
                    4'h0: assert(lane_result == lane_a);
                    4'h1: assert(lane_result == lane_b);
                    4'h2: assert(lane_result == (lane_a + lane_b));
                    4'h3: assert(lane_result == product[DATA_W-1:0]);
                    4'h4: assert(lane_result == (lane_a - lane_b));
                    4'h5: assert(lane_result == (lane_a & lane_b));
                    4'h6: assert(lane_result == (lane_a | lane_b));
                    4'h7: assert(lane_result == (lane_a ^ lane_b));
                    4'h8: assert(lane_result == (lane_a << lane_b[4:0]));
                    4'h9: assert(lane_result == (lane_a >> lane_b[4:0]));
                    default: assert(lane_result == '0);
                endcase

                assert(zero[lane] == (lane_result == '0));
            end
        end
    endgenerate
endmodule
