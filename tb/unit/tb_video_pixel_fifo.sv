module tb_video_pixel_fifo;
    localparam int COORD_W = 4;
    localparam int COLOR_W = 16;
    localparam int DEPTH = 2;
    localparam int COUNT_W = 2;

    logic clk;
    logic rst_n;
    logic flush;
    logic in_valid;
    logic in_ready;
    logic [COORD_W-1:0] in_x;
    logic [COORD_W-1:0] in_y;
    logic [COLOR_W-1:0] in_color;
    logic out_valid;
    logic out_ready;
    logic [COORD_W-1:0] out_x;
    logic [COORD_W-1:0] out_y;
    logic [COLOR_W-1:0] out_color;
    logic full;
    logic empty;
    logic [COUNT_W-1:0] count;
    logic overflow;
    logic underflow;
    integer errors;

    video_pixel_fifo #(
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .DEPTH(DEPTH),
        .COUNT_W(COUNT_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_x(in_x),
        .in_y(in_y),
        .in_color(in_color),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_x(out_x),
        .out_y(out_y),
        .out_color(out_color),
        .full(full),
        .empty(empty),
        .count(count),
        .overflow(overflow),
        .underflow(underflow)
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
            in_valid = 1'b0;
            out_ready = 1'b0;
            in_x = '0;
            in_y = '0;
            in_color = 16'h0000;
            repeat (2) tick();
            rst_n = 1'b1;
            tick();
        end
    endtask

    task automatic push_pixel(
        input logic [COORD_W-1:0] x,
        input logic [COORD_W-1:0] y,
        input logic [COLOR_W-1:0] color
    );
        begin
            in_valid = 1'b1;
            in_x = x;
            in_y = y;
            in_color = color;
            #1;
            check(in_ready, "push sees ready");
            tick();
            in_valid = 1'b0;
            #1;
        end
    endtask

    task automatic expect_head(
        input logic [COORD_W-1:0] x,
        input logic [COORD_W-1:0] y,
        input logic [COLOR_W-1:0] color,
        input string message
    );
        begin
            check(out_valid, {message, ": out_valid"});
            check(out_x == x, {message, ": x"});
            check(out_y == y, {message, ": y"});
            check(out_color == color, {message, ": color"});
        end
    endtask

    task automatic pop_pixel;
        begin
            out_ready = 1'b1;
            tick();
            out_ready = 1'b0;
            #1;
        end
    endtask

    task automatic test_order_and_flags;
        begin
            reset_dut();
            check(empty, "reset fifo is empty");
            check(!out_valid, "reset fifo has no output");
            check(in_ready, "empty fifo is ready");

            push_pixel(4'd1, 4'd2, 16'h1111);
            expect_head(4'd1, 4'd2, 16'h1111, "first pushed pixel");
            check(count == 2'd1, "count after one push");

            push_pixel(4'd3, 4'd4, 16'h2222);
            expect_head(4'd1, 4'd2, 16'h1111, "first pixel remains at head");
            check(full, "fifo full after two pushes");
            check(!in_ready, "full fifo without pop is not ready");

            in_valid = 1'b1;
            in_x = 4'd5;
            in_y = 4'd6;
            in_color = 16'h3333;
            #1;
            check(overflow, "full fifo flags overflow attempt");
            in_valid = 1'b0;

            pop_pixel();
            expect_head(4'd3, 4'd4, 16'h2222, "second pixel after first pop");
            check(count == 2'd1, "count after pop");

            pop_pixel();
            check(empty, "fifo empty after second pop");
            check(!out_valid, "empty fifo has no output valid");
            out_ready = 1'b1;
            #1;
            check(underflow, "empty fifo flags underflow attempt");
            out_ready = 1'b0;
        end
    endtask

    task automatic test_simultaneous_full_push_pop;
        begin
            reset_dut();
            push_pixel(4'd1, 4'd0, 16'hAAAA);
            push_pixel(4'd2, 4'd0, 16'hBBBB);

            in_valid = 1'b1;
            in_x = 4'd3;
            in_y = 4'd0;
            in_color = 16'hCCCC;
            out_ready = 1'b1;
            #1;
            check(in_ready, "full fifo accepts push when pop also happens");
            check(out_valid && out_color == 16'hAAAA, "simultaneous pop sees old head");
            tick();
            in_valid = 1'b0;
            out_ready = 1'b0;
            #1;

            expect_head(4'd2, 4'd0, 16'hBBBB, "second pixel after simultaneous cycle");
            pop_pixel();
            expect_head(4'd3, 4'd0, 16'hCCCC, "new pixel retained after simultaneous cycle");
            check(count == 2'd1, "count remains full-minus-one after one later pop");
        end
    endtask

    task automatic test_flush;
        begin
            reset_dut();
            push_pixel(4'd1, 4'd1, 16'h0101);
            flush = 1'b1;
            in_valid = 1'b1;
            in_x = 4'd2;
            in_y = 4'd2;
            in_color = 16'h0202;
            out_ready = 1'b1;
            #1;
            check(!in_ready, "flush blocks push handshake");
            check(!out_valid, "flush blocks pop handshake");
            check(!overflow, "flush does not report overflow");
            check(!underflow, "flush does not report underflow");
            tick();
            flush = 1'b0;
            in_valid = 1'b0;
            out_ready = 1'b0;
            #1;
            check(empty, "flush empties fifo");
            check(!out_valid, "flush clears output valid");
            check(count == 2'd0, "flush clears count");
        end
    endtask

    initial begin
        errors = 0;
        test_order_and_flags();
        test_simultaneous_full_push_pop();
        test_flush();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
