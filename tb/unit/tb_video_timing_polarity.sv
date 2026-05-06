module tb_video_timing_polarity;
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
        .H_ACTIVE(1),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(1),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .HSYNC_ACTIVE(1'b1),
        .VSYNC_ACTIVE(1'b1),
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

    initial begin
        errors = 0;
        rst_n = 1'b0;
        tick_enable = 1'b1;
        tick();
        rst_n = 1'b1;
        #1;

        check(pixel_valid, "first active pixel valid");
        check(!hsync, "positive hsync inactive before sync interval");
        check(!vsync, "positive vsync inactive before sync interval");
        tick();
        check(!hsync, "front porch hsync inactive");
        tick();
        check(hsync, "sync interval drives active-high hsync");
        tick();
        check(!hsync, "back porch hsync inactive");
        tick();
        check(!pixel_valid, "vertical front porch inactive");
        repeat (4) begin
            tick();
        end
        check(vsync, "sync interval drives active-high vsync");

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
