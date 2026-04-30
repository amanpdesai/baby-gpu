import isa_pkg::*;

module tb_instruction_decoder;
  logic [ISA_WORD_W-1:0] instruction;
  logic [ISA_OPCODE_W-1:0] opcode;
  logic [ISA_REG_ADDR_W-1:0] rd;
  logic [ISA_REG_ADDR_W-1:0] ra;
  logic [ISA_REG_ADDR_W-1:0] rb;
  logic [ISA_IMM18_W-1:0] imm18;
  logic [ISA_SPECIAL_W-1:0] special_reg_id;
  logic [3:0] alu_op;
  logic writes_register;
  logic uses_immediate;
  logic uses_special;
  logic uses_alu;
  logic uses_memory;
  logic memory_write;
  logic memory_store16;
  logic ends_lane;
  logic illegal;

  instruction_decoder dut (
      .instruction(instruction),
      .opcode(opcode),
      .rd(rd),
      .ra(ra),
      .rb(rb),
      .imm18(imm18),
      .special_reg_id(special_reg_id),
      .alu_op(alu_op),
      .writes_register(writes_register),
      .uses_immediate(uses_immediate),
      .uses_special(uses_special),
      .uses_alu(uses_alu),
      .uses_memory(uses_memory),
      .memory_write(memory_write),
      .memory_store16(memory_store16),
      .ends_lane(ends_lane),
      .illegal(illegal)
  );

  function automatic logic [ISA_WORD_W-1:0] pack_r_type(
      input logic [ISA_OPCODE_W-1:0] inst_opcode,
      input logic [ISA_REG_ADDR_W-1:0] inst_rd,
      input logic [ISA_REG_ADDR_W-1:0] inst_ra,
      input logic [ISA_REG_ADDR_W-1:0] inst_rb
  );
    begin
      pack_r_type = {inst_opcode, inst_rd, inst_ra, inst_rb, 14'd0};
    end
  endfunction

  function automatic logic [ISA_WORD_W-1:0] pack_i_type(
      input logic [ISA_OPCODE_W-1:0] inst_opcode,
      input logic [ISA_REG_ADDR_W-1:0] inst_rd,
      input logic [ISA_REG_ADDR_W-1:0] inst_ra,
      input logic [ISA_IMM18_W-1:0] inst_imm18
  );
    begin
      pack_i_type = {inst_opcode, inst_rd, inst_ra, inst_imm18};
    end
  endfunction

  function automatic logic [ISA_WORD_W-1:0] pack_s_type(
      input logic [ISA_OPCODE_W-1:0] inst_opcode,
      input logic [ISA_REG_ADDR_W-1:0] inst_rd,
      input logic [ISA_SPECIAL_W-1:0] inst_special_reg_id
  );
    begin
      pack_s_type = {inst_opcode, inst_rd, inst_special_reg_id, 16'd0};
    end
  endfunction

  task automatic expect_decode(
      input logic [ISA_WORD_W-1:0] test_instruction,
      input logic [ISA_OPCODE_W-1:0] exp_opcode,
      input logic [ISA_REG_ADDR_W-1:0] exp_rd,
      input logic [ISA_REG_ADDR_W-1:0] exp_ra,
      input logic [ISA_REG_ADDR_W-1:0] exp_rb,
      input logic [ISA_IMM18_W-1:0] exp_imm18,
      input logic [ISA_SPECIAL_W-1:0] exp_special_reg_id,
      input logic [3:0] exp_alu_op,
      input logic exp_writes_register,
      input logic exp_uses_immediate,
      input logic exp_uses_special,
      input logic exp_uses_alu,
      input logic exp_ends_lane,
      input logic exp_illegal
  );
    begin
      instruction = test_instruction;
      #1;

      if (opcode !== exp_opcode) $fatal(1, "opcode mismatch");
      if (rd !== exp_rd) $fatal(1, "rd mismatch");
      if (ra !== exp_ra) $fatal(1, "ra mismatch");
      if (rb !== exp_rb) $fatal(1, "rb mismatch");
      if (imm18 !== exp_imm18) $fatal(1, "imm18 mismatch");
      if (special_reg_id !== exp_special_reg_id) $fatal(1, "special register mismatch");
      if (alu_op !== exp_alu_op) $fatal(1, "alu_op mismatch");
      if (writes_register !== exp_writes_register) $fatal(1, "writes_register mismatch");
    if (uses_immediate !== exp_uses_immediate) $fatal(1, "uses_immediate mismatch");
    if (uses_special !== exp_uses_special) $fatal(1, "uses_special mismatch");
    if (uses_alu !== exp_uses_alu) $fatal(1, "uses_alu mismatch");
    if (uses_memory !== 1'b0) $fatal(1, "uses_memory default mismatch");
    if (memory_write !== 1'b0) $fatal(1, "memory_write default mismatch");
    if (memory_store16 !== 1'b0) $fatal(1, "memory_store16 default mismatch");
    if (ends_lane !== exp_ends_lane) $fatal(1, "ends_lane mismatch");
      if (illegal !== exp_illegal) $fatal(1, "illegal mismatch");
  end
  endtask

  task automatic expect_memory_decode(
      input logic [ISA_WORD_W-1:0] test_instruction,
      input logic [ISA_OPCODE_W-1:0] exp_opcode,
      input logic [ISA_REG_ADDR_W-1:0] exp_rd,
      input logic [ISA_REG_ADDR_W-1:0] exp_ra,
      input logic [ISA_REG_ADDR_W-1:0] exp_rb,
      input logic exp_writes_register,
      input logic exp_memory_write,
      input logic exp_memory_store16,
      input logic exp_illegal
  );
  begin
    instruction = test_instruction;
    #1;
    if (opcode !== exp_opcode) $fatal(1, "memory opcode mismatch");
    if (rd !== exp_rd) $fatal(1, "memory rd mismatch");
    if (ra !== exp_ra) $fatal(1, "memory ra mismatch");
    if (rb !== exp_rb) $fatal(1, "memory rb mismatch");
    if (writes_register !== exp_writes_register) $fatal(1, "memory writes_register mismatch");
    if (uses_immediate !== 1'b0) $fatal(1, "memory uses_immediate mismatch");
    if (uses_special !== 1'b0) $fatal(1, "memory uses_special mismatch");
    if (uses_alu !== 1'b0) $fatal(1, "memory uses_alu mismatch");
    if (uses_memory !== !exp_illegal) $fatal(1, "memory uses_memory mismatch");
    if (memory_write !== exp_memory_write) $fatal(1, "memory_write mismatch");
    if (memory_store16 !== exp_memory_store16) $fatal(1, "memory_store16 mismatch");
    if (ends_lane !== 1'b0) $fatal(1, "memory ends_lane mismatch");
    if (illegal !== exp_illegal) $fatal(1, "memory illegal mismatch");
  end
  endtask

  task automatic expect_unimplemented_known_opcode(
      input logic [ISA_OPCODE_W-1:0] test_opcode
  );
    logic [ISA_WORD_W-1:0] test_instruction;
    begin
      test_instruction = {test_opcode, 26'd0};
      expect_decode(
          test_instruction,
          test_opcode,
          4'd0,
          4'd0,
          4'd0,
          18'd0,
          6'd0,
          ISA_ALU_PASS_A,
          1'b0,
          1'b0,
          1'b0,
          1'b0,
          1'b0,
          1'b1
      );
    end
  endtask

  initial begin
    expect_decode(
        pack_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0),
        ISA_OP_NOP,
        4'd0,
        4'd0,
        4'd0,
        18'd0,
        6'd0,
        ISA_ALU_PASS_A,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0),
        ISA_OP_END,
        4'd0,
        4'd0,
        4'd0,
        18'd0,
        6'd0,
        ISA_ALU_PASS_A,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b1,
        1'b0
    );

    expect_decode(
        pack_i_type(ISA_OP_MOVI, 4'd3, 4'd4, 18'h2_aaaa),
        ISA_OP_MOVI,
        4'd3,
        4'd4,
        4'hA,
        18'h2_aaaa,
        6'h12,
        ISA_ALU_PASS_A,
        1'b1,
        1'b1,
        1'b0,
        1'b0,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_s_type(ISA_OP_MOVSR, 4'd5, ISA_SR_GLOBAL_ID_X),
        ISA_OP_MOVSR,
        4'd5,
        4'd0,
        4'd4,
        18'h1_0000,
        ISA_SR_GLOBAL_ID_X,
        ISA_ALU_PASS_A,
        1'b1,
        1'b0,
        1'b1,
        1'b0,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_ADD, 4'd6, 4'd7, 4'd8),
        ISA_OP_ADD,
        4'd6,
        4'd7,
        4'd8,
        18'h2_0000,
        6'h1E,
        ISA_ALU_ADD,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_MUL, 4'd9, 4'd10, 4'd11),
        ISA_OP_MUL,
        4'd9,
        4'd10,
        4'd11,
        18'h2_c000,
        6'h2A,
        ISA_ALU_MUL,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_SUB, 4'd1, 4'd2, 4'd3),
        ISA_OP_SUB,
        4'd1,
        4'd2,
        4'd3,
        18'h0_c000,
        6'h08,
        ISA_ALU_SUB,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_AND, 4'd4, 4'd5, 4'd6),
        ISA_OP_AND,
        4'd4,
        4'd5,
        4'd6,
        18'h1_8000,
        6'h15,
        ISA_ALU_AND,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_OR, 4'd7, 4'd8, 4'd9),
        ISA_OP_OR,
        4'd7,
        4'd8,
        4'd9,
        18'h2_4000,
        6'h22,
        ISA_ALU_OR,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_XOR, 4'd10, 4'd11, 4'd12),
        ISA_OP_XOR,
        4'd10,
        4'd11,
        4'd12,
        18'h3_0000,
        6'h2F,
        ISA_ALU_XOR,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_SHL, 4'd13, 4'd14, 4'd15),
        ISA_OP_SHL,
        4'd13,
        4'd14,
        4'd15,
        18'h3_c000,
        6'h3B,
        ISA_ALU_SHL,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_SHR, 4'd3, 4'd4, 4'd5),
        ISA_OP_SHR,
        4'd3,
        4'd4,
        4'd5,
        18'h1_4000,
        6'h11,
        ISA_ALU_SHR,
        1'b1,
        1'b0,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_decode(
        pack_r_type(ISA_OP_ADD, 4'd1, 4'd2, 4'd3) | 32'd1,
        ISA_OP_ADD,
        4'd1,
        4'd2,
        4'd3,
        18'h0_c001,
        6'h08,
        ISA_ALU_ADD,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b1
    );

    expect_decode(
        pack_s_type(ISA_OP_MOVSR, 4'd2, ISA_SR_FRAMEBUFFER_WIDTH) | 32'd1,
        ISA_OP_MOVSR,
        4'd2,
        4'd2,
        4'd8,
        18'h2_0001,
        ISA_SR_FRAMEBUFFER_WIDTH,
        ISA_ALU_PASS_A,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b0,
        1'b1
    );

    expect_memory_decode(
        pack_r_type(ISA_OP_LOAD, 4'd3, 4'd4, 4'd0),
        ISA_OP_LOAD,
        4'd3,
        4'd4,
        4'd0,
        1'b1,
        1'b0,
        1'b0,
        1'b0
    );

    expect_memory_decode(
        pack_r_type(ISA_OP_STORE, 4'd0, 4'd5, 4'd6),
        ISA_OP_STORE,
        4'd0,
        4'd5,
        4'd6,
        1'b0,
        1'b1,
        1'b0,
        1'b0
    );

    expect_memory_decode(
        pack_r_type(ISA_OP_STORE16, 4'd0, 4'd7, 4'd8),
        ISA_OP_STORE16,
        4'd0,
        4'd7,
        4'd8,
        1'b0,
        1'b1,
        1'b1,
        1'b0
    );

    expect_memory_decode(
        pack_r_type(ISA_OP_LOAD, 4'd3, 4'd4, 4'd1),
        ISA_OP_LOAD,
        4'd3,
        4'd4,
        4'd1,
        1'b0,
        1'b0,
        1'b0,
        1'b1
    );

    expect_memory_decode(
        pack_r_type(ISA_OP_STORE, 4'd1, 4'd5, 4'd6),
        ISA_OP_STORE,
        4'd1,
        4'd5,
        4'd6,
        1'b0,
        1'b0,
        1'b0,
        1'b1
    );

    expect_unimplemented_known_opcode(ISA_OP_CMP);
    expect_unimplemented_known_opcode(ISA_OP_BRA);
    expect_unimplemented_known_opcode(6'h3F);

    $display("tb_instruction_decoder PASS");
    $finish;
  end
endmodule
