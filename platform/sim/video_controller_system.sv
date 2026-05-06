module video_controller_system #(
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
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int LOCAL_ID_W = 1,
    parameter int FIFO_DEPTH = 4,
    parameter int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1),
    parameter int CHECKER_SHIFT = 4,
    parameter int DEPTH_WORDS = 1024,
    parameter int MASK_W = DATA_W / 8,
    parameter int CLIENTS = 2,
    parameter int SOURCE_ID_W = 1,
    parameter int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W
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

    input logic host_req_valid,
    output logic host_req_ready,
    input logic host_req_write,
    input logic [ADDR_W-1:0] host_req_addr,
    input logic [DATA_W-1:0] host_req_wdata,
    input logic [MASK_W-1:0] host_req_wmask,
    output logic host_rsp_valid,
    input logic host_rsp_ready,
    output logic [DATA_W-1:0] host_rsp_rdata,
    output logic host_rsp_error,

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
    localparam int HOST_CLIENT = 0;
    localparam int VIDEO_CLIENT = 1;

    logic video_req_valid;
    logic video_req_ready;
    logic video_req_write;
    logic [ADDR_W-1:0] video_req_addr;
    logic [DATA_W-1:0] video_req_wdata;
    logic [MASK_W-1:0] video_req_wmask;
    logic [LOCAL_ID_W-1:0] video_req_id;
    logic video_rsp_valid;
    logic video_rsp_ready;
    logic [DATA_W-1:0] video_rsp_rdata;
    logic [LOCAL_ID_W-1:0] video_rsp_id;
    logic video_rsp_error;

    logic [CLIENTS-1:0] client_req_valid;
    logic [CLIENTS-1:0] client_req_ready;
    logic [CLIENTS-1:0] client_req_write;
    logic [(CLIENTS*ADDR_W)-1:0] client_req_addr;
    logic [(CLIENTS*DATA_W)-1:0] client_req_wdata;
    logic [(CLIENTS*MASK_W)-1:0] client_req_wmask;
    logic [(CLIENTS*LOCAL_ID_W)-1:0] client_req_id;
    logic [CLIENTS-1:0] client_rsp_valid;
    logic [CLIENTS-1:0] client_rsp_ready;
    logic [(CLIENTS*DATA_W)-1:0] client_rsp_rdata;
    logic [(CLIENTS*LOCAL_ID_W)-1:0] client_rsp_id;
    logic [CLIENTS-1:0] client_rsp_error;

    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [MASK_W-1:0] mem_req_wmask;
    logic [MEM_ID_W-1:0] mem_req_id;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [DATA_W-1:0] mem_rsp_rdata;
    logic [MEM_ID_W-1:0] mem_rsp_id;
    logic mem_rsp_error;
    logic [MEM_ID_W-1:0] pending_mem_id_q;

    initial begin
        if (CLIENTS != 2) begin
            $fatal(1, "video_controller_system requires CLIENTS == 2");
        end
        if (DATA_W != 32) begin
            $fatal(1, "video_controller_system currently requires DATA_W == 32");
        end
        if (LOCAL_ID_W < 1) begin
            $fatal(1, "video_controller_system requires LOCAL_ID_W >= 1");
        end
        if (SOURCE_ID_W != 1) begin
            $fatal(1, "video_controller_system requires SOURCE_ID_W == 1");
        end
    end

    assign client_req_valid[HOST_CLIENT] = host_req_valid;
    assign client_req_valid[VIDEO_CLIENT] = video_req_valid;
    assign client_req_write[HOST_CLIENT] = host_req_write;
    assign client_req_write[VIDEO_CLIENT] = video_req_write;
    assign client_req_addr[(HOST_CLIENT*ADDR_W) +: ADDR_W] = host_req_addr;
    assign client_req_addr[(VIDEO_CLIENT*ADDR_W) +: ADDR_W] = video_req_addr;
    assign client_req_wdata[(HOST_CLIENT*DATA_W) +: DATA_W] = host_req_wdata;
    assign client_req_wdata[(VIDEO_CLIENT*DATA_W) +: DATA_W] = video_req_wdata;
    assign client_req_wmask[(HOST_CLIENT*MASK_W) +: MASK_W] = host_req_wmask;
    assign client_req_wmask[(VIDEO_CLIENT*MASK_W) +: MASK_W] = video_req_wmask;
    assign client_req_id[(HOST_CLIENT*LOCAL_ID_W) +: LOCAL_ID_W] = '0;
    assign client_req_id[(VIDEO_CLIENT*LOCAL_ID_W) +: LOCAL_ID_W] = video_req_id;

    assign host_req_ready = client_req_ready[HOST_CLIENT];
    assign video_req_ready = client_req_ready[VIDEO_CLIENT];
    assign client_rsp_ready[HOST_CLIENT] = host_rsp_ready;
    assign client_rsp_ready[VIDEO_CLIENT] = video_rsp_ready;
    assign host_rsp_valid = client_rsp_valid[HOST_CLIENT];
    assign video_rsp_valid = client_rsp_valid[VIDEO_CLIENT];
    assign host_rsp_rdata = client_rsp_rdata[(HOST_CLIENT*DATA_W) +: DATA_W];
    assign video_rsp_rdata = client_rsp_rdata[(VIDEO_CLIENT*DATA_W) +: DATA_W];
    assign video_rsp_id = client_rsp_id[(VIDEO_CLIENT*LOCAL_ID_W) +: LOCAL_ID_W];
    assign host_rsp_error = client_rsp_error[HOST_CLIENT];
    assign video_rsp_error = client_rsp_error[VIDEO_CLIENT];
    assign mem_rsp_id = pending_mem_id_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_mem_id_q <= '0;
        end else if (mem_req_valid && mem_req_ready) begin
            pending_mem_id_q <= mem_req_id;
        end
    end

    video_controller #(
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
        .COORD_W(COORD_W),
        .COLOR_W(16),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_COUNT_W(FIFO_COUNT_W),
        .CHECKER_SHIFT(CHECKER_SHIFT),
        .MASK_W(MASK_W)
    ) controller (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .source_select(source_select),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .scanout_start_valid(scanout_start_valid),
        .scanout_start_ready(scanout_start_ready),
        .fb_base(fb_base),
        .stride_bytes(stride_bytes),
        .fifo_flush(fifo_flush),
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
        .mem_req_valid(video_req_valid),
        .mem_req_ready(video_req_ready),
        .mem_req_write(video_req_write),
        .mem_req_addr(video_req_addr),
        .mem_req_wdata(video_req_wdata),
        .mem_req_wmask(video_req_wmask),
        .mem_req_id(video_req_id),
        .mem_rsp_valid(video_rsp_valid),
        .mem_rsp_ready(video_rsp_ready),
        .mem_rsp_rdata(video_rsp_rdata),
        .mem_rsp_id(video_rsp_id),
        .mem_rsp_error(video_rsp_error),
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

    memory_arbiter_rr #(
        .CLIENTS(CLIENTS),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .client_req_valid(client_req_valid),
        .client_req_ready(client_req_ready),
        .client_req_write(client_req_write),
        .client_req_addr(client_req_addr),
        .client_req_wdata(client_req_wdata),
        .client_req_wmask(client_req_wmask),
        .client_req_id(client_req_id),
        .client_rsp_valid(client_rsp_valid),
        .client_rsp_ready(client_rsp_ready),
        .client_rsp_rdata(client_rsp_rdata),
        .client_rsp_id(client_rsp_id),
        .client_rsp_error(client_rsp_error),
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

    data_memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH_WORDS(DEPTH_WORDS)
    ) framebuffer_memory (
        .clk(clk),
        .reset(!rst_n),
        .req_valid(mem_req_valid),
        .req_ready(mem_req_ready),
        .req_write(mem_req_write),
        .req_addr(mem_req_addr),
        .req_wdata(mem_req_wdata),
        .req_wmask(mem_req_wmask),
        .rsp_valid(mem_rsp_valid),
        .rsp_ready(mem_rsp_ready),
        .rsp_rdata(mem_rsp_rdata),
        .error(mem_rsp_error)
    );
endmodule
