module video_timing_formal (
    input logic clk
);
    localparam int H_ACTIVE = 3;
    localparam int H_FRONT = 1;
    localparam int H_SYNC = 2;
    localparam int H_BACK = 1;
    localparam int V_ACTIVE = 2;
    localparam int V_FRONT = 1;
    localparam int V_SYNC = 1;
    localparam int V_BACK = 1;
    localparam bit HSYNC_ACTIVE = 1'b0;
    localparam bit VSYNC_ACTIVE = 1'b1;
    localparam int COORD_W = 3;
    localparam int H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam int V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    logic rst_n;
    logic tick_enable;
    logic pixel_valid;
    logic active;
    logic line_start;
    logic frame_start;
    logic hsync;
    logic vsync;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic [COORD_W-1:0] h_model_q;
    logic [COORD_W-1:0] v_model_q;
    logic past_valid;

    logic h_active_model;
    logic v_active_model;
    logic h_sync_model;
    logic v_sync_model;

    video_timing #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT(H_FRONT),
        .H_SYNC(H_SYNC),
        .H_BACK(H_BACK),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT(V_FRONT),
        .V_SYNC(V_SYNC),
        .V_BACK(V_BACK),
        .HSYNC_ACTIVE(HSYNC_ACTIVE),
        .VSYNC_ACTIVE(VSYNC_ACTIVE),
        .COORD_W(COORD_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .pixel_valid(pixel_valid),
        .active(active),
        .line_start(line_start),
        .frame_start(frame_start),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y)
    );

    initial begin
        assume(!rst_n);
        past_valid = 1'b0;
    end

    always_comb begin
        h_active_model = h_model_q < COORD_W'(H_ACTIVE);
        v_active_model = v_model_q < COORD_W'(V_ACTIVE);
        h_sync_model = (h_model_q >= COORD_W'(H_ACTIVE + H_FRONT))
            && (h_model_q < COORD_W'(H_ACTIVE + H_FRONT + H_SYNC));
        v_sync_model = (v_model_q >= COORD_W'(V_ACTIVE + V_FRONT))
            && (v_model_q < COORD_W'(V_ACTIVE + V_FRONT + V_SYNC));

        if (rst_n) begin
            assert(h_model_q < COORD_W'(H_TOTAL));
            assert(v_model_q < COORD_W'(V_TOTAL));
            assert(active == (h_active_model && v_active_model));
            assert(pixel_valid == (tick_enable && active));
            assert(line_start == (tick_enable && (h_model_q == '0)));
            assert(frame_start == (line_start && (v_model_q == '0)));
            assert(x == (h_active_model ? h_model_q : '0));
            assert(y == (v_active_model ? v_model_q : '0));
            assert(hsync == (h_sync_model ? HSYNC_ACTIVE : ~HSYNC_ACTIVE));
            assert(vsync == (v_sync_model ? VSYNC_ACTIVE : ~VSYNC_ACTIVE));
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_model_q <= '0;
            v_model_q <= '0;
        end else if (tick_enable) begin
            if (h_model_q == COORD_W'(H_TOTAL - 1)) begin
                h_model_q <= '0;
                if (v_model_q == COORD_W'(V_TOTAL - 1)) begin
                    v_model_q <= '0;
                end else begin
                    v_model_q <= v_model_q + COORD_W'(1);
                end
            end else begin
                h_model_q <= h_model_q + COORD_W'(1);
            end
        end
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;

        if (!past_valid) begin
            assume(!rst_n);
        end

        if (past_valid && $past(rst_n) && rst_n && !$past(tick_enable)) begin
            assert(h_model_q == $past(h_model_q));
            assert(v_model_q == $past(v_model_q));
        end

        cover(past_valid && rst_n && pixel_valid && x == COORD_W'(H_ACTIVE - 1)
            && y == COORD_W'(V_ACTIVE - 1));
        cover(past_valid && rst_n && hsync == HSYNC_ACTIVE);
        cover(past_valid && rst_n && vsync == VSYNC_ACTIVE);
        cover(past_valid && rst_n && frame_start && $past(rst_n) && !$past(frame_start));
    end
endmodule
