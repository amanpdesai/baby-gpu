module load_store_unit_sequence_checker #(
    parameter int LANES = 3,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int LANE_IDX_W = 2
) (
    input logic clk,
    input logic reset,
    input logic [1:0] state_q,
    input logic [1:0] op_q,
    input logic [LANES-1:0] active_mask_q,
    input logic [LANE_IDX_W-1:0] lane_idx_q,
    input logic req_valid_q,
    input logic req_write_q,
    input logic [ADDR_W-1:0] req_addr_q,
    input logic [DATA_W-1:0] req_wdata_q,
    input logic [(DATA_W/8)-1:0] req_wmask_q,
    input logic [(LANES*DATA_W)-1:0] lane_rdata,
    input logic [LANES-1:0] lane_rvalid_q,
    input logic done_q,
    input logic error_q,
    input logic req_ready,
    input logic rsp_valid,
    input logic [DATA_W-1:0] rsp_rdata
);
    localparam logic [1:0] LSU_OP_LOAD = 2'd0;
    localparam logic [1:0] LSU_OP_STORE = 2'd1;

    localparam logic [1:0] STATE_IDLE = 2'd0;
    localparam logic [1:0] STATE_PREP = 2'd1;
    localparam logic [1:0] STATE_REQ = 2'd2;
    localparam logic [1:0] STATE_WAIT_RSP = 2'd3;

    localparam logic [3:0] SCENARIO_RESET = 4'd0;
    localparam logic [3:0] SCENARIO_REQ_STALL = 4'd1;
    localparam logic [3:0] SCENARIO_REQ_ACCEPT = 4'd2;
    localparam logic [3:0] SCENARIO_LOAD_RSP = 4'd3;
    localparam logic [3:0] SCENARIO_STORE_RSP = 4'd4;
    localparam logic [3:0] SCENARIO_EMPTY_MASK = 4'd5;
    localparam logic [3:0] SCENARIO_MULTI_LANE_RSP = 4'd6;

    (* anyconst *) logic [3:0] scenario;
    logic checked_q;

    initial begin
        checked_q = 1'b0;
    end

    always_comb begin
        assume(scenario <= SCENARIO_MULTI_LANE_RSP);

        if (!checked_q) begin
            case (scenario)
                SCENARIO_RESET: begin
                    assume(reset);
                end

                SCENARIO_REQ_STALL: begin
                    assume(!reset);
                    assume(state_q == STATE_REQ);
                    assume(req_valid_q);
                    assume(req_write_q);
                    assume(req_addr_q == 32'h0000_0040);
                    assume(req_wdata_q == 32'h1234_5678);
                    assume(req_wmask_q == 4'b1111);
                    assume(!req_ready);
                    assume(!rsp_valid);
                end

                SCENARIO_REQ_ACCEPT: begin
                    assume(!reset);
                    assume(state_q == STATE_REQ);
                    assume(req_valid_q);
                    assume(req_ready);
                    assume(!rsp_valid);
                end

                SCENARIO_LOAD_RSP: begin
                    assume(!reset);
                    assume(state_q == STATE_WAIT_RSP);
                    assume(op_q == LSU_OP_LOAD);
                    assume(active_mask_q == {{(LANES-1){1'b0}}, 1'b1});
                    assume(lane_idx_q == '0);
                    assume(lane_rvalid_q == '0);
                    assume(rsp_valid);
                    assume(rsp_rdata == 32'hCAFE_1234);
                end

                SCENARIO_STORE_RSP: begin
                    assume(!reset);
                    assume(state_q == STATE_WAIT_RSP);
                    assume(op_q == LSU_OP_STORE);
                    assume(active_mask_q == {{(LANES-1){1'b0}}, 1'b1});
                    assume(lane_idx_q == '0);
                    assume(lane_rvalid_q == '0);
                    assume(rsp_valid);
                end

                SCENARIO_EMPTY_MASK: begin
                    assume(!reset);
                    assume(state_q == STATE_PREP);
                    assume(active_mask_q == '0);
                    assume(lane_idx_q == '0);
                    assume(!req_valid_q);
                    assume(!error_q);
                end

                SCENARIO_MULTI_LANE_RSP: begin
                    assume(!reset);
                    assume(state_q == STATE_WAIT_RSP);
                    assume(op_q == LSU_OP_LOAD);
                    assume(active_mask_q == 3'b101);
                    assume(lane_idx_q == 2'd1);
                    assume(lane_rvalid_q == 3'b001);
                    assume(lane_rdata[0 +: DATA_W] == 32'h1111_2222);
                    assume(lane_rdata[DATA_W +: DATA_W] == 32'h0000_0000);
                    assume(lane_rdata[(2*DATA_W) +: DATA_W] == 32'h0000_0000);
                    assume(rsp_valid);
                    assume(rsp_rdata == 32'hDEAD_BEEF);
                end

                default: begin
                    assume(1'b0);
                end
            endcase
        end

        if (checked_q) begin
            case (scenario)
                SCENARIO_RESET: begin
                    assert(state_q == STATE_IDLE);
                    assert(!req_valid_q);
                    assert(!req_write_q);
                    assert(req_addr_q == '0);
                    assert(req_wdata_q == '0);
                    assert(req_wmask_q == '0);
                    assert(lane_rvalid_q == '0);
                    assert(!done_q);
                    assert(!error_q);
                end

                SCENARIO_REQ_STALL: begin
                    assert(state_q == STATE_REQ);
                    assert(req_valid_q);
                    assert(req_write_q);
                    assert(req_addr_q == 32'h0000_0040);
                    assert(req_wdata_q == 32'h1234_5678);
                    assert(req_wmask_q == 4'b1111);
                end

                SCENARIO_REQ_ACCEPT: begin
                    assert(state_q == STATE_WAIT_RSP);
                    assert(!req_valid_q);
                end

                SCENARIO_LOAD_RSP: begin
                    assert(state_q == STATE_PREP);
                    assert(lane_idx_q == {{(LANE_IDX_W-1){1'b0}}, 1'b1});
                    assert(lane_rvalid_q[0]);
                    assert(lane_rdata[0 +: DATA_W] == 32'hCAFE_1234);
                end

                SCENARIO_STORE_RSP: begin
                    assert(state_q == STATE_PREP);
                    assert(lane_idx_q == {{(LANE_IDX_W-1){1'b0}}, 1'b1});
                    assert(lane_rvalid_q == '0);
                end

                SCENARIO_EMPTY_MASK: begin
                    assert(state_q == STATE_IDLE);
                    assert(done_q);
                    assert(!error_q);
                    assert(!req_valid_q);
                end

                SCENARIO_MULTI_LANE_RSP: begin
                    assert(state_q == STATE_PREP);
                    assert(lane_idx_q == 2'd3);
                    assert(lane_rvalid_q == 3'b101);
                    assert(lane_rdata[0 +: DATA_W] == 32'h1111_2222);
                    assert(lane_rdata[DATA_W +: DATA_W] == 32'h0000_0000);
                    assert(lane_rdata[(2*DATA_W) +: DATA_W] == 32'hDEAD_BEEF);
                end

                default: begin
                    assert(1'b0);
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        checked_q <= 1'b1;

        if (checked_q) begin
            cover(scenario == SCENARIO_LOAD_RSP && lane_rvalid_q[0]);
            cover(scenario == SCENARIO_EMPTY_MASK && done_q);
            cover(scenario == SCENARIO_MULTI_LANE_RSP && lane_rvalid_q[2]);
        end
    end
endmodule

bind load_store_unit load_store_unit_sequence_checker #(
    .LANES(LANES),
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .LANE_IDX_W(LANE_IDX_W)
) sequence_checker (
    .clk(clk),
    .reset(reset),
    .state_q(state_q),
    .op_q(op_q),
    .active_mask_q(active_mask_q),
    .lane_idx_q(lane_idx_q),
    .req_valid_q(req_valid_q),
    .req_write_q(req_write_q),
    .req_addr_q(req_addr_q),
    .req_wdata_q(req_wdata_q),
    .req_wmask_q(req_wmask_q),
    .lane_rdata(lane_rdata),
    .lane_rvalid_q(lane_rvalid_q),
    .done_q(done_q),
    .error_q(error_q),
    .req_ready(req_ready),
    .rsp_valid(rsp_valid),
    .rsp_rdata(rsp_rdata)
);

module load_store_unit_sequence_formal (
    input logic clk
);
    localparam int LANES = 3;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;

    logic reset;
    logic start_valid;
    logic start_ready;
    logic [1:0] op;
    logic [LANES-1:0] active_mask;
    logic [(LANES*ADDR_W)-1:0] lane_addr;
    logic [(LANES*DATA_W)-1:0] lane_wdata;
    logic busy;
    logic done;
    logic error;
    logic [(LANES*DATA_W)-1:0] lane_rdata;
    logic [LANES-1:0] lane_rvalid;
    logic req_valid;
    logic req_ready;
    logic req_write;
    logic [ADDR_W-1:0] req_addr;
    logic [DATA_W-1:0] req_wdata;
    logic [3:0] req_wmask;
    logic rsp_valid;
    logic rsp_ready;
    logic [DATA_W-1:0] rsp_rdata;

    load_store_unit #(
        .LANES(LANES),
        .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start_valid(start_valid),
        .start_ready(start_ready),
        .op(op),
        .active_mask(active_mask),
        .lane_addr(lane_addr),
        .lane_wdata(lane_wdata),
        .busy(busy),
        .done(done),
        .error(error),
        .lane_rdata(lane_rdata),
        .lane_rvalid(lane_rvalid),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wmask(req_wmask),
        .rsp_valid(rsp_valid),
        .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata)
    );
endmodule
