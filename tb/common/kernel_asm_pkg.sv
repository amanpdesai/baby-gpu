package kernel_asm_pkg;
  import isa_pkg::*;

  function automatic logic [ISA_WORD_W-1:0] kgpu_nop();
    kgpu_nop = isa_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_end();
    kgpu_end = isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_movi(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_IMM18_W-1:0] imm18
  );
    kgpu_movi = isa_i_type(ISA_OP_MOVI, rd, 4'd0, imm18);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_movsr(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_SPECIAL_W-1:0] special_reg_id
  );
    kgpu_movsr = isa_s_type(ISA_OP_MOVSR, rd, special_reg_id);
  endfunction

    function automatic logic [ISA_WORD_W-1:0] kgpu_add(
        input logic [ISA_REG_ADDR_W-1:0] rd,
        input logic [ISA_REG_ADDR_W-1:0] ra,
        input logic [ISA_REG_ADDR_W-1:0] rb
    );
        kgpu_add = isa_r_type(ISA_OP_ADD, rd, ra, rb);
    endfunction

    function automatic logic [ISA_WORD_W-1:0] kgpu_sub(
        input logic [ISA_REG_ADDR_W-1:0] rd,
        input logic [ISA_REG_ADDR_W-1:0] ra,
        input logic [ISA_REG_ADDR_W-1:0] rb
    );
        kgpu_sub = isa_r_type(ISA_OP_SUB, rd, ra, rb);
    endfunction

    function automatic logic [ISA_WORD_W-1:0] kgpu_mul(
        input logic [ISA_REG_ADDR_W-1:0] rd,
        input logic [ISA_REG_ADDR_W-1:0] ra,
        input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_mul = isa_r_type(ISA_OP_MUL, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_and(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_and = isa_r_type(ISA_OP_AND, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_or(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_or = isa_r_type(ISA_OP_OR, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_xor(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_xor = isa_r_type(ISA_OP_XOR, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_shl(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_shl = isa_r_type(ISA_OP_SHL, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_shr(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb
  );
    kgpu_shr = isa_r_type(ISA_OP_SHR, rd, ra, rb);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_cmp(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] rb,
      input logic [ISA_CMP_COND_W-1:0] cond
  );
    kgpu_cmp = isa_cmp_type(rd, ra, rb, cond);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_bra(
      input logic [ISA_REG_ADDR_W-1:0] pred,
      input logic [ISA_BRANCH_OFFSET_W-1:0] offset
  );
    kgpu_bra = isa_b_type(ISA_OP_BRA, pred, offset);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_load(
      input logic [ISA_REG_ADDR_W-1:0] rd,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_IMM18_W-1:0] offset
  );
    kgpu_load = isa_m_type(ISA_OP_LOAD, rd, ra, offset);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_store(
      input logic [ISA_REG_ADDR_W-1:0] rs,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_IMM18_W-1:0] offset
  );
    kgpu_store = isa_m_type(ISA_OP_STORE, rs, ra, offset);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_store16(
      input logic [ISA_REG_ADDR_W-1:0] rs,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_IMM18_W-1:0] offset
  );
    kgpu_store16 = isa_m_type(ISA_OP_STORE16, rs, ra, offset);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_pstore(
      input logic [ISA_REG_ADDR_W-1:0] rs,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] pred,
      input logic [ISA_PRED_OFFSET_W-1:0] offset
  );
    kgpu_pstore = isa_p_type(ISA_OP_PSTORE, rs, ra, pred, offset);
  endfunction

  function automatic logic [ISA_WORD_W-1:0] kgpu_pstore16(
      input logic [ISA_REG_ADDR_W-1:0] rs,
      input logic [ISA_REG_ADDR_W-1:0] ra,
      input logic [ISA_REG_ADDR_W-1:0] pred,
      input logic [ISA_PRED_OFFSET_W-1:0] offset
  );
    kgpu_pstore16 = isa_p_type(ISA_OP_PSTORE16, rs, ra, pred, offset);
  endfunction
endpackage
