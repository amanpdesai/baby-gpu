module tb_video_timing;
    localparam int H_ACTIVE = 3;
    localparam int H_FRONT = 1;
    localparam int H_SYNC = 2;
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
    int errors;

    video_timing #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT(H_FRONT),
        .H_SYNC(H_SYNC),
        .H_BACK(H_BACK),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT(V_FRONT),
        .V_SYNC(V_SYNC),
        .V_BACK(V_BACK),
        .HSYNC_ACTIVE(1'b0),
        .VSYNC_ACTIVE(1'b0),
        .COORD_W(COORD_W)
    ) dut (
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

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check(input bit condition, input string message);
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

    task automatic expect_sample(
        input logic expected_pixel_valid,
        input logic expected_active,
        input logic expected_line_start,
        input logic expected_frame_start,
        input logic expected_hsync,
        input logic expected_vsync,
        input logic [COORD_W-1:0] expected_x,
        input logic [COORD_W-1:0] expected_y,
        input string label
    );
        begin
            #1;
            check(pixel_valid == expected_pixel_valid, {label, " pixel_valid"});
            check(active == expected_active, {label, " active"});
            check(line_start == expected_line_start, {label, " line_start"});
            check(frame_start == expected_frame_start, {label, " frame_start"});
            check(hsync == expected_hsync, {label, " hsync"});
            check(vsync == expected_vsync, {label, " vsync"});
            check(x == expected_x, {label, " x"});
            check(y == expected_y, {label, " y"});
        end
    endtask

    task automatic advance_and_expect(
        input logic expected_pixel_valid,
        input logic expected_active,
        input logic expected_line_start,
        input logic expected_frame_start,
        input logic expected_hsync,
        input logic expected_vsync,
        input logic [COORD_W-1:0] expected_x,
        input logic [COORD_W-1:0] expected_y,
        input string label
    );
        begin
            expect_sample(
                expected_pixel_valid,
                expected_active,
                expected_line_start,
                expected_frame_start,
                expected_hsync,
                expected_vsync,
                expected_x,
                expected_y,
                label
            );
            tick();
        end
    endtask

    task automatic reset_dut;
        begin
            rst_n = 1'b0;
            tick_enable = 1'b0;
            tick();
            rst_n = 1'b1;
            tick_enable = 1'b1;
            #1;
        end
    endtask

    task automatic test_first_active_line;
        begin
            reset_dut();
            advance_and_expect(1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 4'd0, 4'd0, "line0 pixel0");
            advance_and_expect(1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 4'd1, 4'd0, "line0 pixel1");
            advance_and_expect(1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd0, "line0 pixel2");
            advance_and_expect(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 4'd0, 4'd0, "line0 front porch");
            advance_and_expect(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 4'd0, 4'd0, "line0 hsync0");
            advance_and_expect(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 4'd0, 4'd0, "line0 hsync1");
            advance_and_expect(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 4'd0, 4'd0, "line0 back porch");
            advance_and_expect(1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 4'd0, 4'd1, "line1 pixel0");
        end
    endtask

    task automatic test_tick_enable_holds_position;
        begin
            reset_dut();
            tick();
            tick_enable = 1'b0;
            expect_sample(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 4'd1, 4'd0, "held sample");
            tick();
            expect_sample(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 4'd1, 4'd0, "still held sample");
            tick_enable = 1'b1;
            tick();
            expect_sample(1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 4'd2, 4'd0, "resumed sample");
        end
    endtask

    task automatic test_frame_wrap_and_vsync;
        begin
            reset_dut();
            repeat ((H_ACTIVE + H_FRONT + H_SYNC + H_BACK) * (V_ACTIVE + V_FRONT)) begin
                tick();
            end
            expect_sample(1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 4'd0, 4'd0, "vsync line start");
            repeat (H_ACTIVE + H_FRONT + H_SYNC + H_BACK) begin
                tick();
            end
            expect_sample(1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 4'd0, 4'd0, "vback line start");
            repeat (H_ACTIVE + H_FRONT + H_SYNC + H_BACK) begin
                tick();
            end
            expect_sample(1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 4'd0, 4'd0, "wrapped frame start");
        end
    endtask

    initial begin
        errors = 0;
        test_first_active_line();
        test_tick_enable_holds_position();
        test_frame_wrap_and_vsync();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
