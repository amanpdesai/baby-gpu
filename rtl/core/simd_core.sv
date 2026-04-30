import isa_pkg::*;

module simd_core #(
    parameter int LANES = 4,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int ADDR_W = 32,
    parameter int PC_W = 8,
    parameter int REGS = 16,
    parameter int REG_ADDR_W = $clog2(REGS),
    localparam int LANES_PORT_W = (LANES < 1) ? 1 : LANES,
    localparam int DATA_PORT_W = (DATA_W < ISA_IMM18_W) ? ISA_IMM18_W : DATA_W,
    localparam int COORD_PORT_W = (COORD_W < 1) ? 1 : COORD_W,
    localparam int ADDR_PORT_W = (ADDR_W < 1) ? 1 : ADDR_W,
    localparam int PC_PORT_W = (PC_W < 1) ? 1 : PC_W,
    localparam int REG_ADDR_PORT_W = (REG_ADDR_W < 1) ? 1 : REG_ADDR_W
) (
    input logic clk,
    input logic reset,

    input logic start,
    input logic [LANES_PORT_W-1:0] launch_active_mask,
    output logic launch_ready,
    output logic busy,
    output logic done,
    output logic error,

    output logic [PC_PORT_W-1:0] instruction_addr,
    input logic [ISA_WORD_W-1:0] instruction,

    output logic data_req_valid,
    input logic data_req_ready,
    output logic data_req_write,
    output logic [ADDR_PORT_W-1:0] data_req_addr,
    output logic [31:0] data_req_wdata,
    output logic [3:0] data_req_wmask,
    input logic data_rsp_valid,
    output logic data_rsp_ready,
    input logic [31:0] data_rsp_rdata,

    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] lane_id,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] global_id_x,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] global_id_y,
    input logic [(LANES_PORT_W*DATA_PORT_W)-1:0] linear_global_id,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] group_id_x,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] group_id_y,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] local_id_x,
    input logic [(LANES_PORT_W*COORD_PORT_W)-1:0] local_id_y,
    input logic [ADDR_PORT_W-1:0] arg_base,
    input logic [ADDR_PORT_W-1:0] framebuffer_base,
    input logic [COORD_PORT_W-1:0] framebuffer_width,
    input logic [COORD_PORT_W-1:0] framebuffer_height,

    input logic [REG_ADDR_PORT_W-1:0] debug_read_addr,
    output logic [(LANES_PORT_W*DATA_PORT_W)-1:0] debug_read_data
);
  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_RUN,
    STATE_WAIT_LSU,
    STATE_DONE,
    STATE_ERROR
  } state_e;

  localparam logic [1:0] LSU_OP_LOAD = 2'd0;
  localparam logic [1:0] LSU_OP_STORE = 2'd1;
  localparam logic [1:0] LSU_OP_STORE16 = 2'd2;

  initial begin : parameter_guards
    if (LANES < 1) begin
      $fatal(1, "simd_core requires LANES >= 1");
    end
    if (DATA_W < ISA_IMM18_W) begin
      $fatal(1, "simd_core requires DATA_W >= ISA_IMM18_W");
    end
    if (COORD_W < 1) begin
      $fatal(1, "simd_core requires COORD_W >= 1");
    end
    if (COORD_W > DATA_W) begin
      $fatal(1, "simd_core requires COORD_W <= DATA_W for special-register reads");
    end
    if (ADDR_W < 1) begin
      $fatal(1, "simd_core requires ADDR_W >= 1");
    end
    if (ADDR_W > DATA_W) begin
      $fatal(1, "simd_core requires ADDR_W <= DATA_W for special-register reads");
    end
    if (DATA_PORT_W < 32) begin
      $fatal(1, "simd_core requires at least 32-bit data registers for memory operations");
    end
    if (REGS < 2) begin
      $fatal(1, "simd_core requires REGS >= 2");
    end
    if (REG_ADDR_W > ISA_REG_ADDR_W) begin
      $fatal(1, "simd_core requires REG_ADDR_W <= ISA_REG_ADDR_W");
    end
    if (REG_ADDR_W < 1) begin
      $fatal(1, "simd_core requires REG_ADDR_W >= 1");
    end
    if (REGS > 16) begin
      $fatal(1, "simd_core supports at most 16 registers with the current ISA encoding");
    end
    if ((1 << REG_ADDR_W) < REGS) begin
      $fatal(1, "simd_core requires REG_ADDR_W to address all REGS entries");
    end
    if (PC_W < 1) begin
      $fatal(1, "simd_core requires PC_W >= 1");
    end
  end

  state_e state;
  logic [PC_PORT_W-1:0] pc;
  logic [LANES_PORT_W-1:0] active_mask;
  logic launch_armed;
  logic launch_accept;

  logic [ISA_OPCODE_W-1:0] decoded_opcode;
  logic [ISA_REG_ADDR_W-1:0] decoded_rd;
    logic [ISA_REG_ADDR_W-1:0] decoded_ra;
    logic [ISA_REG_ADDR_W-1:0] decoded_rb;
    logic [ISA_IMM18_W-1:0] decoded_imm18;
    logic [ISA_BRANCH_OFFSET_W-1:0] decoded_branch_offset;
    logic [ISA_SPECIAL_W-1:0] decoded_special_reg_id;
  localparam int REG_ADDR_SELECT_W =
      (REG_ADDR_PORT_W > ISA_REG_ADDR_W) ? ISA_REG_ADDR_W : REG_ADDR_PORT_W;
  localparam int SPECIAL_COORD_W =
      (COORD_PORT_W > DATA_PORT_W) ? DATA_PORT_W : COORD_PORT_W;
  localparam int SPECIAL_ADDR_W =
      (ADDR_PORT_W > DATA_PORT_W) ? DATA_PORT_W : ADDR_PORT_W;
  logic [3:0] decoded_alu_op;
  logic decoded_writes_register;
  logic decoded_uses_immediate;
  logic decoded_uses_special;
    logic decoded_uses_alu;
    logic decoded_uses_memory;
    logic decoded_uses_branch;
    logic decoded_memory_write;
  logic decoded_memory_store16;
  logic decoded_ends_lane;
  logic decoder_illegal;

  logic [REG_ADDR_PORT_W-1:0] rf_read_addr_a;
  logic [REG_ADDR_PORT_W-1:0] rf_read_addr_b;
  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] rf_read_data_a;
  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] rf_read_data_b;
  logic [LANES_PORT_W-1:0] rf_write_enable;
  logic [REG_ADDR_PORT_W-1:0] rf_write_addr;
  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] rf_write_data;

  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] alu_result;
  logic [LANES_PORT_W-1:0] alu_zero;
  logic [(LANES_PORT_W*DATA_PORT_W)-1:0] special_value;
  logic special_illegal;
  logic instruction_has_error;
  logic lsu_start_valid;
  logic lsu_start_ready;
  logic lsu_done;
  logic lsu_error;
  logic [1:0] lsu_op;
  logic lsu_writes_register_q;
  logic [REG_ADDR_PORT_W-1:0] lsu_write_addr_q;
  logic [(LANES_PORT_W*ADDR_PORT_W)-1:0] lsu_lane_addr;
  logic [(LANES_PORT_W*32)-1:0] lsu_lane_wdata;
  logic [(LANES_PORT_W*32)-1:0] lsu_lane_rdata;
  logic [LANES_PORT_W-1:0] lsu_lane_rvalid;
    logic [(LANES_PORT_W*DATA_PORT_W)-1:0] immediate_value;
    logic [(LANES_PORT_W*DATA_PORT_W)-1:0] lsu_writeback_value;
    logic [LANES_PORT_W-1:0] branch_lane_taken;
    logic branch_any_taken;
    logic branch_any_not_taken;
    logic branch_divergent;
    logic branch_taken;
    logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_lane_id;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_global_id_x;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_global_id_y;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_group_id_x;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_group_id_y;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_local_id_x;
  logic [(LANES_PORT_W*SPECIAL_COORD_W)-1:0] special_local_id_y;
  logic [SPECIAL_ADDR_W-1:0] special_arg_base;
  logic [SPECIAL_ADDR_W-1:0] special_framebuffer_base;
  logic [SPECIAL_COORD_W-1:0] special_framebuffer_width;
  logic [SPECIAL_COORD_W-1:0] special_framebuffer_height;

  assign busy = (state == STATE_RUN) || (state == STATE_WAIT_LSU);
  assign done = state == STATE_DONE;
  assign error = state == STATE_ERROR;
  assign launch_ready = (state == STATE_IDLE) && launch_armed;
  assign launch_accept = start && launch_ready;
  assign instruction_addr = pc;
  // Debug reads share the register-file read port used by instruction decode.
  // The read data is only contractually valid while the core is not busy.
    assign rf_read_addr_a = busy ?
        (decoded_uses_branch ? fit_reg_addr(decoded_rd) : fit_reg_addr(decoded_ra)) :
        debug_read_addr;
  assign rf_read_addr_b = decoded_memory_write ? fit_reg_addr(decoded_rd) : fit_reg_addr(decoded_rb);
  assign debug_read_data = rf_read_data_a;
  assign rf_write_addr = (state == STATE_WAIT_LSU) ? lsu_write_addr_q : fit_reg_addr(decoded_rd);
  assign instruction_has_error = decoder_illegal || (decoded_uses_special && special_illegal);
  assign rf_write_enable =
      ((state == STATE_WAIT_LSU) && lsu_writes_register_q && lsu_done && !lsu_error) ? lsu_lane_rvalid :
      ((state == STATE_RUN) && decoded_writes_register && !decoded_uses_memory && !instruction_has_error) ?
          active_mask : '0;

  function automatic logic [(LANES_PORT_W*DATA_PORT_W)-1:0] replicate_immediate(
      input logic [ISA_IMM18_W-1:0] imm);
    integer lane;
    begin
      replicate_immediate = '0;
      for (lane = 0; lane < LANES_PORT_W; lane = lane + 1) begin
        replicate_immediate[(lane*DATA_PORT_W)+:DATA_PORT_W] = DATA_PORT_W'(imm);
      end
    end
  endfunction

    function automatic logic [REG_ADDR_PORT_W-1:0] fit_reg_addr(
        input logic [ISA_REG_ADDR_W-1:0] encoded_addr);
        begin
      fit_reg_addr = '0;
      fit_reg_addr[REG_ADDR_SELECT_W-1:0] = encoded_addr[REG_ADDR_SELECT_W-1:0];
        end
    endfunction

    function automatic logic [PC_PORT_W-1:0] branch_target(
        input logic [PC_PORT_W-1:0] base_pc,
        input logic [ISA_BRANCH_OFFSET_W-1:0] offset
    );
        localparam int BRANCH_CALC_W =
            (PC_PORT_W > ISA_BRANCH_OFFSET_W) ? (PC_PORT_W + 1) : (ISA_BRANCH_OFFSET_W + 1);
        logic signed [BRANCH_CALC_W-1:0] pc_ext;
        logic signed [BRANCH_CALC_W-1:0] offset_ext;
        logic signed [BRANCH_CALC_W-1:0] sum;
        begin
            pc_ext = '0;
            pc_ext[PC_PORT_W-1:0] = base_pc;
            offset_ext = $signed({{(BRANCH_CALC_W-ISA_BRANCH_OFFSET_W)
                {offset[ISA_BRANCH_OFFSET_W-1]}}, offset});
            sum = pc_ext + offset_ext + BRANCH_CALC_W'(1);
            branch_target = sum[PC_PORT_W-1:0];
        end
    endfunction

    assign immediate_value = replicate_immediate(decoded_imm18);
  assign lsu_op = decoded_memory_store16 ? LSU_OP_STORE16 :
                  decoded_memory_write ? LSU_OP_STORE :
                  LSU_OP_LOAD;
  assign lsu_start_valid = (state == STATE_RUN) && decoded_uses_memory && !instruction_has_error;

  always_comb begin
    lsu_lane_addr = '0;
    lsu_lane_wdata = '0;
    lsu_writeback_value = '0;

    for (int lane = 0; lane < LANES_PORT_W; lane++) begin
      lsu_lane_addr[(lane*ADDR_PORT_W)+:ADDR_PORT_W] =
          rf_read_data_a[(lane*DATA_PORT_W)+:ADDR_PORT_W] + ADDR_PORT_W'(decoded_imm18);
      lsu_lane_wdata[(lane*32)+:32] =
          rf_read_data_b[(lane*DATA_PORT_W)+:32];
      lsu_writeback_value[(lane*DATA_PORT_W)+:32] =
          lsu_lane_rdata[(lane*32)+:32];
    end
  end

  genvar special_lane;
  generate
    for (special_lane = 0; special_lane < LANES_PORT_W; special_lane = special_lane + 1) begin : gen_special_inputs
      assign special_lane_id[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          lane_id[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_global_id_x[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          global_id_x[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_global_id_y[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          global_id_y[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_group_id_x[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          group_id_x[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_group_id_y[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          group_id_y[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_local_id_x[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          local_id_x[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
      assign special_local_id_y[(special_lane*SPECIAL_COORD_W)+:SPECIAL_COORD_W] =
          local_id_y[(special_lane*COORD_PORT_W)+:SPECIAL_COORD_W];
    end
  endgenerate

  assign special_arg_base = arg_base[SPECIAL_ADDR_W-1:0];
  assign special_framebuffer_base = framebuffer_base[SPECIAL_ADDR_W-1:0];
  assign special_framebuffer_width = framebuffer_width[SPECIAL_COORD_W-1:0];
  assign special_framebuffer_height = framebuffer_height[SPECIAL_COORD_W-1:0];

  always_comb begin
    rf_write_data = '0;

    if (state == STATE_WAIT_LSU) begin
      rf_write_data = lsu_writeback_value;
    end else if (decoded_uses_immediate) begin
      rf_write_data = immediate_value;
    end else if (decoded_uses_special) begin
      rf_write_data = special_value;
    end else if (decoded_uses_alu) begin
      rf_write_data = alu_result;
        end
    end

    always_comb begin
        branch_lane_taken = '0;

        for (int lane = 0; lane < LANES_PORT_W; lane++) begin
            branch_lane_taken[lane] =
                rf_read_data_a[(lane*DATA_PORT_W)+:DATA_PORT_W] != '0;
        end
    end

    assign branch_any_taken = |(branch_lane_taken & active_mask);
    assign branch_any_not_taken = |((~branch_lane_taken) & active_mask);
    assign branch_divergent = branch_any_taken && branch_any_not_taken;
    assign branch_taken = branch_any_taken && !branch_any_not_taken;

    instruction_decoder u_instruction_decoder (
        .instruction(instruction),
      .opcode(decoded_opcode),
      .rd(decoded_rd),
      .ra(decoded_ra),
        .rb(decoded_rb),
        .imm18(decoded_imm18),
        .branch_offset(decoded_branch_offset),
        .special_reg_id(decoded_special_reg_id),
        .alu_op(decoded_alu_op),
      .writes_register(decoded_writes_register),
      .uses_immediate(decoded_uses_immediate),
      .uses_special(decoded_uses_special),
        .uses_alu(decoded_uses_alu),
        .uses_memory(decoded_uses_memory),
        .uses_branch(decoded_uses_branch),
        .memory_write(decoded_memory_write),
      .memory_store16(decoded_memory_store16),
      .ends_lane(decoded_ends_lane),
      .illegal(decoder_illegal)
  );

  lane_register_file #(
      .LANES(LANES_PORT_W),
      .REGS(REGS),
      .DATA_W(DATA_PORT_W),
      .REG_ADDR_W(REG_ADDR_PORT_W)
  ) u_lane_register_file (
      .clk(clk),
      .reset(reset),
      .read_addr_a(rf_read_addr_a),
      .read_data_a(rf_read_data_a),
      .read_addr_b(rf_read_addr_b),
      .read_data_b(rf_read_data_b),
      .write_enable(rf_write_enable),
      .write_addr(rf_write_addr),
      .write_data(rf_write_data)
  );

  simd_alu #(
      .LANES(LANES_PORT_W),
      .DATA_W(DATA_PORT_W),
      .OP_W(4)
  ) u_simd_alu (
      .op(decoded_alu_op),
      .operand_a(rf_read_data_a),
      .operand_b(rf_read_data_b),
      .result(alu_result),
      .zero(alu_zero)
  );

  special_registers #(
      .LANES(LANES_PORT_W),
      .DATA_W(DATA_PORT_W),
      .COORD_W(SPECIAL_COORD_W),
      .ADDR_W(SPECIAL_ADDR_W)
  ) u_special_registers (
      .special_reg_id(decoded_special_reg_id),
      .lane_id(special_lane_id),
      .global_id_x(special_global_id_x),
      .global_id_y(special_global_id_y),
      .linear_global_id(linear_global_id),
      .group_id_x(special_group_id_x),
      .group_id_y(special_group_id_y),
      .local_id_x(special_local_id_x),
      .local_id_y(special_local_id_y),
      .arg_base(special_arg_base),
      .framebuffer_base(special_framebuffer_base),
      .framebuffer_width(special_framebuffer_width),
      .framebuffer_height(special_framebuffer_height),
      .value(special_value),
      .illegal(special_illegal)
  );

  load_store_unit #(
      .LANES(LANES_PORT_W),
      .ADDR_W(ADDR_PORT_W)
  ) u_load_store_unit (
      .clk(clk),
      .reset(reset),
      .start_valid(lsu_start_valid),
      .start_ready(lsu_start_ready),
      .op(lsu_op),
      .active_mask(active_mask),
      .lane_addr(lsu_lane_addr),
      .lane_wdata(lsu_lane_wdata),
      .busy(),
      .done(lsu_done),
      .error(lsu_error),
      .lane_rdata(lsu_lane_rdata),
      .lane_rvalid(lsu_lane_rvalid),
      .req_valid(data_req_valid),
      .req_ready(data_req_ready),
      .req_write(data_req_write),
      .req_addr(data_req_addr),
      .req_wdata(data_req_wdata),
      .req_wmask(data_req_wmask),
      .rsp_valid(data_rsp_valid),
      .rsp_ready(data_rsp_ready),
      .rsp_rdata(data_rsp_rdata)
  );

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
      pc <= '0;
      active_mask <= '0;
      launch_armed <= 1'b1;
      lsu_writes_register_q <= 1'b0;
      lsu_write_addr_q <= '0;
    end else begin
      if (!start) begin
        launch_armed <= 1'b1;
      end

      case (state)
        STATE_IDLE: begin
          if (launch_accept) begin
            state <= STATE_RUN;
            pc <= '0;
            active_mask <= launch_active_mask;
            launch_armed <= 1'b0;
          end
        end

        STATE_RUN: begin
          if (instruction_has_error) begin
            state <= STATE_ERROR;
            active_mask <= '0;
                    end else if (decoded_uses_memory) begin
                        if (lsu_start_ready) begin
                            lsu_writes_register_q <= decoded_writes_register;
                            lsu_write_addr_q <= fit_reg_addr(decoded_rd);
                            state <= STATE_WAIT_LSU;
                        end
                    end else if (decoded_uses_branch) begin
                        if (branch_divergent) begin
                            state <= STATE_ERROR;
                            active_mask <= '0;
                        end else if (branch_taken) begin
                            pc <= branch_target(pc, decoded_branch_offset);
                        end else begin
                            pc <= pc + PC_PORT_W'(1);
                        end
                    end else if (decoded_ends_lane) begin
                        state <= STATE_DONE;
                        active_mask <= '0;
          end else begin
            pc <= pc + PC_PORT_W'(1);
          end
        end

        STATE_WAIT_LSU: begin
          if (lsu_error) begin
            state <= STATE_ERROR;
            active_mask <= '0;
            lsu_writes_register_q <= 1'b0;
          end else if (lsu_done) begin
            pc <= pc + PC_PORT_W'(1);
            lsu_writes_register_q <= 1'b0;
            state <= STATE_RUN;
          end
        end

        STATE_DONE: begin
          state <= STATE_IDLE;
        end

        STATE_ERROR: begin
          state <= STATE_IDLE;
        end

        default: begin
          state <= STATE_ERROR;
        end
      endcase
    end
  end
endmodule
