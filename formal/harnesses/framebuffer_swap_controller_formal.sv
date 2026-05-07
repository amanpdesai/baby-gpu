module framebuffer_swap_controller_formal(input logic clk);
    localparam int ADDR_W = 8;
    localparam logic [ADDR_W-1:0] FRONT0 = 8'h20;
    localparam logic [ADDR_W-1:0] BACK0 = 8'h40;

    (* anyseq *) logic rst_n;
    (* anyseq *) logic swap_request;
    logic swap_ready;
    (* anyseq *) logic frame_boundary;
    logic [ADDR_W-1:0] front_base;
    logic [ADDR_W-1:0] back_base;
    logic swap_pending;
    logic swap_pulse;
    logic past_valid;

    framebuffer_swap_controller #(
        .ADDR_W(ADDR_W),
        .FRONT_BASE_RESET(FRONT0),
        .BACK_BASE_RESET(BACK0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .swap_request(swap_request),
        .swap_ready(swap_ready),
        .frame_boundary(frame_boundary),
        .front_base(front_base),
        .back_base(back_base),
        .swap_pending(swap_pending),
        .swap_pulse(swap_pulse)
    );

    wire accept_swap = swap_request && swap_ready;
    wire commit_swap = frame_boundary && (swap_pending || accept_swap);

    initial begin
        past_valid = 1'b0;
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;

        if (!past_valid) begin
            assume(!rst_n);
        end else begin
            assume(rst_n);
        end

        assert(swap_ready == !swap_pending);

        if (!rst_n) begin
            assert(front_base == FRONT0);
            assert(back_base == BACK0);
            assert(!swap_pending);
            assert(!swap_pulse);
        end

        if (past_valid && $past(rst_n) && rst_n) begin
            assert(swap_pulse ==
                   $past(frame_boundary && (swap_pending || (swap_request && swap_ready))));
            if ($past(frame_boundary && (swap_pending || (swap_request && swap_ready)))) begin
                assert(front_base == $past(back_base));
                assert(back_base == $past(front_base));
                assert(!swap_pending);
            end else if ($past(swap_request && swap_ready)) begin
                assert(swap_pending);
                assert(front_base == $past(front_base));
                assert(back_base == $past(back_base));
            end
        end

        cover(past_valid && rst_n && swap_request && !frame_boundary && swap_pending);
        cover(past_valid && rst_n && swap_pulse && front_base == BACK0 && back_base == FRONT0);
        cover(past_valid && rst_n && swap_request && frame_boundary && swap_pulse);
    end
endmodule
