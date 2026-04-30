import isa_pkg::*;

module instruction_decoder (
    input logic [ISA_WORD_W-1:0] instruction,
    output logic [ISA_OPCODE_W-1:0] opcode,
    output logic [ISA_REG_ADDR_W-1:0] rd,
    output logic [ISA_REG_ADDR_W-1:0] ra,
    output logic [ISA_REG_ADDR_W-1:0] rb,
    output logic [ISA_IMM18_W-1:0] imm18,
    output logic [ISA_SPECIAL_W-1:0] special_reg_id,
    output logic [3:0] alu_op,
    output logic writes_register,
    output logic uses_immediate,
    output logic uses_special,
    output logic uses_alu,
    output logic ends_lane,
    output logic illegal
);
  logic r_type_reserved_clear;
  logic s_type_reserved_clear;

  assign opcode = instruction[ISA_OPCODE_MSB:ISA_OPCODE_LSB];
  assign rd = instruction[ISA_RD_MSB:ISA_RD_LSB];
  assign ra = instruction[ISA_RA_MSB:ISA_RA_LSB];
  assign rb = instruction[ISA_RB_MSB:ISA_RB_LSB];
  assign imm18 = instruction[ISA_IMM18_MSB:ISA_IMM18_LSB];
  assign special_reg_id = instruction[ISA_SPECIAL_MSB:ISA_SPECIAL_LSB];

  assign r_type_reserved_clear = instruction[13:0] == 14'd0;
  assign s_type_reserved_clear = instruction[15:0] == 16'd0;

  always_comb begin
    alu_op = ISA_ALU_PASS_A;
    writes_register = 1'b0;
    uses_immediate = 1'b0;
    uses_special = 1'b0;
    uses_alu = 1'b0;
    ends_lane = 1'b0;
    illegal = 1'b0;

    case (opcode)
      ISA_OP_NOP: begin
        illegal = !r_type_reserved_clear;
      end

      ISA_OP_END: begin
        ends_lane = r_type_reserved_clear;
        illegal = !r_type_reserved_clear;
      end

      ISA_OP_MOVI: begin
        writes_register = 1'b1;
        uses_immediate = 1'b1;
      end

      ISA_OP_MOVSR: begin
        writes_register = s_type_reserved_clear;
        uses_special = s_type_reserved_clear;
        illegal = !s_type_reserved_clear;
      end

      ISA_OP_ADD: begin
        writes_register = r_type_reserved_clear;
        uses_alu = r_type_reserved_clear;
        alu_op = ISA_ALU_ADD;
        illegal = !r_type_reserved_clear;
      end

      ISA_OP_MUL: begin
        writes_register = r_type_reserved_clear;
        uses_alu = r_type_reserved_clear;
        alu_op = ISA_ALU_MUL;
        illegal = !r_type_reserved_clear;
      end

      default: begin
        illegal = 1'b1;
      end
    endcase
  end
endmodule
