module tb_video_fifo_source_mux;
    localparam int COORD_W = 4;
    localparam int COLOR_W = 16;
    localparam int DEPTH = 4;
    localparam int COUNT_W = 3;

    logic clk;
    logic rst_n;
    logic flush;
    logic fifo_in_valid;
    logic fifo_in_ready;
    logic [COORD_W-1:0] fifo_in_x;
    logic [COORD_W-1:0] fifo_in_y;
    logic [COLOR_W-1:0] fifo_in_color;
    logic fifo_out_valid;
    logic fifo_out_ready;
    logic [COORD_W-1:0] fifo_out_x;
    logic [COORD_W-1:0] fifo_out_y;
    logic [COLOR_W-1:0] fifo_out_color;
    logic fifo_full;
    logic fifo_empty;
    logic [COUNT_W-1:0] fifo_count;
    logic fifo_overflow;
    logic fifo_underflow;

    logic timing_pixel_valid;
    logic timing_active;
    logic [COORD_W-1:0] timing_x;
    logic [COORD_W-1:0] timing_y;
    logic framebuffer_rgb_valid;
    logic [15:0] framebuffer_rgb;
    logic source_underrun;
    logic source_coordinate_mismatch;
    logic out_pixel_valid;
    logic out_active;
    logic [COORD_W-1:0] out_x;
    logic [COORD_W-1:0] out_y;
    logic [15:0] out_rgb;
    logic source_missing;
    integer errors;

    video_pixel_fifo #(
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .DEPTH(DEPTH),
        .COUNT_W(COUNT_W)
    ) fifo (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid(fifo_in_valid),
        .in_ready(fifo_in_ready),
        .in_x(fifo_in_x),
        .in_y(fifo_in_y),
        .in_color(fifo_in_color),
        .out_valid(fifo_out_valid),
        .out_ready(fifo_out_ready),
        .out_x(fifo_out_x),
        .out_y(fifo_out_y),
        .out_color(fifo_out_color),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    video_framebuffer_source #(
        .COORD_W(COORD_W)
    ) source (
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .x(timing_x),
        .y(timing_y),
        .scanout_pixel_valid(fifo_out_valid),
        .scanout_pixel_ready(fifo_out_ready),
        .scanout_pixel_x(fifo_out_x),
        .scanout_pixel_y(fifo_out_y),
        .scanout_pixel_color(fifo_out_color),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .underrun(source_underrun),
        .coordinate_mismatch(source_coordinate_mismatch)
    );

    video_stream_mux #(
        .COORD_W(COORD_W)
    ) mux (
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .line_start(1'b0),
        .frame_start(1'b0),
        .hsync(1'b1),
        .vsync(1'b1),
        .x(timing_x),
        .y(timing_y),
        .source_select(1'b1),
        .pattern_rgb_valid(1'b1),
        .pattern_rgb(16'hFFFF),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .out_pixel_valid(out_pixel_valid),
        .out_active(out_active),
        .out_line_start(),
        .out_frame_start(),
        .out_hsync(),
        .out_vsync(),
        .out_x(out_x),
        .out_y(out_y),
        .out_rgb(out_rgb),
        .source_missing(source_missing)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                errors++;
            end
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic reset_dut;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            flush = 1'b0;
            fifo_in_valid = 1'b0;
            fifo_in_x = '0;
            fifo_in_y = '0;
            fifo_in_color = 16'h0000;
            timing_pixel_valid = 1'b0;
            timing_active = 1'b0;
            timing_x = '0;
            timing_y = '0;
            repeat (2) tick();
            rst_n = 1'b1;
            tick();
        end
    endtask

    task automatic fifo_push(
        input logic [COORD_W-1:0] x,
        input logic [COORD_W-1:0] y,
        input logic [COLOR_W-1:0] color
    );
        begin
            fifo_in_valid = 1'b1;
            fifo_in_x = x;
            fifo_in_y = y;
            fifo_in_color = color;
            #1;
            check(fifo_in_ready, "fifo accepts preload pixel");
            tick();
            fifo_in_valid = 1'b0;
            #1;
        end
    endtask

    task automatic expect_timing_pixel(
        input logic [COORD_W-1:0] x,
        input logic [COORD_W-1:0] y,
        input logic [COLOR_W-1:0] color,
        input string message
    );
        begin
            timing_pixel_valid = 1'b1;
            timing_active = 1'b1;
            timing_x = x;
            timing_y = y;
            #1;
            check(out_pixel_valid, {message, ": output valid"});
            check(out_active, {message, ": output active"});
            check(out_x == x, {message, ": output x"});
            check(out_y == y, {message, ": output y"});
            check(out_rgb == color, {message, ": output color"});
            check(!source_missing, {message, ": source present"});
            check(!source_underrun, {message, ": no underrun"});
            check(!source_coordinate_mismatch, {message, ": no mismatch"});
            tick();
            timing_pixel_valid = 1'b0;
            timing_active = 1'b0;
            #1;
        end
    endtask

    task automatic test_preloaded_pixels_feed_timing;
        begin
            reset_dut();
            fifo_push(4'd0, 4'd0, 16'h1111);
            fifo_push(4'd1, 4'd0, 16'h2222);
            check(fifo_count == 3'd2, "two pixels preloaded");

            expect_timing_pixel(4'd0, 4'd0, 16'h1111, "first preloaded pixel");
            expect_timing_pixel(4'd1, 4'd0, 16'h2222, "second preloaded pixel");
            check(fifo_empty, "fifo drains after two timing pixels");
        end
    endtask

    task automatic test_empty_fifo_reports_underrun;
        begin
            reset_dut();
            timing_pixel_valid = 1'b1;
            timing_active = 1'b1;
            timing_x = 4'd0;
            timing_y = 4'd0;
            #1;
            check(fifo_underflow, "empty fifo sees pop attempt");
            check(source_underrun, "source reports underrun from empty fifo");
            check(source_missing, "mux reports missing framebuffer source");
            check(out_rgb == 16'h0000, "empty fifo path emits black");
            timing_pixel_valid = 1'b0;
            timing_active = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        test_preloaded_pixels_feed_timing();
        test_empty_fifo_reports_underrun();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
