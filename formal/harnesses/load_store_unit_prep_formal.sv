module load_store_unit_prep_checker #(
    parameter int LANES = 1,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int LANE_IDX_W = 1
) (
    input logic [1:0] state_q,
    input logic [1:0] op_q,
    input logic [LANES-1:0] active_mask_q,
    input logic [(LANES*ADDR_W)-1:0] lane_addr_q,
    input logic [(LANES*DATA_W)-1:0] lane_wdata_q,
    input logic [LANE_IDX_W-1:0] lane_idx_q,
    input logic done_q,
    input logic error_q,
    input logic req_valid_q,
    input logic req_write_q,
    input logic [ADDR_W-1:0] req_addr_q,
    input logic [DATA_W-1:0] req_wdata_q,
    input logic [(DATA_W/8)-1:0] req_wmask_q,
    input logic [LANES-1:0] lane_rvalid_q,
    input logic found_lane,
    input logic align_error,
    input logic op_error,
    input logic [ADDR_W-1:0] prepared_addr,
    input logic [DATA_W-1:0] prepared_wdata,
    input logic [(DATA_W/8)-1:0] prepared_wmask
);
    localparam logic [1:0] OP_STORE = 2'd1;
    localparam logic [1:0] OP_STORE16 = 2'd2;
    localparam logic [1:0] STATE_PREP = 2'd1;

    (* anyconst *) logic [2:0] scenario;

    always_comb begin
        assume(scenario <= 3'd5);
        assume(state_q == STATE_PREP);
        assume(lane_idx_q == '0);
        assume(done_q == 1'b0);
        assume(error_q == 1'b0);
        assume(req_valid_q == 1'b0);
        assume(req_write_q == 1'b0);
        assume(req_addr_q == '0);
        assume(req_wdata_q == '0);
        assume(req_wmask_q == '0);
        assume(lane_rvalid_q == '0);

        unique case (scenario)
            3'd0: begin
                assume(op_q == OP_STORE);
                assume(active_mask_q == 1'b1);
                assume(lane_addr_q == 32'h0000_0040);
                assume(lane_wdata_q == 32'h1234_5678);
            end
            3'd1: begin
                assume(op_q == OP_STORE16);
                assume(active_mask_q == 1'b1);
                assume(lane_addr_q == 32'h0000_0100);
                assume(lane_wdata_q == 32'h0000_55AA);
            end
            3'd2: begin
                assume(op_q == OP_STORE16);
                assume(active_mask_q == 1'b1);
                assume(lane_addr_q == 32'h0000_0102);
                assume(lane_wdata_q == 32'h0000_A55A);
            end
            3'd3: begin
                assume(op_q == OP_STORE);
                assume(active_mask_q == 1'b1);
                assume(lane_addr_q == 32'h0000_0002);
                assume(lane_wdata_q == 32'hDEAD_BEEF);
            end
            3'd4: begin
                assume(op_q == OP_STORE16);
                assume(active_mask_q == 1'b1);
                assume(lane_addr_q == 32'h0000_0101);
                assume(lane_wdata_q == 32'h0000_9876);
            end
            default: begin
                assume(op_q == OP_STORE);
                assume(active_mask_q == '0);
                assume(lane_addr_q == 32'h0000_0020);
                assume(lane_wdata_q == 32'h1111_2222);
            end
        endcase

        if (scenario == 3'd0) begin
            assert(found_lane);
            assert(!align_error);
            assert(!op_error);
            assert(prepared_addr == 32'h0000_0040);
            assert(prepared_wdata == 32'h1234_5678);
            assert(prepared_wmask == 4'b1111);
        end

        if (scenario == 3'd1) begin
            assert(found_lane);
            assert(!align_error);
            assert(!op_error);
            assert(prepared_addr == 32'h0000_0100);
            assert(prepared_wdata == 32'h0000_55AA);
            assert(prepared_wmask == 4'b0011);
        end

        if (scenario == 3'd2) begin
            assert(found_lane);
            assert(!align_error);
            assert(!op_error);
            assert(prepared_addr == 32'h0000_0100);
            assert(prepared_wdata == 32'hA55A_0000);
            assert(prepared_wmask == 4'b1100);
        end

        if (scenario == 3'd3) begin
            assert(found_lane);
            assert(align_error);
            assert(!op_error);
        end

        if (scenario == 3'd4) begin
            assert(found_lane);
            assert(align_error);
            assert(!op_error);
        end

        if (scenario == 3'd5) begin
            assert(!found_lane);
            assert(!align_error);
            assert(!op_error);
        end
    end
endmodule

bind load_store_unit load_store_unit_prep_checker #(
    .LANES(LANES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .LANE_IDX_W(LANE_IDX_W)
) prep_checker (
    .state_q(state_q),
    .op_q(op_q),
    .active_mask_q(active_mask_q),
    .lane_addr_q(lane_addr_q),
    .lane_wdata_q(lane_wdata_q),
    .lane_idx_q(lane_idx_q),
    .done_q(done_q),
    .error_q(error_q),
    .req_valid_q(req_valid_q),
    .req_write_q(req_write_q),
    .req_addr_q(req_addr_q),
    .req_wdata_q(req_wdata_q),
    .req_wmask_q(req_wmask_q),
    .lane_rvalid_q(lane_rvalid_q),
    .found_lane(found_lane),
    .align_error(align_error),
    .op_error(op_error),
    .prepared_addr(prepared_addr),
    .prepared_wdata(prepared_wdata),
    .prepared_wmask(prepared_wmask)
);

module load_store_unit_prep_formal (
    input logic clk
);
    localparam int LANES = 1;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;

    logic start_ready;
    logic busy;
    logic done;
    logic error;
    logic [(LANES*DATA_W)-1:0] lane_rdata;
    logic [LANES-1:0] lane_rvalid;
    logic req_valid;
    logic req_write;
    logic [ADDR_W-1:0] req_addr;
    logic [DATA_W-1:0] req_wdata;
    logic [3:0] req_wmask;
    logic rsp_ready;

    load_store_unit #(
        .LANES(LANES),
        .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk),
        .reset(1'b0),
        .start_valid(1'b0),
        .start_ready(start_ready),
        .op(2'd0),
        .active_mask('0),
        .lane_addr('0),
        .lane_wdata('0),
        .busy(busy),
        .done(done),
        .error(error),
        .lane_rdata(lane_rdata),
        .lane_rvalid(lane_rvalid),
        .req_valid(req_valid),
        .req_ready(1'b0),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wmask(req_wmask),
        .rsp_valid(1'b0),
        .rsp_ready(rsp_ready),
        .rsp_rdata('0)
    );
endmodule
