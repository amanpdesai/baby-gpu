module video_pixel_fifo_formal (
    input logic clk
);
    localparam int COORD_W = 3;
    localparam int COLOR_W = 8;
    localparam int DEPTH = 3;
    localparam int COUNT_W = $clog2(DEPTH + 1);

    logic rst_n;
    logic flush;
    logic in_valid;
    logic in_ready;
    logic [COORD_W-1:0] in_x;
    logic [COORD_W-1:0] in_y;
    logic [COLOR_W-1:0] in_color;
    logic out_valid;
    logic out_ready;
    logic [COORD_W-1:0] out_x;
    logic [COORD_W-1:0] out_y;
    logic [COLOR_W-1:0] out_color;
    logic full;
    logic empty;
    logic [COUNT_W-1:0] count;
    logic overflow;
    logic underflow;
    logic past_valid;

    localparam logic [COUNT_W-1:0] DEPTH_COUNT = COUNT_W'(DEPTH);

    video_pixel_fifo #(
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .DEPTH(DEPTH),
        .COUNT_W(COUNT_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_x(in_x),
        .in_y(in_y),
        .in_color(in_color),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_x(out_x),
        .out_y(out_y),
        .out_color(out_color),
        .full(full),
        .empty(empty),
        .count(count),
        .overflow(overflow),
        .underflow(underflow)
    );

    initial begin
        assume(!rst_n);
        past_valid = 1'b0;
    end

    always_comb begin
        if (rst_n) begin
            assert(count <= DEPTH_COUNT);
            assert(empty == (count == '0));
            assert(full == (count == DEPTH_COUNT));
            assert(out_valid == (!flush && !empty));
            assert(in_ready == (!flush && (!full || (out_ready && out_valid))));
            assert(overflow == (!flush && in_valid && !in_ready));
            assert(underflow == (!flush && out_ready && !out_valid));

            if (flush) begin
                assert(!in_ready);
                assert(!out_valid);
                assert(!overflow);
                assert(!underflow);
            end
        end
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;

        if (!past_valid) begin
            assume(!rst_n);
        end

        if (past_valid && (!$past(rst_n) || $past(flush))) begin
            assert(count == '0);
            assert(empty);
            assert(!full);
            assert(!out_valid);
        end

        if (past_valid && rst_n && $past(rst_n) && !$past(flush)) begin
            if ($past(in_valid && in_ready) && !$past(out_valid && out_ready)) begin
                assert(count == $past(count) + COUNT_W'(1));
            end else if (!$past(in_valid && in_ready) && $past(out_valid && out_ready)) begin
                assert(count == $past(count) - COUNT_W'(1));
            end else begin
                assert(count == $past(count));
            end
        end

        if (past_valid && rst_n && $past(rst_n) && !$past(flush) && !flush
            && $past(out_valid) && !$past(out_ready)) begin
            assert(out_valid);
            assert(out_x == $past(out_x));
            assert(out_y == $past(out_y));
            assert(out_color == $past(out_color));
        end

        cover(past_valid && rst_n && full);
        cover(past_valid && rst_n && overflow);
        cover(past_valid && rst_n && underflow);
        cover(past_valid && rst_n && $past(out_valid && !out_ready) && out_valid && out_ready);
        cover(past_valid && rst_n && $past(flush) && empty);
    end
endmodule
