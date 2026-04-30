module tb_simd_alu;
  logic [3:0] op;
  logic [127:0] operand_a;
  logic [127:0] operand_b;
  logic [127:0] result;
  logic [3:0] zero;

  simd_alu dut (
      .op(op),
      .operand_a(operand_a),
      .operand_b(operand_b),
      .result(result),
      .zero(zero)
  );

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $fatal(1, "%s", message);
      end
    end
  endtask

  function automatic logic [31:0] lane_word(input logic [127:0] value, input int lane);
    begin
      lane_word = value[(lane*32)+:32];
    end
  endfunction

  initial begin
    operand_a = {32'd40, 32'd30, 32'd20, 32'd10};
    operand_b = {32'd4, 32'd3, 32'd2, 32'd1};

    op = 4'h2;
    #1;
    check(lane_word(result, 0) == 32'd11, "ADD lane 0");
    check(lane_word(result, 1) == 32'd22, "ADD lane 1");
    check(lane_word(result, 2) == 32'd33, "ADD lane 2");
    check(lane_word(result, 3) == 32'd44, "ADD lane 3");
    check(zero == 4'b0000, "ADD zero flags clear");

    op = 4'h3;
    #1;
    check(lane_word(result, 0) == 32'd10, "MUL lane 0");
    check(lane_word(result, 1) == 32'd40, "MUL lane 1");
    check(lane_word(result, 2) == 32'd90, "MUL lane 2");
    check(lane_word(result, 3) == 32'd160, "MUL lane 3");

    op = 4'h4;
    #1;
    check(lane_word(result, 0) == 32'd9, "SUB lane 0");
    check(lane_word(result, 1) == 32'd18, "SUB lane 1");
    check(lane_word(result, 2) == 32'd27, "SUB lane 2");
    check(lane_word(result, 3) == 32'd36, "SUB lane 3");

    operand_a = {32'h0000_0008, 32'h0000_0004, 32'h0000_0002, 32'h0000_0001};
    operand_b = {32'd3, 32'd2, 32'd1, 32'd0};
    op = 4'h8;
    #1;
    check(result == {32'h0000_0040, 32'h0000_0010, 32'h0000_0004, 32'h0000_0001},
          "SHL applies per-lane shift amounts");

    op = 4'h9;
    #1;
    check(result == {32'h0000_0001, 32'h0000_0001, 32'h0000_0001, 32'h0000_0001},
          "SHR applies per-lane shift amounts");

    operand_a = {32'hFFFF_0000, 32'h00FF_00FF, 32'h0000_0000, 32'h1234_5678};
    operand_b = {32'h0000_FFFF, 32'h0F0F_0F0F, 32'h0000_0000, 32'hFFFF_0000};
    op = 4'h5;
    #1;
    check(lane_word(result, 0) == 32'h1234_0000, "AND lane 0");
    check(lane_word(result, 1) == 32'h0000_0000, "AND lane 1 zero result");
    check(zero[1], "zero flag set for zero lane");

    op = 4'h6;
    #1;
    check(lane_word(result, 3) == 32'hFFFF_FFFF, "OR lane 3");

    op = 4'h7;
    #1;
    check(lane_word(result, 2) == 32'h0FF0_0FF0, "XOR lane 2");

    op = 4'hF;
    #1;
    check(result == 128'd0 && zero == 4'b1111, "illegal ALU op returns zero");

    $display("tb_simd_alu PASS");
    $finish;
  end
endmodule
