module tb_video_controller_framebuffer;
    localparam int COORD_W = 4;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int MASK_W = DATA_W / 8;
    localparam int LOCAL_ID_W = 1;
    localparam int FIFO_COUNT_W = 1;

    logic clk;
    logic rst_n;
    logic tick_enable;
    logic scanout_start_valid;
    logic scanout_start_ready;
    logic scanout_busy;
    logic scanout_done;
    logic scanout_error;
    logic fifo_full;
    logic fifo_empty;
    logic [FIFO_COUNT_W-1:0] fifo_count;
    logic fifo_overflow;
    logic fifo_underflow;
    logic framebuffer_underrun;
    logic framebuffer_coordinate_mismatch;
    logic source_missing;
    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [MASK_W-1:0] mem_req_wmask;
    logic [LOCAL_ID_W-1:0] mem_req_id;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [DATA_W-1:0] mem_rsp_rdata;
    logic [LOCAL_ID_W-1:0] mem_rsp_id;
    logic mem_rsp_error;
    logic pixel_valid;
    logic active;
    logic line_start;
    logic frame_start;
    logic hsync;
    logic vsync;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic [15:0] rgb;
    integer errors;

    video_controller #(
        .H_ACTIVE(2),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(1),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W),
        .FIFO_DEPTH(1),
        .FIFO_COUNT_W(FIFO_COUNT_W),
        .CHECKER_SHIFT(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .source_select(1'b1),
        .pattern_select(2'd0),
        .solid_rgb(16'hFFFF),
        .scanout_start_valid(scanout_start_valid),
        .scanout_start_ready(scanout_start_ready),
        .fb_base(32'h0000_9000),
        .stride_bytes(32'd4),
        .fifo_flush(1'b0),
        .scanout_busy(scanout_busy),
        .scanout_done(scanout_done),
        .scanout_error(scanout_error),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .fifo_overflow(fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .framebuffer_underrun(framebuffer_underrun),
        .framebuffer_coordinate_mismatch(framebuffer_coordinate_mismatch),
        .source_missing(source_missing),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wmask(mem_req_wmask),
        .mem_req_id(mem_req_id),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_id(mem_rsp_id),
        .mem_rsp_error(mem_rsp_error),
        .pixel_valid(pixel_valid),
        .active(active),
        .line_start(line_start),
        .frame_start(frame_start),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
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
            scanout_start_valid = 1'b0;
            mem_req_ready = 1'b1;
            mem_rsp_valid = 1'b0;
            mem_rsp_rdata = '0;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            #1;
        end
    endtask

    task automatic prime_framebuffer;
        begin
            check(scanout_start_ready, "controller scanout starts idle");
            scanout_start_valid = 1'b1;
            tick();
            scanout_start_valid = 1'b0;

            check(mem_req_valid, "controller scanout requests framebuffer word");
            check(!mem_req_write, "controller scanout issues read");
            check(mem_req_addr == 32'h0000_9000, "controller scanout requests fb base");
            tick();

            check(mem_rsp_ready, "controller scanout waits for memory response");
            mem_rsp_rdata = 32'hBBBB_AAAA;
            mem_rsp_id = '0;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;

            tick();
            check(fifo_full, "controller fifo stores first pixel");
            check(fifo_count == 1'b1, "controller fifo count after prime");
        end
    endtask

    task automatic expect_pixel(
        input logic [COORD_W-1:0] expected_x,
        input logic [15:0] expected_rgb,
        input string message
    );
        begin
            check(pixel_valid, {message, ": pixel_valid"});
            check(active, {message, ": active"});
            check(x == expected_x, {message, ": x"});
            check(y == 4'd0, {message, ": y"});
            check(rgb == expected_rgb, {message, ": rgb"});
            check(!source_missing, {message, ": no source missing"});
            check(!framebuffer_underrun, {message, ": no underrun"});
            check(!framebuffer_coordinate_mismatch, {message, ": no coordinate mismatch"});
        end
    endtask

    task automatic test_scanout_response_error;
        begin
            reset_dut();
            check(scanout_start_ready, "error scanout starts idle");
            scanout_start_valid = 1'b1;
            tick();
            scanout_start_valid = 1'b0;

            check(mem_req_valid, "error scanout issues framebuffer request");
            check(!mem_req_write, "error scanout issues read");
            check(mem_req_addr == 32'h0000_9000, "error scanout requests fb base");
            tick();

            check(mem_rsp_ready, "error scanout waits for memory response");
            mem_rsp_rdata = 32'hDDDD_CCCC;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b1;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;
            mem_rsp_error = 1'b0;

            tick();
            check(scanout_error, "controller propagates scanout memory error");
            check(fifo_full, "errored response still queues returned pixel");
            check(fifo_count == 1'b1, "errored response fifo count");
            check(!fifo_underflow, "errored response does not underflow fifo");
            tick_enable = 1'b1;
            #1;
            expect_pixel(4'd0, 16'hCCCC, "error response pixel still visible");
            check(scanout_error, "scanout error remains sticky while pixel is consumed");
            tick();
            check(scanout_error, "scanout error remains sticky after errored pixel pop");
            check(!fifo_overflow, "errored pixel pop does not overflow fifo");
            check(!fifo_underflow, "errored pixel pop does not underflow fifo");
            tick_enable = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();
        prime_framebuffer();

        tick_enable = 1'b1;
        #1;
        expect_pixel(4'd0, 16'hAAAA, "controller fb pixel0");
        check(line_start, "controller fb pixel0 line_start");
        check(frame_start, "controller fb pixel0 frame_start");
        tick();

        expect_pixel(4'd1, 16'hBBBB, "controller fb pixel1");
        check(scanout_done, "controller scanout done after final pixel");
        tick();

        check(fifo_empty, "controller fifo empty after frame");
        check(!fifo_underflow, "controller fifo no underflow");
        check(!fifo_overflow, "controller fifo no overflow");
        check(!scanout_error, "controller scanout no error");
        check(!pixel_valid, "controller front porch suppresses pixel_valid");
        check(rgb == 16'h0000, "controller front porch emits black");

        test_scanout_response_error();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
