module tb_video_timing_test_pattern;
    localparam int H_ACTIVE = 4;
    localparam int H_FRONT = 1;
    localparam int H_SYNC = 1;
    localparam int H_BACK = 1;
    localparam int V_ACTIVE = 2;
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
    logic rgb_valid;
    logic [15:0] rgb;
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
        .rgb_valid(rgb_valid),
        .rgb(rgb)
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
        input logic expected_active,
        input logic [COORD_W-1:0] expected_x,
        input logic [COORD_W-1:0] expected_y,
        input logic [15:0] expected_rgb,
        input string message
    );
        begin
            check(pixel_valid, {message, ": pixel_valid"});
            check(rgb_valid, {message, ": rgb_valid follows timing"});
            check(active == expected_active, {message, ": active"});
            check(x == expected_x, {message, ": x"});
            check(y == expected_y, {message, ": y"});
            check(rgb == expected_rgb, {message, ": rgb"});
        end
    endtask

    task automatic test_first_line_bars_and_blanking;
        begin
            expect_pixel(1'b1, 4'd0, 4'd0, 16'hFFFF, "first active pixel");
            check(line_start, "first active pixel marks line start");
            check(frame_start, "first active pixel marks frame start");
            tick();

            expect_pixel(1'b1, 4'd1, 4'd0, 16'hFFE0, "second active pixel");
            tick();

            expect_pixel(1'b1, 4'd2, 4'd0, 16'h07FF, "third active pixel");
            tick();

            expect_pixel(1'b1, 4'd3, 4'd0, 16'h07E0, "fourth active pixel");
            tick();

            check(!active, "front porch is inactive");
            check(!pixel_valid, "front porch suppresses pixel_valid");
            check(!rgb_valid, "front porch suppresses rgb_valid");
            check(rgb == 16'h0000, "front porch emits black");
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();
        test_first_line_bars_and_blanking();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end else begin
            $display("FAIL: %0d errors", errors);
            $fatal(1);
        end
    end
endmodule
