module tb_video_timing_pattern_mux;
    localparam int H_ACTIVE = 4;
    localparam int H_FRONT = 1;
    localparam int H_SYNC = 1;
    localparam int H_BACK = 1;
    localparam int V_ACTIVE = 1;
    localparam int V_FRONT = 1;
    localparam int V_SYNC = 1;
    localparam int V_BACK = 1;
    localparam int COORD_W = 4;

    logic clk;
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
    logic pattern_rgb_valid;
    logic [15:0] pattern_rgb;
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

    video_timing #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT(H_FRONT),
        .H_SYNC(H_SYNC),
        .H_BACK(H_BACK),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT(V_FRONT),
        .V_SYNC(V_SYNC),
        .V_BACK(V_BACK),
        .COORD_W(COORD_W)
    ) timing (
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

    video_test_pattern #(
        .COORD_W(COORD_W),
        .H_ACTIVE(H_ACTIVE),
        .CHECKER_SHIFT(1)
    ) pattern (
        .pixel_valid(pixel_valid),
        .active(active),
        .pattern_select(2'd1),
        .solid_rgb(16'h0000),
        .x(x),
        .y(y),
        .rgb_valid(pattern_rgb_valid),
        .rgb(pattern_rgb)
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
        .source_select(1'b0),
        .pattern_rgb_valid(pattern_rgb_valid),
        .pattern_rgb(pattern_rgb),
        .framebuffer_rgb_valid(1'b0),
        .framebuffer_rgb(16'h0000),
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
            tick_enable = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            tick_enable = 1'b1;
            #1;
        end
    endtask

    task automatic expect_pixel(
        input logic [COORD_W-1:0] expected_x,
        input logic [15:0] expected_rgb,
        input string message
    );
        begin
            check(out_pixel_valid, {message, ": out_pixel_valid"});
            check(out_active, {message, ": out_active"});
            check(out_x == expected_x, {message, ": out_x"});
            check(out_y == 4'd0, {message, ": out_y"});
            check(out_rgb == expected_rgb, {message, ": out_rgb"});
            check(!source_missing, {message, ": source available"});
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();

        expect_pixel(4'd0, 16'hFFFF, "pattern mux pixel0");
        check(out_line_start, "pattern mux forwards line_start");
        check(out_frame_start, "pattern mux forwards frame_start");
        tick();

        expect_pixel(4'd1, 16'hFFE0, "pattern mux pixel1");
        tick();

        expect_pixel(4'd2, 16'h07FF, "pattern mux pixel2");
        tick();

        expect_pixel(4'd3, 16'h07E0, "pattern mux pixel3");
        tick();

        check(!out_pixel_valid, "blanking suppresses out_pixel_valid");
        check(!out_active, "blanking suppresses out_active");
        check(out_rgb == 16'h0000, "blanking through mux emits black");

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
