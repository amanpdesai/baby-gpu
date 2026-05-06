module video_timing #(
    parameter int H_ACTIVE = 640,
    parameter int H_FRONT = 16,
    parameter int H_SYNC = 96,
    parameter int H_BACK = 48,
    parameter int V_ACTIVE = 480,
    parameter int V_FRONT = 10,
    parameter int V_SYNC = 2,
    parameter int V_BACK = 33,
    parameter bit HSYNC_ACTIVE = 1'b0,
    parameter bit VSYNC_ACTIVE = 1'b0,
    parameter int COORD_W = 16,
    localparam int H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK,
    localparam int V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK
) (
    input logic clk,
    input logic rst_n,
    input logic tick_enable,

    output logic pixel_valid,
    output logic active,
    output logic line_start,
    output logic frame_start,
    output logic hsync,
    output logic vsync,
    output logic [COORD_W-1:0] x,
    output logic [COORD_W-1:0] y
);
    logic [COORD_W-1:0] h_count_q;
    logic [COORD_W-1:0] v_count_q;
    logic h_active_region;
    logic v_active_region;
    logic h_sync_region;
    logic v_sync_region;
    logic last_h;
    logic last_v;

    initial begin
        if (H_ACTIVE < 1) $fatal(1, "video_timing requires H_ACTIVE >= 1");
        if (H_FRONT < 0) $fatal(1, "video_timing requires H_FRONT >= 0");
        if (H_SYNC < 1) $fatal(1, "video_timing requires H_SYNC >= 1");
        if (H_BACK < 0) $fatal(1, "video_timing requires H_BACK >= 0");
        if (V_ACTIVE < 1) $fatal(1, "video_timing requires V_ACTIVE >= 1");
        if (V_FRONT < 0) $fatal(1, "video_timing requires V_FRONT >= 0");
        if (V_SYNC < 1) $fatal(1, "video_timing requires V_SYNC >= 1");
        if (V_BACK < 0) $fatal(1, "video_timing requires V_BACK >= 0");
        if (COORD_W < 1) $fatal(1, "video_timing requires COORD_W >= 1");
        if (COORD_W < 32 && 64'(H_TOTAL) > (64'd1 << COORD_W)) $fatal(1, "H_TOTAL exceeds COORD_W");
        if (COORD_W < 32 && 64'(V_TOTAL) > (64'd1 << COORD_W)) $fatal(1, "V_TOTAL exceeds COORD_W");
    end

    assign h_active_region = h_count_q < COORD_W'(H_ACTIVE);
    assign v_active_region = v_count_q < COORD_W'(V_ACTIVE);
    assign active = h_active_region && v_active_region;
    assign pixel_valid = tick_enable && active;
    assign line_start = tick_enable && (h_count_q == '0);
    assign frame_start = line_start && (v_count_q == '0);
    assign x = h_active_region ? h_count_q : '0;
    assign y = v_active_region ? v_count_q : '0;

    assign h_sync_region =
        (h_count_q >= COORD_W'(H_ACTIVE + H_FRONT)) &&
        (h_count_q < COORD_W'(H_ACTIVE + H_FRONT + H_SYNC));
    assign v_sync_region =
        (v_count_q >= COORD_W'(V_ACTIVE + V_FRONT)) &&
        (v_count_q < COORD_W'(V_ACTIVE + V_FRONT + V_SYNC));
    assign hsync = h_sync_region ? HSYNC_ACTIVE : ~HSYNC_ACTIVE;
    assign vsync = v_sync_region ? VSYNC_ACTIVE : ~VSYNC_ACTIVE;
    assign last_h = h_count_q == COORD_W'(H_TOTAL - 1);
    assign last_v = v_count_q == COORD_W'(V_TOTAL - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count_q <= '0;
            v_count_q <= '0;
        end else if (tick_enable) begin
            if (last_h) begin
                h_count_q <= '0;
                if (last_v) begin
                    v_count_q <= '0;
                end else begin
                    v_count_q <= v_count_q + COORD_W'(1);
                end
            end else begin
                h_count_q <= h_count_q + COORD_W'(1);
            end
        end
    end
endmodule
