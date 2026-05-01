module special_registers_formal (
    input logic clk
);
    localparam int LANES = 2;
    localparam int DATA_W = 8;
    localparam int COORD_W = 4;
    localparam int ADDR_W = 6;

    (* anyseq *) logic [isa_pkg::ISA_SPECIAL_W-1:0] special_reg_id;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] lane_id;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] global_id_x;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] global_id_y;
    (* anyseq *) logic [(LANES*DATA_W)-1:0] linear_global_id;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] group_id_x;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] group_id_y;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] local_id_x;
    (* anyseq *) logic [(LANES*COORD_W)-1:0] local_id_y;
    (* anyseq *) logic [ADDR_W-1:0] arg_base;
    (* anyseq *) logic [ADDR_W-1:0] framebuffer_base;
    (* anyseq *) logic [COORD_W-1:0] framebuffer_width;
    (* anyseq *) logic [COORD_W-1:0] framebuffer_height;

    logic [(LANES*DATA_W)-1:0] value;
    logic illegal;

    special_registers #(
        .LANES(LANES),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W)
    ) dut (
        .special_reg_id(special_reg_id),
        .lane_id(lane_id),
        .global_id_x(global_id_x),
        .global_id_y(global_id_y),
        .linear_global_id(linear_global_id),
        .group_id_x(group_id_x),
        .group_id_y(group_id_y),
        .local_id_x(local_id_x),
        .local_id_y(local_id_y),
        .arg_base(arg_base),
        .framebuffer_base(framebuffer_base),
        .framebuffer_width(framebuffer_width),
        .framebuffer_height(framebuffer_height),
        .value(value),
        .illegal(illegal)
    );

    function automatic logic [DATA_W-1:0] fit_coord(input logic [COORD_W-1:0] coord);
        fit_coord = {{(DATA_W-COORD_W){1'b0}}, coord};
    endfunction

    function automatic logic [DATA_W-1:0] fit_addr(input logic [ADDR_W-1:0] addr);
        fit_addr = {{(DATA_W-ADDR_W){1'b0}}, addr};
    endfunction

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : lane_checks
            logic [DATA_W-1:0] lane_value;

            assign lane_value = value[(lane*DATA_W)+:DATA_W];

            always_comb begin
                unique case (special_reg_id)
                    isa_pkg::ISA_SR_LANE_ID: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(lane_id[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_GLOBAL_ID_X: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(global_id_x[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_GLOBAL_ID_Y: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(global_id_y[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_LINEAR_GLOBAL_ID: begin
                        assert(!illegal);
                        assert(lane_value == linear_global_id[(lane*DATA_W)+:DATA_W]);
                    end
                    isa_pkg::ISA_SR_GROUP_ID_X: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(group_id_x[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_GROUP_ID_Y: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(group_id_y[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_LOCAL_ID_X: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(local_id_x[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_LOCAL_ID_Y: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(local_id_y[(lane*COORD_W)+:COORD_W]));
                    end
                    isa_pkg::ISA_SR_ARG_BASE: begin
                        assert(!illegal);
                        assert(lane_value == fit_addr(arg_base));
                    end
                    isa_pkg::ISA_SR_FRAMEBUFFER_BASE: begin
                        assert(!illegal);
                        assert(lane_value == fit_addr(framebuffer_base));
                    end
                    isa_pkg::ISA_SR_FRAMEBUFFER_WIDTH: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(framebuffer_width));
                    end
                    isa_pkg::ISA_SR_FRAMEBUFFER_HEIGHT: begin
                        assert(!illegal);
                        assert(lane_value == fit_coord(framebuffer_height));
                    end
                    default: begin
                        assert(illegal);
                        assert(lane_value == '0);
                    end
                endcase
            end
        end
    endgenerate
endmodule
