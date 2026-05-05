module memory_response_tracker #(
    parameter int ID_W = 2,
    parameter int DEPTH = 4,
    localparam int PTR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    localparam int COUNT_W = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic reset,
    input logic clear_errors,

    input logic req_fire,
    input logic [ID_W-1:0] req_id,

    input logic rsp_fire,
    output logic [ID_W-1:0] rsp_id,

    output logic empty,
    output logic full,
    output logic [COUNT_W-1:0] outstanding_count,
    output logic overflow_error,
    output logic underflow_error,
    output logic error
);
    logic [ID_W-1:0] id_fifo [0:DEPTH-1];
    logic [PTR_W-1:0] head_q;
    logic [PTR_W-1:0] tail_q;
    logic [COUNT_W-1:0] count_q;
    logic overflow_error_q;
    logic underflow_error_q;

    function automatic logic [PTR_W-1:0] next_ptr(input logic [PTR_W-1:0] ptr);
        begin
            if (ptr == PTR_W'(DEPTH - 1)) begin
                next_ptr = '0;
            end else begin
                next_ptr = ptr + PTR_W'(1);
            end
        end
    endfunction

    logic push_allowed;
    logic pop_allowed;

    initial begin
        if (ID_W < 1) $fatal(1, "memory_response_tracker requires ID_W >= 1");
        if (DEPTH < 1) $fatal(1, "memory_response_tracker requires DEPTH >= 1");
    end

    assign empty = (count_q == '0);
    assign full = (count_q == COUNT_W'(DEPTH));
    assign outstanding_count = count_q;
    assign rsp_id = empty ? '0 : id_fifo[head_q];
    assign overflow_error = overflow_error_q;
    assign underflow_error = underflow_error_q;
    assign error = overflow_error_q || underflow_error_q;

    assign push_allowed = req_fire && (!full || (rsp_fire && !empty));
    assign pop_allowed = rsp_fire && !empty;

    always_ff @(posedge clk) begin
        if (reset) begin
            head_q <= '0;
            tail_q <= '0;
            count_q <= '0;
            overflow_error_q <= 1'b0;
            underflow_error_q <= 1'b0;
        end else begin
            if (clear_errors) begin
                overflow_error_q <= 1'b0;
                underflow_error_q <= 1'b0;
            end

            if (req_fire && !push_allowed) begin
                overflow_error_q <= 1'b1;
            end

            if (rsp_fire && !pop_allowed) begin
                underflow_error_q <= 1'b1;
            end

            if (push_allowed) begin
                id_fifo[tail_q] <= req_id;
                tail_q <= next_ptr(tail_q);
            end

            if (pop_allowed) begin
                head_q <= next_ptr(head_q);
            end

            case ({push_allowed, pop_allowed})
                2'b10: count_q <= count_q + COUNT_W'(1);
                2'b01: count_q <= count_q - COUNT_W'(1);
                default: count_q <= count_q;
            endcase
        end
    end
endmodule
