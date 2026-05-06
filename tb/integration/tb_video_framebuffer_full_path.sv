module tb_video_framebuffer_full_path;
    localparam int FRAME_WIDTH = 2;
    localparam int FRAME_HEIGHT = 1;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 4;
    localparam int COLOR_W = 16;
    localparam int LOCAL_ID_W = 1;
    localparam int MASK_W = DATA_W / 8;

    logic clk;
    logic rst_n;
    logic tick_enable;
    logic timing_pixel_valid;
    logic timing_active;
    logic timing_line_start;
    logic timing_frame_start;
    logic timing_hsync;
    logic timing_vsync;
    logic [COORD_W-1:0] timing_x;
    logic [COORD_W-1:0] timing_y;

    logic scanout_start_valid;
    logic scanout_start_ready;
    logic scanout_busy;
    logic scanout_done;
    logic scanout_error;
    logic scanout_pixel_valid;
    logic scanout_pixel_ready;
    logic [COORD_W-1:0] scanout_pixel_x;
    logic [COORD_W-1:0] scanout_pixel_y;
    logic [COLOR_W-1:0] scanout_pixel_color;
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

    logic framebuffer_rgb_valid;
    logic [15:0] framebuffer_rgb;
    logic source_underrun;
    logic source_coordinate_mismatch;
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
        .H_ACTIVE(FRAME_WIDTH),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(FRAME_HEIGHT),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .COORD_W(COORD_W)
    ) timing (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .line_start(timing_line_start),
        .frame_start(timing_frame_start),
        .hsync(timing_hsync),
        .vsync(timing_vsync),
        .x(timing_x),
        .y(timing_y)
    );

    framebuffer_scanout #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) scanout (
        .clk(clk),
        .rst_n(rst_n),
        .start_valid(scanout_start_valid),
        .start_ready(scanout_start_ready),
        .fb_base(32'h0000_8000),
        .stride_bytes(32'd4),
        .busy(scanout_busy),
        .done(scanout_done),
        .error(scanout_error),
        .pixel_valid(scanout_pixel_valid),
        .pixel_ready(scanout_pixel_ready),
        .pixel_x(scanout_pixel_x),
        .pixel_y(scanout_pixel_y),
        .pixel_color(scanout_pixel_color),
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

    video_framebuffer_source #(
        .COORD_W(COORD_W)
    ) source (
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .x(timing_x),
        .y(timing_y),
        .scanout_pixel_valid(scanout_pixel_valid),
        .scanout_pixel_ready(scanout_pixel_ready),
        .scanout_pixel_x(scanout_pixel_x),
        .scanout_pixel_y(scanout_pixel_y),
        .scanout_pixel_color(scanout_pixel_color),
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
        .line_start(timing_line_start),
        .frame_start(timing_frame_start),
        .hsync(timing_hsync),
        .vsync(timing_vsync),
        .x(timing_x),
        .y(timing_y),
        .source_select(1'b1),
        .pattern_rgb_valid(1'b1),
        .pattern_rgb(16'hFFFF),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
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

    task automatic start_and_prime_scanout;
        begin
            check(scanout_start_ready, "scanout starts idle");
            scanout_start_valid = 1'b1;
            tick();
            scanout_start_valid = 1'b0;

            check(mem_req_valid, "scanout requests first framebuffer word");
            check(!mem_req_write, "scanout request is read");
            check(mem_req_addr == 32'h0000_8000, "scanout requests framebuffer base");
            tick();

            check(mem_rsp_ready, "scanout waits for memory response");
            mem_rsp_rdata = 32'h2222_1111;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;

            check(scanout_pixel_valid, "scanout holds first pixel before timing starts");
            check(scanout_pixel_x == 4'd0, "primed scanout x0");
            check(scanout_pixel_y == 4'd0, "primed scanout y0");
            check(scanout_pixel_color == 16'h1111, "primed scanout low halfword");
        end
    endtask

    task automatic expect_output_pixel(
        input logic [COORD_W-1:0] expected_x,
        input logic [15:0] expected_rgb,
        input string message
    );
        begin
            check(out_pixel_valid, {message, ": pixel valid"});
            check(out_active, {message, ": active"});
            check(out_x == expected_x, {message, ": x"});
            check(out_y == 4'd0, {message, ": y"});
            check(out_rgb == expected_rgb, {message, ": rgb"});
            check(!source_missing, {message, ": source present"});
            check(!source_underrun, {message, ": no underrun"});
            check(!source_coordinate_mismatch, {message, ": no coordinate mismatch"});
        end
    endtask

    task automatic run_aligned_frame;
        begin
            tick_enable = 1'b1;
            #1;

            expect_output_pixel(4'd0, 16'h1111, "framebuffer pixel0");
            check(out_line_start, "framebuffer pixel0 line_start");
            check(out_frame_start, "framebuffer pixel0 frame_start");
            tick();

            expect_output_pixel(4'd1, 16'h2222, "framebuffer pixel1");
            tick();

            check(scanout_done, "scanout completes after final active pixel");
            check(!scanout_error, "scanout has no error");
            check(!out_pixel_valid, "front porch suppresses output valid");
            check(!out_active, "front porch suppresses output active");
            check(out_rgb == 16'h0000, "front porch emits black");
            check(!source_missing, "front porch does not flag missing source");
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();
        start_and_prime_scanout();
        run_aligned_frame();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
