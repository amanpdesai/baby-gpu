module video_stream_mux_formal;
    localparam int COORD_W = 3;

    logic pixel_valid;
    logic active;
    logic line_start;
    logic frame_start;
    logic hsync;
    logic vsync;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic source_select;
    logic pattern_rgb_valid;
    logic [15:0] pattern_rgb;
    logic framebuffer_rgb_valid;
    logic [15:0] framebuffer_rgb;
    logic out_pixel_valid;
    logic out_active;
    logic out_line_start;
    logic out_frame_start;
    logic out_hsync;
    logic out_vsync;
    logic [COORD_W-1:0] out_x;
    logic [COORD_W-1:0] out_y;
    logic [15:0] out_rgb;
    logic source_missing;

    logic selected_valid;
    logic [15:0] selected_rgb;

    video_stream_mux #(
        .COORD_W(COORD_W)
    ) dut (
        .pixel_valid(pixel_valid),
        .active(active),
        .line_start(line_start),
        .frame_start(frame_start),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
        .source_select(source_select),
        .pattern_rgb_valid(pattern_rgb_valid),
        .pattern_rgb(pattern_rgb),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .out_pixel_valid(out_pixel_valid),
        .out_active(out_active),
        .out_line_start(out_line_start),
        .out_frame_start(out_frame_start),
        .out_hsync(out_hsync),
        .out_vsync(out_vsync),
        .out_x(out_x),
        .out_y(out_y),
        .out_rgb(out_rgb),
        .source_missing(source_missing)
    );

    always_comb begin
        selected_valid = source_select ? framebuffer_rgb_valid : pattern_rgb_valid;
        selected_rgb = source_select ? framebuffer_rgb : pattern_rgb;

        assert(out_pixel_valid == pixel_valid);
        assert(out_active == active);
        assert(out_line_start == line_start);
        assert(out_frame_start == frame_start);
        assert(out_hsync == hsync);
        assert(out_vsync == vsync);
        assert(out_x == x);
        assert(out_y == y);

        if (active && pixel_valid && selected_valid) begin
            assert(out_rgb == selected_rgb);
            assert(!source_missing);
        end

        if (active && pixel_valid && !selected_valid) begin
            assert(out_rgb == 16'h0000);
            assert(source_missing);
        end

        if (!active || !pixel_valid) begin
            assert(out_rgb == 16'h0000);
            assert(!source_missing);
        end

        cover(active && pixel_valid && !source_select && pattern_rgb_valid && out_rgb == pattern_rgb);
        cover(active && pixel_valid && source_select && framebuffer_rgb_valid && out_rgb == framebuffer_rgb);
        cover(active && pixel_valid && source_missing);
    end
endmodule
