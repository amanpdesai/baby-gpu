module tb_video_framebuffer_source_mux;
    localparam int COORD_W = 4;

    logic pixel_valid;
    logic active;
    logic line_start;
    logic frame_start;
    logic hsync;
    logic vsync;
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

    video_framebuffer_source #(
        .COORD_W(COORD_W)
    ) source (
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

    video_stream_mux #(
        .COORD_W(COORD_W)
    ) mux (
        .pixel_valid(pixel_valid),
        .active(active),
        .line_start(line_start),
        .frame_start(frame_start),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
        .source_select(1'b1),
        .pattern_rgb_valid(1'b1),
        .pattern_rgb(16'hFFFF),
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
            line_start = 1'b0;
            frame_start = 1'b0;
            hsync = 1'b1;
            vsync = 1'b1;
            x = 4'd1;
            y = 4'd2;
            scanout_pixel_valid = 1'b1;
            scanout_pixel_x = 4'd1;
            scanout_pixel_y = 4'd2;
            scanout_pixel_color = 16'h1234;
            #1;
        end
    endtask

    task automatic check_timing_passthrough;
        begin
            check(out_pixel_valid == pixel_valid, "mux forwards pixel_valid");
            check(out_active == active, "mux forwards active");
            check(out_line_start == line_start, "mux forwards line_start");
            check(out_frame_start == frame_start, "mux forwards frame_start");
            check(out_hsync == hsync, "mux forwards hsync");
            check(out_vsync == vsync, "mux forwards vsync");
            check(out_x == x, "mux forwards x");
            check(out_y == y, "mux forwards y");
        end
    endtask

    task automatic test_aligned_framebuffer_pixel;
        begin
            drive_common();
            check_timing_passthrough();
            check(scanout_pixel_ready, "aligned active pixel consumes scanout data");
            check(framebuffer_rgb_valid, "adapter presents aligned framebuffer RGB");
            check(out_rgb == 16'h1234, "mux emits aligned framebuffer RGB");
            check(!source_missing, "mux sees framebuffer source present");
            check(!underrun, "aligned path does not underrun");
            check(!coordinate_mismatch, "aligned path does not mismatch");
        end
    endtask

    task automatic test_underrun_reaches_mux;
        begin
            drive_common();
            scanout_pixel_valid = 1'b0;
            #1;
            check(scanout_pixel_ready, "underrun still requests scanout data");
            check(underrun, "adapter flags underrun");
            check(!coordinate_mismatch, "underrun is not coordinate mismatch");
            check(source_missing, "mux flags missing framebuffer source");
            check(out_rgb == 16'h0000, "mux blacks out underrun");
        end
    endtask

    task automatic test_mismatch_reaches_mux;
        begin
            drive_common();
            scanout_pixel_y = 4'd3;
            #1;
            check(scanout_pixel_ready, "mismatch consumes scanout data on timing cadence");
            check(!underrun, "mismatch is not underrun");
            check(coordinate_mismatch, "adapter flags coordinate mismatch");
            check(source_missing, "mux flags missing usable framebuffer source");
            check(out_rgb == 16'h0000, "mux blacks out coordinate mismatch");
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
        scanout_pixel_valid = 1'b0;
        scanout_pixel_x = '0;
        scanout_pixel_y = '0;
        scanout_pixel_color = 16'h0000;

        test_aligned_framebuffer_pixel();
        test_underrun_reaches_mux();
        test_mismatch_reaches_mux();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
