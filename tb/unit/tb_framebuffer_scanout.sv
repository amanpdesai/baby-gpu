module tb_framebuffer_scanout;
    localparam int FRAME_WIDTH = 3;
    localparam int FRAME_HEIGHT = 2;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 8;
    localparam int COLOR_W = 16;
    localparam int LOCAL_ID_W = 1;
    localparam int MASK_W = DATA_W / 8;

    logic clk;
    logic rst_n;
    logic start_valid;
    logic start_ready;
    logic [ADDR_W-1:0] fb_base;
    logic [ADDR_W-1:0] stride_bytes;
    logic busy;
    logic done;
    logic error;
    logic pixel_valid;
    logic pixel_ready;
    logic [COORD_W-1:0] pixel_x;
    logic [COORD_W-1:0] pixel_y;
    logic [COLOR_W-1:0] pixel_color;
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
    int errors;

    framebuffer_scanout #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_valid(start_valid),
        .start_ready(start_ready),
        .fb_base(fb_base),
        .stride_bytes(stride_bytes),
        .busy(busy),
        .done(done),
        .error(error),
        .pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_color(pixel_color),
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
        .mem_rsp_error(mem_rsp_error)
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

    task automatic settle;
        begin
            #1;
        end
    endtask

    task automatic reset_dut;
        begin
            start_valid = 1'b0;
            fb_base = 32'h0000_1000;
            stride_bytes = 32'd16;
            pixel_ready = 1'b1;
            mem_req_ready = 1'b0;
            mem_rsp_valid = 1'b0;
            mem_rsp_rdata = '0;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            rst_n = 1'b0;
            tick();
            rst_n = 1'b1;
            tick();
        end
    endtask

    task automatic start_frame;
        begin
            check(start_ready, "scanout accepts start while idle");
            start_valid = 1'b1;
            tick();
            start_valid = 1'b0;
            settle();
            check(busy, "scanout becomes busy after start");
            check(!start_ready, "scanout rejects start while busy");
        end
    endtask

    task automatic expect_request(input logic [ADDR_W-1:0] addr, input string label);
        begin
            settle();
            check(mem_req_valid, {label, " request valid"});
            check(!mem_req_write, {label, " request is read"});
            check(mem_req_addr == addr, {label, " request address"});
            check(mem_req_wdata == '0, {label, " request write data zero"});
            check(mem_req_wmask == '0, {label, " request mask zero"});
            check(mem_req_id == '0, {label, " request ID zero"});
        end
    endtask

    task automatic accept_request;
        begin
            mem_req_ready = 1'b1;
            tick();
            mem_req_ready = 1'b0;
            settle();
        end
    endtask

    task automatic return_word(input logic [DATA_W-1:0] word, input bit rsp_error);
        begin
            check(mem_rsp_ready, "scanout ready for response");
            mem_rsp_rdata = word;
            mem_rsp_error = rsp_error;
            mem_rsp_id = '0;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;
            mem_rsp_error = 1'b0;
            settle();
        end
    endtask

    task automatic expect_pixel(
        input logic [COORD_W-1:0] x,
        input logic [COORD_W-1:0] y,
        input logic [COLOR_W-1:0] color,
        input string label
    );
        begin
            settle();
            check(pixel_valid, {label, " pixel valid"});
            check(pixel_x == x, {label, " pixel x"});
            check(pixel_y == y, {label, " pixel y"});
            check(pixel_color == color, {label, " pixel color"});
            tick();
        end
    endtask

    task automatic test_frame_sequence;
        begin
            reset_dut();
            start_frame();

            expect_request(32'h0000_1000, "row0 word0");
            accept_request();
            return_word(32'h2222_1111, 1'b0);
            expect_pixel(8'd0, 8'd0, 16'h1111, "pixel 0,0");
            expect_pixel(8'd1, 8'd0, 16'h2222, "pixel 1,0");

            expect_request(32'h0000_1004, "row0 word1");
            accept_request();
            return_word(32'h4444_3333, 1'b0);
            expect_pixel(8'd2, 8'd0, 16'h3333, "pixel 2,0");
            check(!pixel_valid, "odd-width high half is skipped");

            expect_request(32'h0000_1010, "row1 word0");
            accept_request();
            return_word(32'h6666_5555, 1'b0);
            expect_pixel(8'd0, 8'd1, 16'h5555, "pixel 0,1");
            expect_pixel(8'd1, 8'd1, 16'h6666, "pixel 1,1");

            expect_request(32'h0000_1014, "row1 word1");
            accept_request();
            return_word(32'h8888_7777, 1'b0);
            expect_pixel(8'd2, 8'd1, 16'h7777, "pixel 2,1");
            check(done, "last accepted pixel pulses done");
            check(!busy, "scanout returns idle after frame");
            check(start_ready, "scanout ready for next frame");
            check(!error, "clean frame has no error");
        end
    endtask

    task automatic test_request_backpressure_stability;
        begin
            reset_dut();
            start_frame();
            expect_request(32'h0000_1000, "stalled request");
            mem_req_ready = 1'b0;
            repeat (3) tick();
            expect_request(32'h0000_1000, "still stalled request");
            accept_request();
            check(mem_rsp_ready, "response phase follows accepted request");
        end
    endtask

    task automatic test_pixel_backpressure_stability;
        begin
            reset_dut();
            start_frame();
            accept_request();
            return_word(32'hBBBB_AAAA, 1'b0);
            pixel_ready = 1'b0;
            repeat (3) begin
                settle();
                check(pixel_valid, "stalled pixel remains valid");
                check(pixel_x == 8'd0, "stalled pixel x stable");
                check(pixel_color == 16'hAAAA, "stalled pixel color stable");
                tick();
            end
            pixel_ready = 1'b1;
            expect_pixel(8'd0, 8'd0, 16'hAAAA, "released pixel");
        end
    endtask

    task automatic test_response_error_sticky;
        begin
            reset_dut();
            start_frame();
            accept_request();
            return_word(32'h2222_1111, 1'b1);
            expect_pixel(8'd0, 8'd0, 16'h1111, "error frame still emits pixel");
            check(error, "response error is sticky");
        end
    endtask

    initial begin
        errors = 0;
        test_frame_sequence();
        test_request_backpressure_stability();
        test_pixel_backpressure_stability();
        test_response_error_sticky();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
