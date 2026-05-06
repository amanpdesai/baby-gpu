module video_framebuffer_source #(
    parameter int COORD_W = 12
) (
    input logic pixel_valid,
    input logic active,
    input logic [COORD_W-1:0] x,
    input logic [COORD_W-1:0] y,

    input logic scanout_pixel_valid,
    output logic scanout_pixel_ready,
    input logic [COORD_W-1:0] scanout_pixel_x,
    input logic [COORD_W-1:0] scanout_pixel_y,
    input logic [15:0] scanout_pixel_color,

    output logic framebuffer_rgb_valid,
    output logic [15:0] framebuffer_rgb,
    output logic underrun,
    output logic coordinate_mismatch
);
    logic active_pixel;
    logic coordinate_match;

    initial begin
        if (COORD_W < 1) begin
            $fatal(1, "video_framebuffer_source requires COORD_W >= 1");
        end
    end

    assign active_pixel = pixel_valid && active;
    assign coordinate_match = (scanout_pixel_x == x) && (scanout_pixel_y == y);
    assign scanout_pixel_ready = active_pixel;
    assign framebuffer_rgb_valid = active_pixel && scanout_pixel_valid && coordinate_match;
    assign framebuffer_rgb = framebuffer_rgb_valid ? scanout_pixel_color : 16'h0000;
    assign underrun = active_pixel && !scanout_pixel_valid;
    assign coordinate_mismatch = active_pixel && scanout_pixel_valid && !coordinate_match;
endmodule
