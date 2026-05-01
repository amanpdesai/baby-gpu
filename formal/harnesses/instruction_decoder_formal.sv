module instruction_decoder_formal (
    input logic [isa_pkg::ISA_WORD_W-1:0] instruction
);
    logic [isa_pkg::ISA_OPCODE_W-1:0] opcode;
    logic [isa_pkg::ISA_REG_ADDR_W-1:0] rd;
    logic [isa_pkg::ISA_REG_ADDR_W-1:0] ra;
    logic [isa_pkg::ISA_REG_ADDR_W-1:0] rb;
    logic [isa_pkg::ISA_IMM18_W-1:0] imm18;
    logic [isa_pkg::ISA_BRANCH_OFFSET_W-1:0] branch_offset;
    logic [isa_pkg::ISA_CMP_COND_W-1:0] cmp_op;
    logic [isa_pkg::ISA_SPECIAL_W-1:0] special_reg_id;
    logic [3:0] alu_op;
    logic writes_register;
    logic uses_immediate;
    logic uses_special;
    logic uses_alu;
    logic uses_compare;
    logic uses_memory;
    logic uses_branch;
    logic memory_write;
    logic memory_store16;
    logic memory_predicated;
    logic ends_lane;
    logic illegal;

    logic cmp_reserved_clear;

    instruction_decoder dut (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .ra(ra),
        .rb(rb),
        .imm18(imm18),
        .branch_offset(branch_offset),
        .cmp_op(cmp_op),
        .special_reg_id(special_reg_id),
        .alu_op(alu_op),
        .writes_register(writes_register),
        .uses_immediate(uses_immediate),
        .uses_special(uses_special),
        .uses_alu(uses_alu),
        .uses_compare(uses_compare),
        .uses_memory(uses_memory),
        .uses_branch(uses_branch),
        .memory_write(memory_write),
        .memory_store16(memory_store16),
        .memory_predicated(memory_predicated),
        .ends_lane(ends_lane),
        .illegal(illegal)
    );

    assign cmp_reserved_clear = instruction[13:isa_pkg::ISA_CMP_COND_W] == '0;

    always_comb begin
        assert(opcode == instruction[isa_pkg::ISA_OPCODE_MSB:isa_pkg::ISA_OPCODE_LSB]);
        assert(rd == instruction[isa_pkg::ISA_RD_MSB:isa_pkg::ISA_RD_LSB]);
        assert(ra == instruction[isa_pkg::ISA_RA_MSB:isa_pkg::ISA_RA_LSB]);
        assert(rb == instruction[isa_pkg::ISA_RB_MSB:isa_pkg::ISA_RB_LSB]);
        assert(imm18 == instruction[isa_pkg::ISA_IMM18_MSB:isa_pkg::ISA_IMM18_LSB]);
        assert(branch_offset ==
               instruction[isa_pkg::ISA_BRANCH_OFFSET_MSB:isa_pkg::ISA_BRANCH_OFFSET_LSB]);
        assert(cmp_op == instruction[isa_pkg::ISA_CMP_COND_MSB:isa_pkg::ISA_CMP_COND_LSB]);
        assert(special_reg_id ==
               instruction[isa_pkg::ISA_SPECIAL_MSB:isa_pkg::ISA_SPECIAL_LSB]);

        if (opcode == isa_pkg::ISA_OP_CMP) begin
            assert(illegal == (!cmp_reserved_clear || (cmp_op > isa_pkg::ISA_CMP_GES)));
            assert(writes_register ==
                   (cmp_reserved_clear && (cmp_op <= isa_pkg::ISA_CMP_GES)));
            assert(uses_compare ==
                   (cmp_reserved_clear && (cmp_op <= isa_pkg::ISA_CMP_GES)));
            assert(!uses_memory && !memory_write && !memory_predicated);
        end

        if (opcode == isa_pkg::ISA_OP_PSTORE) begin
            assert(!illegal && !writes_register && uses_immediate && uses_memory);
            assert(memory_write && !memory_store16 && memory_predicated);
        end

        if (opcode == isa_pkg::ISA_OP_PSTORE16) begin
            assert(!illegal && !writes_register && uses_immediate && uses_memory);
            assert(memory_write && memory_store16 && memory_predicated);
        end

        if (opcode == 6'h3f) begin
            assert(illegal && !writes_register && !uses_memory && !uses_branch);
            assert(!memory_write && !memory_store16 && !memory_predicated);
        end
    end
endmodule
