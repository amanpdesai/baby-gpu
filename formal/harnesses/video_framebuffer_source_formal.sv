module video_framebuffer_source_formal;
    localparam int COORD_W = 3;

    logic pixel_valid;
    logic active;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic scanout_pixel_valid;
    logic scanout_pixel_ready;
    logic [COORD_W-1:0] scanout_pixel_x;
    logic [COORD_W-1:0] scanout_pixel_y;
    logic [15:0] scanout_pixel_color;
    logic framebuffer_rgb_valid;
    logic [15:0] framebuffer_rgb;
    logic underrun;
    logic coordinate_mismatch;

    logic active_pixel;
    logic coordinate_match;

    video_framebuffer_source #(
        .COORD_W(COORD_W)
    ) dut (
        .pixel_valid(pixel_valid),
        .active(active),
        .x(x),
        .y(y),
        .scanout_pixel_valid(scanout_pixel_valid),
        .scanout_pixel_ready(scanout_pixel_ready),
        .scanout_pixel_x(scanout_pixel_x),
        .scanout_pixel_y(scanout_pixel_y),
        .scanout_pixel_color(scanout_pixel_color),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .underrun(underrun),
        .coordinate_mismatch(coordinate_mismatch)
    );

    always_comb begin
        active_pixel = pixel_valid && active;
        coordinate_match = (scanout_pixel_x == x) && (scanout_pixel_y == y);

        assert(scanout_pixel_ready == active_pixel);
        assert(framebuffer_rgb_valid == (active_pixel && scanout_pixel_valid && coordinate_match));
        assert(underrun == (active_pixel && !scanout_pixel_valid));
        assert(coordinate_mismatch == (active_pixel && scanout_pixel_valid && !coordinate_match));

        if (framebuffer_rgb_valid) begin
            assert(framebuffer_rgb == scanout_pixel_color);
            assert(!underrun);
            assert(!coordinate_mismatch);
        end else begin
            assert(framebuffer_rgb == 16'h0000);
        end

        if (!active_pixel) begin
            assert(!scanout_pixel_ready);
            assert(!framebuffer_rgb_valid);
            assert(!underrun);
            assert(!coordinate_mismatch);
        end

        cover(framebuffer_rgb_valid && framebuffer_rgb == scanout_pixel_color);
        cover(underrun);
        cover(coordinate_mismatch);
    end
endmodule
