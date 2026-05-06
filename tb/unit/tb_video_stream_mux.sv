module tb_video_stream_mux;
    localparam int COORD_W = 4;

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
    integer errors;

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

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                errors++;
            end
        end
    endtask

    task automatic drive_common;
        begin
            pixel_valid = 1'b1;
            active = 1'b1;
            line_start = 1'b1;
            frame_start = 1'b0;
            hsync = 1'b1;
            vsync = 1'b0;
            x = 4'd9;
            y = 4'd3;
            pattern_rgb_valid = 1'b1;
            pattern_rgb = 16'h2A5B;
            framebuffer_rgb_valid = 1'b1;
            framebuffer_rgb = 16'h4C3D;
            #1;
        end
    endtask

    task automatic check_timing_passthrough;
        begin
            check(out_pixel_valid == pixel_valid, "pixel_valid passes through");
            check(out_active == active, "active passes through");
            check(out_line_start == line_start, "line_start passes through");
            check(out_frame_start == frame_start, "frame_start passes through");
            check(out_hsync == hsync, "hsync passes through");
            check(out_vsync == vsync, "vsync passes through");
            check(out_x == x, "x passes through");
            check(out_y == y, "y passes through");
        end
    endtask

    task automatic test_pattern_mode;
        begin
            drive_common();
            source_select = 1'b0;
            #1;
            check_timing_passthrough();
            check(out_rgb == 16'h2A5B, "pattern mode selects pattern RGB");
            check(!source_missing, "pattern mode does not flag missing source");
        end
    endtask

    task automatic test_framebuffer_mode;
        begin
            drive_common();
            source_select = 1'b1;
            #1;
            check_timing_passthrough();
            check(out_rgb == 16'h4C3D, "framebuffer mode selects framebuffer RGB");
            check(!source_missing, "framebuffer mode does not flag missing source");
        end
    endtask

    task automatic test_missing_source_blacks_active_pixel;
        begin
            drive_common();
            source_select = 1'b1;
            framebuffer_rgb_valid = 1'b0;
            #1;
            check(source_missing, "missing framebuffer source is flagged");
            check(out_rgb == 16'h0000, "missing source emits black");
            check(out_pixel_valid, "missing source preserves pixel cadence");
        end
    endtask

    task automatic test_blanking_suppresses_missing;
        begin
            drive_common();
            source_select = 1'b1;
            active = 1'b0;
            framebuffer_rgb_valid = 1'b0;
            #1;
            check(!source_missing, "blanking does not flag missing source");
            check(out_rgb == 16'h0000, "blanking emits black");
        end
    endtask

    initial begin
        errors = 0;
        pixel_valid = 1'b0;
        active = 1'b0;
        line_start = 1'b0;
        frame_start = 1'b0;
        hsync = 1'b0;
        vsync = 1'b0;
        x = '0;
        y = '0;
        source_select = 1'b0;
        pattern_rgb_valid = 1'b0;
        pattern_rgb = 16'h0000;
        framebuffer_rgb_valid = 1'b0;
        framebuffer_rgb = 16'h0000;

        test_pattern_mode();
        test_framebuffer_mode();
        test_missing_source_blacks_active_pixel();
        test_blanking_suppresses_missing();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
