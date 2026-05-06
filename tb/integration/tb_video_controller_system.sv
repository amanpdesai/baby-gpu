module tb_video_controller_system;
    localparam int COORD_W = 4;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int MASK_W = DATA_W / 8;
    localparam int FIFO_COUNT_W = 1;

    logic clk;
    logic rst_n;
    logic tick_enable;
    logic source_select;
    logic [1:0] pattern_select;
    logic [15:0] solid_rgb;
    logic scanout_start_valid;
    logic scanout_start_ready;
    logic fifo_flush;
    logic host_req_valid;
    logic host_req_ready;
    logic host_req_write;
    logic [ADDR_W-1:0] host_req_addr;
    logic [DATA_W-1:0] host_req_wdata;
    logic [MASK_W-1:0] host_req_wmask;
    logic host_rsp_valid;
    logic host_rsp_ready;
    logic [DATA_W-1:0] host_rsp_rdata;
    logic host_rsp_error;
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

    video_controller_system #(
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
        .FIFO_DEPTH(1),
        .FIFO_COUNT_W(FIFO_COUNT_W),
        .CHECKER_SHIFT(1),
        .DEPTH_WORDS(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .source_select(source_select),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .scanout_start_valid(scanout_start_valid),
        .scanout_start_ready(scanout_start_ready),
        .fb_base(8'h20),
        .stride_bytes(8'd4),
        .fifo_flush(fifo_flush),
        .host_req_valid(host_req_valid),
        .host_req_ready(host_req_ready),
        .host_req_write(host_req_write),
        .host_req_addr(host_req_addr),
        .host_req_wdata(host_req_wdata),
        .host_req_wmask(host_req_wmask),
        .host_rsp_valid(host_rsp_valid),
        .host_rsp_ready(host_rsp_ready),
        .host_rsp_rdata(host_rsp_rdata),
        .host_rsp_error(host_rsp_error),
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
            source_select = 1'b0;
            pattern_select = 2'd0;
            solid_rgb = 16'h0000;
            scanout_start_valid = 1'b0;
            fifo_flush = 1'b0;
            host_req_valid = 1'b0;
            host_req_write = 1'b0;
            host_req_addr = '0;
            host_req_wdata = '0;
            host_req_wmask = '0;
            host_rsp_ready = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            #1;
        end
    endtask

    task automatic host_write_word(
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] data
    );
        begin
            host_req_valid = 1'b1;
            host_req_write = 1'b1;
            host_req_addr = addr;
            host_req_wdata = data;
            host_req_wmask = 4'b1111;
            #1;
            check(host_req_ready, "host write request accepted");
            tick();
            host_req_valid = 1'b0;
            host_req_write = 1'b0;
            host_rsp_ready = 1'b1;
            #1;
            check(host_rsp_valid, "host write response valid");
            check(!host_rsp_error, "host write has no error");
            tick();
            host_rsp_ready = 1'b0;
        end
    endtask

    task automatic host_read_word(
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] expected_data
    );
        begin
            host_req_valid = 1'b1;
            host_req_write = 1'b0;
            host_req_addr = addr;
            host_req_wdata = '0;
            host_req_wmask = '0;
            #1;
            check(host_req_ready, "host read request accepted");
            tick();
            host_req_valid = 1'b0;
            #1;
            check(host_rsp_valid, "host read response held under backpressure");
            check(host_rsp_rdata == expected_data, "host read response data while backpressured");
            check(!host_rsp_error, "host read has no error");
            tick();
            check(host_rsp_valid, "host read response remains valid while backpressured");
            host_rsp_ready = 1'b1;
            tick();
            host_rsp_ready = 1'b0;
        end
    endtask

    task automatic wait_for_fifo_full;
        begin
            for (int i = 0; i < 12 && !fifo_full; i++) begin
                tick();
            end
            check(fifo_full, "controller system fifo fills from framebuffer memory");
            check(fifo_count == 1'b1, "controller system fifo count after scanout prime");
        end
    endtask

    task automatic test_pattern_output;
        begin
            reset_dut();
            source_select = 1'b0;
            pattern_select = 2'd0;
            solid_rgb = 16'h1357;
            tick_enable = 1'b1;
            #1;
            check(pixel_valid, "system pattern pixel valid");
            check(active, "system pattern pixel active");
            check(x == 4'd0, "system pattern starts x0");
            check(rgb == 16'h1357, "system pattern emits solid color");
            check(!source_missing, "system pattern source is present");
            check(!framebuffer_underrun, "system pattern has no framebuffer underrun");
        end
    endtask

    task automatic test_host_preload_framebuffer_output;
        begin
            reset_dut();
            host_write_word(8'h20, 32'h2222_1111);

            source_select = 1'b1;
            scanout_start_valid = 1'b1;
            tick();
            scanout_start_valid = 1'b0;
            wait_for_fifo_full();

            tick_enable = 1'b1;
            #1;
            check(pixel_valid, "system framebuffer pixel0 valid");
            check(active, "system framebuffer pixel0 active");
            check(line_start, "system framebuffer pixel0 line_start");
            check(frame_start, "system framebuffer pixel0 frame_start");
            check(x == 4'd0, "system framebuffer pixel0 x");
            check(rgb == 16'h1111, "system framebuffer pixel0 rgb");
            check(!source_missing, "system framebuffer pixel0 source present");
            tick();

            check(pixel_valid, "system framebuffer pixel1 valid");
            check(active, "system framebuffer pixel1 active");
            check(x == 4'd1, "system framebuffer pixel1 x");
            check(rgb == 16'h2222, "system framebuffer pixel1 rgb");
            check(scanout_done, "system scanout done after second pixel");
            tick();

            check(!pixel_valid, "system front porch suppresses pixel_valid");
            check(rgb == 16'h0000, "system front porch emits black");
            check(fifo_empty, "system fifo drains after frame");
            check(!fifo_underflow, "system fifo has no underflow");
            check(!fifo_overflow, "system fifo has no overflow");
            check(!scanout_error, "system scanout has no error");
        end
    endtask

    task automatic test_host_readback_backpressure;
        begin
            reset_dut();
            host_write_word(8'h24, 32'hCAFE_BABE);
            host_read_word(8'h24, 32'hCAFE_BABE);
        end
    endtask

    task automatic test_host_video_contention;
        begin
            reset_dut();
            host_write_word(8'h20, 32'h4444_3333);

            source_select = 1'b1;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "contention scanout starts idle");
            tick();
            scanout_start_valid = 1'b0;
            #1;
            check(scanout_busy, "contention scanout is waiting to request memory");

            host_req_valid = 1'b1;
            host_req_write = 1'b0;
            host_req_addr = 8'h20;
            host_req_wdata = '0;
            host_req_wmask = '0;
            #1;
            check(!host_req_ready, "contention host waits while video request wins first grant");
            tick();
            check(host_req_valid, "contention host request remains asserted after video grant");

            host_rsp_ready = 1'b0;
            for (int i = 0; i < 4 && !host_req_ready; i++) begin
                tick();
                check(host_req_valid, "contention host request remains asserted while video response clears");
            end
            check(host_req_ready, "contention host request wins after video response clears");
            tick();
            host_req_valid = 1'b0;
            check(host_rsp_valid, "contention host response returns after video response");
            check(host_rsp_rdata == 32'h4444_3333, "contention host read data");
            check(!host_rsp_error, "contention host read has no error");
            host_rsp_ready = 1'b1;
            tick();
            host_rsp_ready = 1'b0;

            wait_for_fifo_full();
            check(fifo_full, "contention video request eventually fills fifo");
            check(fifo_count == 1'b1, "contention fifo count after video request");

            tick_enable = 1'b1;
            #1;
            check(pixel_valid, "contention framebuffer pixel valid");
            check(rgb == 16'h3333, "contention framebuffer first pixel rgb");
            check(!source_missing, "contention framebuffer source present");
            tick();
            tick_enable = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        test_pattern_output();
        test_host_preload_framebuffer_output();
        test_host_readback_backpressure();
        test_host_video_contention();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
