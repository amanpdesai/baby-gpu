module load_store_unit #(
    parameter int LANES = 4,
    parameter int ADDR_W = 32
) (
    input logic clk,
    input logic reset,

    input logic start_valid,
    output logic start_ready,
    input logic [1:0] op,
    input logic [LANES-1:0] active_mask,
    input logic [(LANES*ADDR_W)-1:0] lane_addr,
    input logic [(LANES*32)-1:0] lane_wdata,

    output logic busy,
    output logic done,
    output logic error,
    output logic [(LANES*32)-1:0] lane_rdata,
    output logic [LANES-1:0] lane_rvalid,

    output logic req_valid,
    input logic req_ready,
    output logic req_write,
    output logic [ADDR_W-1:0] req_addr,
    output logic [31:0] req_wdata,
    output logic [3:0] req_wmask,

    input logic rsp_valid,
    output logic rsp_ready,
    input logic [31:0] rsp_rdata
);
    localparam logic [1:0] LSU_OP_LOAD = 2'd0;
    localparam logic [1:0] LSU_OP_STORE = 2'd1;
    localparam logic [1:0] LSU_OP_STORE16 = 2'd2;
    localparam int DATA_W = 32;
    localparam int STRB_W = DATA_W / 8;
    localparam int LANE_SEL_W = (LANES <= 1) ? 1 : $clog2(LANES);
    localparam int LANE_IDX_W = (LANES <= 1) ? 1 : $clog2(LANES + 1);

    initial begin
        if (ADDR_W < 2) begin
            $fatal(1, "load_store_unit requires ADDR_W >= 2");
        end
        if (LANES < 1) begin
            $fatal(1, "load_store_unit requires LANES >= 1");
        end
    end

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_PREP,
        STATE_REQ,
        STATE_WAIT_RSP
    } state_t;

    state_t state_q;
    logic [1:0] op_q;
    logic [LANES-1:0] active_mask_q;
    logic [(LANES*ADDR_W)-1:0] lane_addr_q;
    logic [(LANES*DATA_W)-1:0] lane_wdata_q;
    logic [LANE_IDX_W-1:0] lane_idx_q;
    logic req_valid_q;
    logic req_write_q;
    logic [ADDR_W-1:0] req_addr_q;
    logic [DATA_W-1:0] req_wdata_q;
    logic [STRB_W-1:0] req_wmask_q;
    logic [ADDR_W-1:0] lane_addr_arr [LANES];
    logic [DATA_W-1:0] lane_wdata_arr [LANES];
    logic [DATA_W-1:0] lane_rdata_arr [LANES];
    logic [LANES-1:0] lane_rvalid_q;
    logic done_q;
    logic error_q;

    logic [LANES-1:0] candidate_mask;
    logic found_lane;
    logic [LANE_SEL_W-1:0] next_lane;
    logic [LANE_IDX_W-1:0] next_lane_cursor;
    logic [ADDR_W-1:0] curr_addr;
    logic [DATA_W-1:0] curr_wdata;
    logic align_error;
    logic op_error;
    logic [ADDR_W-1:0] prepared_addr;
    logic [DATA_W-1:0] prepared_wdata;
    logic [STRB_W-1:0] prepared_wmask;

    genvar gen_lane;
    generate
        for (gen_lane = 0; gen_lane < LANES; gen_lane++) begin : gen_lane_unpack
            assign lane_addr_arr[gen_lane] = lane_addr_q[gen_lane*ADDR_W +: ADDR_W];
            assign lane_wdata_arr[gen_lane] = lane_wdata_q[gen_lane*DATA_W +: DATA_W];
            assign lane_rdata[gen_lane*DATA_W +: DATA_W] = lane_rdata_arr[gen_lane];
        end
    endgenerate

    function automatic logic [LANE_SEL_W-1:0] first_active_lane(
        input logic [LANES-1:0] mask
    );
        begin
            first_active_lane = '0;
            for (int lane = LANES - 1; lane >= 0; lane--) begin
                if (mask[lane]) begin
                    first_active_lane = lane[LANE_SEL_W-1:0];
                end
            end
        end
    endfunction

    genvar scan_lane;
    generate
        for (scan_lane = 0; scan_lane < LANES; scan_lane++) begin : gen_lane_scan
            assign candidate_mask[scan_lane] = active_mask_q[scan_lane] && (scan_lane >= lane_idx_q);
        end
    endgenerate

    assign found_lane = |candidate_mask;
    assign next_lane = first_active_lane(candidate_mask);
    assign next_lane_cursor = {{(LANE_IDX_W-LANE_SEL_W){1'b0}}, next_lane};

    always_comb begin
        curr_addr = '0;
        curr_wdata = '0;
        if (found_lane) begin
            curr_addr = lane_addr_arr[next_lane];
            curr_wdata = lane_wdata_arr[next_lane];
        end
        align_error = 1'b0;
        op_error = 1'b0;
        prepared_addr = curr_addr;
        prepared_wdata = '0;
        prepared_wmask = '0;

        case (op_q)
            LSU_OP_LOAD: begin
                align_error = ((curr_addr & 32'd3) != '0);
                prepared_wmask = '0;
            end
            LSU_OP_STORE: begin
                align_error = ((curr_addr & 32'd3) != '0);
                prepared_wdata = curr_wdata;
                prepared_wmask = '1;
            end
            LSU_OP_STORE16: begin
                align_error = ((curr_addr & 32'd1) != '0);
                prepared_addr = (curr_addr >> 2) << 2;
                if ((curr_addr & 32'd2) != '0) begin
                    prepared_wdata = (curr_wdata & 32'h0000_FFFF) << 16;
                    prepared_wmask = 4'b1100;
                end else begin
                    prepared_wdata = curr_wdata & 32'h0000_FFFF;
                    prepared_wmask = 4'b0011;
                end
            end
            default: begin
                op_error = 1'b1;
            end
        endcase
    end

    assign start_ready = (state_q == STATE_IDLE);
    assign busy = (state_q != STATE_IDLE);
    assign done = done_q;
    assign error = error_q;
    assign lane_rvalid = lane_rvalid_q;
    assign req_valid = req_valid_q;
    assign req_write = req_write_q;
    assign req_addr = req_addr_q;
    assign req_wdata = req_wdata_q;
    assign req_wmask = req_wmask_q;
    assign rsp_ready = (state_q == STATE_WAIT_RSP);

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            op_q <= LSU_OP_LOAD;
            active_mask_q <= '0;
            lane_addr_q <= '0;
            lane_wdata_q <= '0;
            lane_idx_q <= '0;
            req_valid_q <= 1'b0;
            req_write_q <= 1'b0;
            req_addr_q <= '0;
            req_wdata_q <= '0;
            req_wmask_q <= '0;
            lane_rvalid_q <= '0;
            done_q <= 1'b0;
            error_q <= 1'b0;
            for (int lane = 0; lane < LANES; lane++) begin
                lane_rdata_arr[lane] <= '0;
            end
        end else begin
            done_q <= 1'b0;

            case (state_q)
                STATE_IDLE: begin
                    req_valid_q <= 1'b0;
                    if (start_valid) begin
                        op_q <= op;
                        active_mask_q <= active_mask;
                        lane_addr_q <= lane_addr;
                        lane_wdata_q <= lane_wdata;
                        lane_idx_q <= '0;
                        lane_rvalid_q <= '0;
                        error_q <= 1'b0;
                        state_q <= STATE_PREP;
                    end
                end
                STATE_PREP: begin
                    if (!found_lane) begin
                        done_q <= 1'b1;
                        state_q <= STATE_IDLE;
                    end else if (align_error || op_error) begin
                        error_q <= 1'b1;
                        state_q <= STATE_IDLE;
                    end else begin
                        req_valid_q <= 1'b1;
                        req_write_q <= (op_q != LSU_OP_LOAD);
                        req_addr_q <= prepared_addr;
                        req_wdata_q <= prepared_wdata;
                        req_wmask_q <= prepared_wmask;
                        state_q <= STATE_REQ;
                    end
                end
                STATE_REQ: begin
                    if (req_ready) begin
                        req_valid_q <= 1'b0;
                        state_q <= STATE_WAIT_RSP;
                    end
                end
                STATE_WAIT_RSP: begin
                    if (rsp_valid) begin
                        if (op_q == LSU_OP_LOAD) begin
                            lane_rdata_arr[next_lane] <= rsp_rdata;
                            lane_rvalid_q[next_lane] <= 1'b1;
                        end
                        lane_idx_q <= next_lane_cursor + {{(LANE_IDX_W-1){1'b0}}, 1'b1};
                        state_q <= STATE_PREP;
                    end
                end
                default: begin
                    state_q <= STATE_IDLE;
                    req_valid_q <= 1'b0;
                    error_q <= 1'b1;
                end
            endcase
        end
    end
endmodule
