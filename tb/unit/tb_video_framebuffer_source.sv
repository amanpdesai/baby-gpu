module tb_video_framebuffer_source;
    localparam int COORD_W = 4;

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
    integer errors;

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
            x = 4'd3;
            y = 4'd2;
            scanout_pixel_valid = 1'b1;
            scanout_pixel_x = 4'd3;
            scanout_pixel_y = 4'd2;
            scanout_pixel_color = 16'h5A5A;
            #1;
        end
    endtask

    task automatic test_aligned_pixel;
        begin
            drive_common();
            check(scanout_pixel_ready, "active timing pixel consumes scanout pixel");
            check(framebuffer_rgb_valid, "aligned scanout pixel is valid framebuffer RGB");
            check(framebuffer_rgb == 16'h5A5A, "aligned scanout pixel forwards color");
            check(!underrun, "aligned scanout pixel does not underrun");
            check(!coordinate_mismatch, "aligned scanout pixel does not mismatch");
        end
    endtask

    task automatic test_blanking_holds_scanout;
        begin
            drive_common();
            pixel_valid = 1'b0;
            active = 1'b0;
            #1;
            check(!scanout_pixel_ready, "blanking does not consume scanout pixel");
            check(!framebuffer_rgb_valid, "blanking does not present framebuffer RGB");
            check(framebuffer_rgb == 16'h0000, "blanking emits black");
            check(!underrun, "blanking does not underrun");
            check(!coordinate_mismatch, "blanking does not mismatch");
        end
    endtask

    task automatic test_underrun;
        begin
            drive_common();
            scanout_pixel_valid = 1'b0;
            #1;
            check(scanout_pixel_ready, "active timing pixel still requests scanout data");
            check(!framebuffer_rgb_valid, "underrun suppresses framebuffer RGB valid");
            check(framebuffer_rgb == 16'h0000, "underrun emits black");
            check(underrun, "underrun is flagged");
            check(!coordinate_mismatch, "underrun is not a coordinate mismatch");
        end
    endtask

    task automatic test_x_mismatch;
        begin
            drive_common();
            scanout_pixel_x = 4'd4;
            #1;
            check(scanout_pixel_ready, "mismatched pixel is consumed on active cadence");
            check(!framebuffer_rgb_valid, "x mismatch suppresses framebuffer RGB valid");
            check(framebuffer_rgb == 16'h0000, "x mismatch emits black");
            check(!underrun, "valid mismatched pixel is not an underrun");
            check(coordinate_mismatch, "x mismatch is flagged");
        end
    endtask

    task automatic test_y_mismatch;
        begin
            drive_common();
            scanout_pixel_y = 4'd3;
            #1;
            check(scanout_pixel_ready, "y mismatched pixel is consumed on active cadence");
            check(!framebuffer_rgb_valid, "y mismatch suppresses framebuffer RGB valid");
            check(framebuffer_rgb == 16'h0000, "y mismatch emits black");
            check(!underrun, "valid y mismatched pixel is not an underrun");
            check(coordinate_mismatch, "y mismatch is flagged");
        end
    endtask

    initial begin
        errors = 0;
        pixel_valid = 1'b0;
        active = 1'b0;
        x = '0;
        y = '0;
        scanout_pixel_valid = 1'b0;
        scanout_pixel_x = '0;
        scanout_pixel_y = '0;
        scanout_pixel_color = 16'h0000;

        test_aligned_pixel();
        test_blanking_holds_scanout();
        test_underrun();
        test_x_mismatch();
        test_y_mismatch();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
