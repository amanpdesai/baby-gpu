module video_stream_mux #(
    parameter int COORD_W = 12
) (
    input logic pixel_valid,
    input logic active,
    input logic line_start,
    input logic frame_start,
    input logic hsync,
    input logic vsync,
    input logic [COORD_W-1:0] x,
    input logic [COORD_W-1:0] y,

    input logic source_select,
    input logic pattern_rgb_valid,
    input logic [15:0] pattern_rgb,
    input logic framebuffer_rgb_valid,
    input logic [15:0] framebuffer_rgb,

    output logic out_pixel_valid,
    output logic out_active,
    output logic out_line_start,
    output logic out_frame_start,
    output logic out_hsync,
    output logic out_vsync,
    output logic [COORD_W-1:0] out_x,
    output logic [COORD_W-1:0] out_y,
    output logic [15:0] out_rgb,
    output logic source_missing
);
    localparam logic SOURCE_PATTERN = 1'b0;
    localparam logic SOURCE_FRAMEBUFFER = 1'b1;

    logic selected_valid;
    logic [15:0] selected_rgb;

    initial begin
        if (COORD_W < 1) begin
            $fatal(1, "video_stream_mux requires COORD_W >= 1");
        end
    end

    assign out_pixel_valid = pixel_valid;
    assign out_active = active;
    assign out_line_start = line_start;
    assign out_frame_start = frame_start;
    assign out_hsync = hsync;
    assign out_vsync = vsync;
    assign out_x = x;
    assign out_y = y;

    always_comb begin
        selected_valid = pattern_rgb_valid;
        selected_rgb = pattern_rgb;

        if (source_select == SOURCE_FRAMEBUFFER) begin
            selected_valid = framebuffer_rgb_valid;
            selected_rgb = framebuffer_rgb;
        end else if (source_select != SOURCE_PATTERN) begin
            selected_valid = 1'b0;
            selected_rgb = 16'h0000;
        end
    end

    always_comb begin
        source_missing = 1'b0;
        out_rgb = 16'h0000;

        if (active && pixel_valid) begin
            source_missing = !selected_valid;
            if (selected_valid) begin
                out_rgb = selected_rgb;
            end
        end
    end
endmodule
