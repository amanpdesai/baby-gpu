module video_controller #(
    parameter int H_ACTIVE = 640,
    parameter int H_FRONT = 16,
    parameter int H_SYNC = 96,
    parameter int H_BACK = 48,
    parameter int V_ACTIVE = 480,
    parameter int V_FRONT = 10,
    parameter int V_SYNC = 2,
    parameter int V_BACK = 33,
    parameter bit HSYNC_ACTIVE = 1'b0,
    parameter bit VSYNC_ACTIVE = 1'b0,
    parameter int COORD_W = 12,
    parameter int COLOR_W = 16,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int LOCAL_ID_W = 1,
    parameter int FIFO_DEPTH = 4,
    parameter int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1),
    parameter int CHECKER_SHIFT = 4,
    parameter int MASK_W = DATA_W / 8
) (
    input logic clk,
    input logic rst_n,
    input logic tick_enable,

    input logic source_select,
    input logic [1:0] pattern_select,
    input logic [15:0] solid_rgb,

    input logic scanout_start_valid,
    output logic scanout_start_ready,
    input logic [ADDR_W-1:0] fb_base,
    input logic [ADDR_W-1:0] stride_bytes,
    input logic fifo_flush,

    output logic scanout_busy,
    output logic scanout_done,
    output logic scanout_error,
    output logic fifo_full,
    output logic fifo_empty,
    output logic [FIFO_COUNT_W-1:0] fifo_count,
    output logic fifo_overflow,
    output logic fifo_underflow,
    output logic framebuffer_underrun,
    output logic framebuffer_coordinate_mismatch,
    output logic source_missing,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_W-1:0] mem_req_addr,
    output logic [DATA_W-1:0] mem_req_wdata,
    output logic [MASK_W-1:0] mem_req_wmask,
    output logic [LOCAL_ID_W-1:0] mem_req_id,
    input logic mem_rsp_valid,
    output logic mem_rsp_ready,
    input logic [DATA_W-1:0] mem_rsp_rdata,
    input logic [LOCAL_ID_W-1:0] mem_rsp_id,
    input logic mem_rsp_error,

    output logic pixel_valid,
    output logic active,
    output logic line_start,
    output logic frame_start,
    output logic hsync,
    output logic vsync,
    output logic [COORD_W-1:0] x,
    output logic [COORD_W-1:0] y,
    output logic [15:0] rgb
);
    logic timing_pixel_valid;
    logic timing_active;
    logic timing_line_start;
    logic timing_frame_start;
    logic timing_hsync;
    logic timing_vsync;
    logic [COORD_W-1:0] timing_x;
    logic [COORD_W-1:0] timing_y;

    logic scanout_pixel_valid;
    logic scanout_pixel_ready;
    logic [COORD_W-1:0] scanout_pixel_x;
    logic [COORD_W-1:0] scanout_pixel_y;
    logic [COLOR_W-1:0] scanout_pixel_color;

    logic fifo_pixel_valid;
    logic fifo_pixel_ready;
    logic [COORD_W-1:0] fifo_pixel_x;
    logic [COORD_W-1:0] fifo_pixel_y;
    logic [COLOR_W-1:0] fifo_pixel_color;

    logic pattern_rgb_valid;
    logic [15:0] pattern_rgb;
    logic framebuffer_rgb_valid;
    logic [15:0] framebuffer_rgb;

    initial begin
        if (COLOR_W != 16) begin
            $fatal(1, "video_controller currently requires COLOR_W == 16");
        end
        if (DATA_W != 32) begin
            $fatal(1, "video_controller currently requires DATA_W == 32");
        end
        if (FIFO_COUNT_W < $clog2(FIFO_DEPTH + 1)) begin
            $fatal(1, "video_controller FIFO_COUNT_W cannot represent FIFO_DEPTH");
        end
    end

    video_timing #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT(H_FRONT),
        .H_SYNC(H_SYNC),
        .H_BACK(H_BACK),
        .V_ACTIVE(V_ACTIVE),
        .V_FRONT(V_FRONT),
        .V_SYNC(V_SYNC),
        .V_BACK(V_BACK),
        .HSYNC_ACTIVE(HSYNC_ACTIVE),
        .VSYNC_ACTIVE(VSYNC_ACTIVE),
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
        .FRAME_WIDTH(H_ACTIVE),
        .FRAME_HEIGHT(V_ACTIVE),
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
        .fb_base(fb_base),
        .stride_bytes(stride_bytes),
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

    video_pixel_fifo #(
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .DEPTH(FIFO_DEPTH),
        .COUNT_W(FIFO_COUNT_W)
    ) fifo (
        .clk(clk),
        .rst_n(rst_n),
        .flush(fifo_flush),
        .in_valid(scanout_pixel_valid),
        .in_ready(scanout_pixel_ready),
        .in_x(scanout_pixel_x),
        .in_y(scanout_pixel_y),
        .in_color(scanout_pixel_color),
        .out_valid(fifo_pixel_valid),
        .out_ready(fifo_pixel_ready),
        .out_x(fifo_pixel_x),
        .out_y(fifo_pixel_y),
        .out_color(fifo_pixel_color),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    video_framebuffer_source #(
        .COORD_W(COORD_W)
    ) framebuffer_source (
        .pixel_valid(source_select ? timing_pixel_valid : 1'b0),
        .active(source_select ? timing_active : 1'b0),
        .x(timing_x),
        .y(timing_y),
        .scanout_pixel_valid(fifo_pixel_valid),
        .scanout_pixel_ready(fifo_pixel_ready),
        .scanout_pixel_x(fifo_pixel_x),
        .scanout_pixel_y(fifo_pixel_y),
        .scanout_pixel_color(fifo_pixel_color[15:0]),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .underrun(framebuffer_underrun),
        .coordinate_mismatch(framebuffer_coordinate_mismatch)
    );

    video_test_pattern #(
        .COORD_W(COORD_W),
        .H_ACTIVE(H_ACTIVE),
        .CHECKER_SHIFT(CHECKER_SHIFT)
    ) test_pattern (
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .x(timing_x),
        .y(timing_y),
        .rgb_valid(pattern_rgb_valid),
        .rgb(pattern_rgb)
    );

    video_stream_mux #(
        .COORD_W(COORD_W)
    ) stream_mux (
        .pixel_valid(timing_pixel_valid),
        .active(timing_active),
        .line_start(timing_line_start),
        .frame_start(timing_frame_start),
        .hsync(timing_hsync),
        .vsync(timing_vsync),
        .x(timing_x),
        .y(timing_y),
        .source_select(source_select),
        .pattern_rgb_valid(pattern_rgb_valid),
        .pattern_rgb(pattern_rgb),
        .framebuffer_rgb_valid(framebuffer_rgb_valid),
        .framebuffer_rgb(framebuffer_rgb),
        .out_pixel_valid(pixel_valid),
        .out_active(active),
        .out_line_start(line_start),
        .out_frame_start(frame_start),
        .out_hsync(hsync),
        .out_vsync(vsync),
        .out_x(x),
        .out_y(y),
        .out_rgb(rgb),
        .source_missing(source_missing)
    );
endmodule
