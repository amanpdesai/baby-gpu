module memory_response_tracker_formal (
    input logic clk
);
    localparam int ID_W = 3;
    localparam int DEPTH = 2;
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

    initial begin
        reset = 1'b1;
        past_valid = 1'b0;
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        reset <= 1'b0;
    end

    always @* begin
        if (!reset) begin
            assert(outstanding_count <= DEPTH);
            assert(empty == (outstanding_count == 0));
            assert(full == (outstanding_count == DEPTH));
            assert(error == (overflow_error || underflow_error));
        end

        if (!reset && empty) begin
            assert(rsp_id == '0);
        end
    end

    always_ff @(posedge clk) begin
        if (past_valid && !$past(reset) && !$past(empty) && !$past(rsp_fire)) begin
            assert(rsp_id == $past(rsp_id));
        end

        if (past_valid && !$past(reset) && $past(empty) && $past(rsp_fire)) begin
            assert(underflow_error);
        end

        if (past_valid && !$past(reset) && $past(full) && $past(req_fire) && !($past(rsp_fire) && !$past(empty))) begin
            assert(overflow_error);
        end

        if (past_valid && !$past(reset) && $past(req_fire) && $past(empty) && !$past(rsp_fire)) begin
            assert(!empty);
            assert(rsp_id == $past(req_id));
        end

        if (past_valid && !$past(reset) && $past(req_fire) && $past(rsp_fire) && !$past(empty) && !$past(full)) begin
            assert(outstanding_count == $past(outstanding_count));
        end

        cover(past_valid && !$past(reset) && $past(req_fire) && !$past(rsp_fire) && rsp_id == $past(req_id));
        cover(past_valid && !$past(reset) && $past(full) && $past(req_fire) && $past(rsp_fire) && full);
        cover(overflow_error);
        cover(underflow_error);
    end
endmodule
