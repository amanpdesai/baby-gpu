module tb_video_test_pattern;
    localparam int COORD_W = 4;
    localparam int H_ACTIVE = 16;
    localparam int CHECKER_SHIFT = 1;

    localparam logic [1:0] PATTERN_SOLID = 2'd0;
    localparam logic [1:0] PATTERN_BARS = 2'd1;
    localparam logic [1:0] PATTERN_CHECKER = 2'd2;
    localparam logic [1:0] PATTERN_GRADIENT = 2'd3;

    logic pixel_valid;
    logic active;
    logic [1:0] pattern_select;
    logic [15:0] solid_rgb;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic rgb_valid;
    logic [15:0] rgb;
    integer errors;

    video_test_pattern #(
        .COORD_W(COORD_W),
        .H_ACTIVE(H_ACTIVE),
        .CHECKER_SHIFT(CHECKER_SHIFT)
    ) dut (
        .pixel_valid(pixel_valid),
        .active(active),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .x(x),
        .y(y),
        .rgb_valid(rgb_valid),
        .rgb(rgb)
    );

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                errors++;
            end
        end
    endtask

    task automatic drive(
        input logic next_pixel_valid,
        input logic next_active,
        input logic [1:0] next_pattern_select,
        input logic [COORD_W-1:0] next_x,
        input logic [COORD_W-1:0] next_y
    );
        begin
            pixel_valid = next_pixel_valid;
            active = next_active;
            pattern_select = next_pattern_select;
            x = next_x;
            y = next_y;
            #1;
        end
    endtask

    task automatic expect_rgb(input logic [15:0] expected_rgb, input string message);
        begin
            check(rgb == expected_rgb, message);
        end
    endtask

    task automatic test_solid_and_blank;
        begin
            solid_rgb = 16'h2A5B;

            drive(1'b1, 1'b1, PATTERN_SOLID, 4'd3, 4'd2);
            check(rgb_valid, "solid pattern forwards pixel_valid");
            expect_rgb(16'h2A5B, "solid pattern emits configured color");

            drive(1'b0, 1'b1, PATTERN_SOLID, 4'd3, 4'd2);
            check(!rgb_valid, "rgb_valid deasserts with pixel_valid");
            expect_rgb(16'h2A5B, "solid color remains combinational while active");

            drive(1'b1, 1'b0, PATTERN_SOLID, 4'd3, 4'd2);
            check(rgb_valid, "blanking still forwards timing valid");
            expect_rgb(16'h0000, "inactive region emits black");
        end
    endtask

    task automatic test_color_bars;
        begin
            drive(1'b1, 1'b1, PATTERN_BARS, 4'd0, 4'd0);
            expect_rgb(16'hFFFF, "bar 0 is white");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd2, 4'd0);
            expect_rgb(16'hFFE0, "bar 1 is yellow");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd4, 4'd0);
            expect_rgb(16'h07FF, "bar 2 is cyan");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd6, 4'd0);
            expect_rgb(16'h07E0, "bar 3 is green");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd8, 4'd0);
            expect_rgb(16'hF81F, "bar 4 is magenta");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd10, 4'd0);
            expect_rgb(16'hF800, "bar 5 is red");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd12, 4'd0);
            expect_rgb(16'h001F, "bar 6 is blue");

            drive(1'b1, 1'b1, PATTERN_BARS, 4'd14, 4'd0);
            expect_rgb(16'h0000, "bar 7 is black");
        end
    endtask

    task automatic test_checker;
        begin
            drive(1'b1, 1'b1, PATTERN_CHECKER, 4'd0, 4'd0);
            expect_rgb(16'h0000, "checker matching tile parity is black");

            drive(1'b1, 1'b1, PATTERN_CHECKER, 4'd2, 4'd0);
            expect_rgb(16'hFFFF, "checker horizontal parity flip is white");

            drive(1'b1, 1'b1, PATTERN_CHECKER, 4'd2, 4'd2);
            expect_rgb(16'h0000, "checker double parity flip is black");
        end
    endtask

    task automatic test_gradient;
        begin
            drive(1'b1, 1'b1, PATTERN_GRADIENT, 4'd9, 4'd6);
            expect_rgb(16'h48CF, "gradient packs x, y, and xor coordinate bits");
        end
    endtask

    initial begin
        errors = 0;
        pixel_valid = 1'b0;
        active = 1'b0;
        pattern_select = PATTERN_SOLID;
        solid_rgb = 16'h0000;
        x = '0;
        y = '0;

        test_solid_and_blank();
        test_color_bars();
        test_checker();
        test_gradient();

        if (errors == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", errors);
            $fatal(1);
        end
    end
endmodule
