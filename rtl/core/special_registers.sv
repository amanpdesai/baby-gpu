module special_registers #(
    parameter int LANES = 4,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int ADDR_W = 32
) (
    input logic [isa_pkg::ISA_SPECIAL_W-1:0] special_reg_id,

    input logic [(LANES*COORD_W)-1:0] lane_id,
    input logic [(LANES*COORD_W)-1:0] global_id_x,
    input logic [(LANES*COORD_W)-1:0] global_id_y,
    input logic [(LANES*DATA_W)-1:0] linear_global_id,
    input logic [(LANES*COORD_W)-1:0] group_id_x,
    input logic [(LANES*COORD_W)-1:0] group_id_y,
    input logic [(LANES*COORD_W)-1:0] local_id_x,
    input logic [(LANES*COORD_W)-1:0] local_id_y,

    input logic [ADDR_W-1:0] arg_base,
    input logic [ADDR_W-1:0] framebuffer_base,
    input logic [COORD_W-1:0] framebuffer_width,
    input logic [COORD_W-1:0] framebuffer_height,

    output logic [(LANES*DATA_W)-1:0] value,
    output logic illegal
);
  import isa_pkg::*;

  function automatic logic [DATA_W-1:0] fit_coord(input logic [COORD_W-1:0] coord);
    begin
      fit_coord = {{(DATA_W - COORD_W) {1'b0}}, coord};
    end
  endfunction

  function automatic logic [DATA_W-1:0] fit_addr(input logic [ADDR_W-1:0] addr);
    begin
      fit_addr = {{(DATA_W - ADDR_W) {1'b0}}, addr};
    end
  endfunction

  always_comb begin
    illegal = 1'b0;
    value = '0;

    for (int lane = 0; lane < LANES; lane = lane + 1) begin
      case (special_reg_id)
        ISA_SR_LANE_ID:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(lane_id[(lane*COORD_W)+:COORD_W]);
        ISA_SR_GLOBAL_ID_X:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(global_id_x[(lane*COORD_W)+:COORD_W]);
        ISA_SR_GLOBAL_ID_Y:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(global_id_y[(lane*COORD_W)+:COORD_W]);
        ISA_SR_LINEAR_GLOBAL_ID:
          value[(lane*DATA_W)+:DATA_W] = linear_global_id[(lane*DATA_W)+:DATA_W];
        ISA_SR_GROUP_ID_X:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(group_id_x[(lane*COORD_W)+:COORD_W]);
        ISA_SR_GROUP_ID_Y:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(group_id_y[(lane*COORD_W)+:COORD_W]);
        ISA_SR_LOCAL_ID_X:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(local_id_x[(lane*COORD_W)+:COORD_W]);
        ISA_SR_LOCAL_ID_Y:
          value[(lane*DATA_W)+:DATA_W] = fit_coord(local_id_y[(lane*COORD_W)+:COORD_W]);
        ISA_SR_ARG_BASE: value[(lane*DATA_W)+:DATA_W] = fit_addr(arg_base);
        ISA_SR_FRAMEBUFFER_BASE: value[(lane*DATA_W)+:DATA_W] = fit_addr(framebuffer_base);
        ISA_SR_FRAMEBUFFER_WIDTH: value[(lane*DATA_W)+:DATA_W] = fit_coord(framebuffer_width);
        ISA_SR_FRAMEBUFFER_HEIGHT: value[(lane*DATA_W)+:DATA_W] = fit_coord(framebuffer_height);
        default: begin
          illegal = 1'b1;
          value[(lane*DATA_W)+:DATA_W] = '0;
        end
      endcase
    end
  end
endmodule
