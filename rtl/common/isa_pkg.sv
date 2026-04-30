package isa_pkg;
  localparam int ISA_WORD_W = 32;
  localparam int ISA_OPCODE_W = 6;
  localparam int ISA_REG_ADDR_W = 4;
  localparam int ISA_IMM18_W = 18;
  localparam int ISA_SPECIAL_W = 6;

  localparam int ISA_OPCODE_MSB = 31;
  localparam int ISA_OPCODE_LSB = 26;
  localparam int ISA_RD_MSB = 25;
  localparam int ISA_RD_LSB = 22;
  localparam int ISA_RA_MSB = 21;
  localparam int ISA_RA_LSB = 18;
  localparam int ISA_RB_MSB = 17;
  localparam int ISA_RB_LSB = 14;
  localparam int ISA_IMM18_MSB = 17;
  localparam int ISA_IMM18_LSB = 0;
  localparam int ISA_SPECIAL_MSB = 21;
  localparam int ISA_SPECIAL_LSB = 16;

  typedef enum logic [ISA_OPCODE_W-1:0] {
    ISA_OP_NOP = 6'h00,
    ISA_OP_END = 6'h01,
    ISA_OP_MOVI = 6'h02,
    ISA_OP_MOVSR = 6'h03,
    ISA_OP_ADD = 6'h04,
    ISA_OP_MUL = 6'h05,
    ISA_OP_LOAD = 6'h06,
    ISA_OP_STORE = 6'h07,
    ISA_OP_STORE16 = 6'h08,
    ISA_OP_CMP = 6'h09,
    ISA_OP_BRA = 6'h0A,
    ISA_OP_SUB = 6'h0B,
    ISA_OP_AND = 6'h0C,
    ISA_OP_OR = 6'h0D,
    ISA_OP_XOR = 6'h0E,
    ISA_OP_SHL = 6'h0F,
    ISA_OP_SHR = 6'h10
  } isa_opcode_e;

  typedef enum logic [3:0] {
    ISA_ALU_PASS_A = 4'h0,
    ISA_ALU_PASS_B = 4'h1,
    ISA_ALU_ADD = 4'h2,
    ISA_ALU_MUL = 4'h3,
    ISA_ALU_SUB = 4'h4,
    ISA_ALU_AND = 4'h5,
    ISA_ALU_OR = 4'h6,
    ISA_ALU_XOR = 4'h7,
    ISA_ALU_SHL = 4'h8,
    ISA_ALU_SHR = 4'h9
  } isa_alu_op_e;

  typedef enum logic [ISA_SPECIAL_W-1:0] {
    ISA_SR_LANE_ID = 6'h00,
    ISA_SR_GLOBAL_ID_X = 6'h01,
    ISA_SR_GLOBAL_ID_Y = 6'h02,
    ISA_SR_LINEAR_GLOBAL_ID = 6'h03,
    ISA_SR_GROUP_ID_X = 6'h04,
    ISA_SR_GROUP_ID_Y = 6'h05,
    ISA_SR_LOCAL_ID_X = 6'h06,
    ISA_SR_LOCAL_ID_Y = 6'h07,
    ISA_SR_ARG_BASE = 6'h08,
    ISA_SR_FRAMEBUFFER_BASE = 6'h09,
    ISA_SR_FRAMEBUFFER_WIDTH = 6'h0A,
    ISA_SR_FRAMEBUFFER_HEIGHT = 6'h0B
  } isa_special_reg_e;

  function automatic logic [ISA_WORD_W-1:0] isa_r_type(
      input logic [ISA_OPCODE_W-1:0] opcode,
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb);
    isa_r_type = {opcode, rd, ra, rb, 14'd0};
  endfunction

  function automatic logic [ISA_WORD_W-1:0] isa_i_type(
      input logic [ISA_OPCODE_W-1:0] opcode,
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_IMM18_W-1:0] imm18);
    isa_i_type = {opcode, rd, ra, imm18};
  endfunction

  function automatic logic [ISA_WORD_W-1:0] isa_m_type(
      input logic [ISA_OPCODE_W-1:0] opcode,
      input logic [ISA_REG_ADDR_W-1:0] rd_rs,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_IMM18_W-1:0] offset18);
    isa_m_type = {opcode, rd_rs, ra, offset18};
  endfunction

  function automatic logic [ISA_WORD_W-1:0] isa_s_type(
      input logic [ISA_OPCODE_W-1:0] opcode,
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_SPECIAL_W-1:0] special_id);
    isa_s_type = {opcode, rd, special_id, 16'd0};
  endfunction
endpackage
