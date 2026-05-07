module memory_response_tracker_formal (
    input logic clk
);
    localparam int ID_W = 3;
    localparam int DEPTH = 2;
    localparam int PTR_W = $clog2(DEPTH);
    localparam int COUNT_W = $clog2(DEPTH + 1);

    logic reset;
    (* anyseq *) logic clear_errors;
    (* anyseq *) logic req_fire;
    (* anyseq *) logic [ID_W-1:0] req_id;
    (* anyseq *) logic rsp_fire;
    logic [ID_W-1:0] rsp_id;
    logic empty;
    logic full;
    logic [COUNT_W-1:0] outstanding_count;
    logic overflow_error;
    logic underflow_error;
    logic error;
    logic past_valid;

    logic [ID_W-1:0] model_fifo [0:DEPTH-1];
    logic [PTR_W-1:0] model_head;
    logic [PTR_W-1:0] model_tail;
    logic [COUNT_W-1:0] model_count;
    logic model_push_allowed;
    logic model_pop_allowed;

    memory_response_tracker #(
        .ID_W(ID_W),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .clear_errors(clear_errors),
        .req_fire(req_fire),
        .req_id(req_id),
        .rsp_fire(rsp_fire),
        .rsp_id(rsp_id),
        .empty(empty),
        .full(full),
        .outstanding_count(outstanding_count),
        .overflow_error(overflow_error),
        .underflow_error(underflow_error),
        .error(error)
    );

    assign model_push_allowed = req_fire && ((model_count != COUNT_W'(DEPTH)) ||
                                (rsp_fire && (model_count != '0)));
    assign model_pop_allowed = rsp_fire && (model_count != '0);

    initial begin
        reset = 1'b1;
        past_valid = 1'b0;
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        reset <= 1'b0;

        if (reset) begin
            model_head <= '0;
            model_tail <= '0;
            model_count <= '0;
            for (int model_idx = 0; model_idx < DEPTH; model_idx = model_idx + 1) begin
                model_fifo[model_idx] <= '0;
            end
        end else begin
            if (model_push_allowed) begin
                model_fifo[model_tail] <= req_id;
                model_tail <= model_tail + PTR_W'(1);
            end

            if (model_pop_allowed) begin
                model_head <= model_head + PTR_W'(1);
            end

            case ({model_push_allowed, model_pop_allowed})
                2'b10: model_count <= model_count + COUNT_W'(1);
                2'b01: model_count <= model_count - COUNT_W'(1);
                default: model_count <= model_count;
            endcase
        end
    end

    always_comb begin
        if (!reset) begin
            assert(outstanding_count == model_count);
            assert(outstanding_count <= DEPTH);
            assert(full == (outstanding_count == COUNT_W'(DEPTH)));
            assert(empty == (outstanding_count == '0));
            assert(error == (overflow_error || underflow_error));

            if (model_count != '0) begin
                assert(rsp_id == model_fifo[model_head]);
            end else begin
                assert(rsp_id == '0);
            end

            cover(overflow_error);
            cover(underflow_error);
            cover(outstanding_count == COUNT_W'(DEPTH));
            cover(req_fire && rsp_fire && full);
            cover(req_fire && rsp_fire && (outstanding_count == COUNT_W'(1)));
            cover(req_fire && rsp_fire && (outstanding_count == COUNT_W'(DEPTH)));
        end
    end

    always_ff @(posedge clk) begin
        if (past_valid && !$past(reset) && !$past(empty) && !$past(rsp_fire)) begin
            assert(rsp_id == $past(rsp_id));
        end

        if (past_valid && !$past(reset) && $past(empty) && $past(rsp_fire)) begin
            assert(underflow_error);
        end

        if (past_valid && !$past(reset) && $past(full) && $past(req_fire) &&
            !($past(rsp_fire) && !$past(empty))) begin
            assert(overflow_error);
        end

        if (past_valid && !$past(reset) && $past(req_fire) && $past(empty) &&
            !$past(rsp_fire)) begin
            assert(!empty);
            assert(rsp_id == $past(req_id));
        end

        if (past_valid && !$past(reset) && $past(req_fire) && $past(rsp_fire) &&
            !$past(empty) && !$past(full)) begin
            assert(outstanding_count == $past(outstanding_count));
        end

        cover(past_valid && !$past(reset) && $past(req_fire) && !$past(rsp_fire) &&
              rsp_id == $past(req_id));
        cover(past_valid && !$past(reset) && $past(full) && $past(req_fire) &&
              $past(rsp_fire) && full);
    end
endmodule
