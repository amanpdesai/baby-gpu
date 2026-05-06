module framebuffer_scanout #(
    parameter int FRAME_WIDTH = 160,
    parameter int FRAME_HEIGHT = 120,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int COLOR_W = 16,
    parameter int LOCAL_ID_W = 1,
    localparam int MASK_W = DATA_W / 8
) (
    input logic clk,
    input logic rst_n,

    input logic start_valid,
    output logic start_ready,
    input logic [ADDR_W-1:0] fb_base,
    input logic [ADDR_W-1:0] stride_bytes,

    output logic busy,
    output logic done,
    output logic error,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [COORD_W-1:0] pixel_x,
    output logic [COORD_W-1:0] pixel_y,
    output logic [COLOR_W-1:0] pixel_color,

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
    input logic mem_rsp_error
);
    localparam logic [LOCAL_ID_W-1:0] SCANOUT_REQ_ID = '0;

    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_REQ,
        STATE_RSP,
        STATE_PIXEL_LO,
        STATE_PIXEL_HI
    } state_t;

    state_t state_q;
    logic [ADDR_W-1:0] stride_bytes_q;
    logic [ADDR_W-1:0] row_base_q;
    logic [ADDR_W-1:0] current_addr_q;
    logic [COORD_W-1:0] x_word_q;
    logic [COORD_W-1:0] y_q;
    logic [DATA_W-1:0] rsp_word_q;
    logic error_q;
    logic done_q;
    logic [31:0] x_word_u32;
    logic [31:0] y_u32;
    logic last_low_pixel;
    logic last_word_in_row;
    logic last_row;
    logic rsp_id_error;

    initial begin
        if (FRAME_WIDTH < 1) $fatal(1, "framebuffer_scanout requires FRAME_WIDTH >= 1");
        if (FRAME_HEIGHT < 1) $fatal(1, "framebuffer_scanout requires FRAME_HEIGHT >= 1");
        if (ADDR_W < 3) $fatal(1, "framebuffer_scanout requires ADDR_W >= 3");
        if (DATA_W != 32) $fatal(1, "framebuffer_scanout requires DATA_W == 32");
        if (COORD_W < 1) $fatal(1, "framebuffer_scanout requires COORD_W >= 1");
        if (COORD_W > 32) $fatal(1, "framebuffer_scanout supports COORD_W <= 32");
        if (COLOR_W != 16) $fatal(1, "framebuffer_scanout requires COLOR_W == 16");
        if (LOCAL_ID_W < 1) $fatal(1, "framebuffer_scanout requires LOCAL_ID_W >= 1");
        if (COORD_W < 32 && 64'(FRAME_WIDTH) > (64'd1 << COORD_W)) $fatal(1, "FRAME_WIDTH exceeds COORD_W");
        if (COORD_W < 32 && 64'(FRAME_HEIGHT) > (64'd1 << COORD_W)) $fatal(1, "FRAME_HEIGHT exceeds COORD_W");
    end

    assign x_word_u32 = {{(32-COORD_W){1'b0}}, x_word_q};
    assign y_u32 = {{(32-COORD_W){1'b0}}, y_q};
    assign last_low_pixel = ((x_word_u32 + 32'd1) >= FRAME_WIDTH);
    assign last_word_in_row = ((x_word_u32 + 32'd2) >= FRAME_WIDTH);
    assign last_row = ((y_u32 + 32'd1) >= FRAME_HEIGHT);
    assign rsp_id_error = mem_rsp_valid && (mem_rsp_id != SCANOUT_REQ_ID);

    assign start_ready = (state_q == STATE_IDLE);
    assign busy = (state_q != STATE_IDLE);
    assign done = done_q;
    assign error = error_q;

    assign mem_req_valid = (state_q == STATE_REQ);
    assign mem_req_write = 1'b0;
    assign mem_req_addr = current_addr_q;
    assign mem_req_wdata = '0;
    assign mem_req_wmask = '0;
    assign mem_req_id = SCANOUT_REQ_ID;
    assign mem_rsp_ready = (state_q == STATE_RSP);

    assign pixel_valid = (state_q == STATE_PIXEL_LO) || (state_q == STATE_PIXEL_HI);
    assign pixel_x = (state_q == STATE_PIXEL_HI) ? (x_word_q + COORD_W'(1)) : x_word_q;
    assign pixel_y = y_q;
    assign pixel_color = (state_q == STATE_PIXEL_HI) ? rsp_word_q[31:16] : rsp_word_q[15:0];

    task automatic advance_word_or_finish;
        begin
            if (last_word_in_row) begin
                if (last_row) begin
                    state_q <= STATE_IDLE;
                    done_q <= 1'b1;
                end else begin
                    row_base_q <= row_base_q + stride_bytes_q;
                    current_addr_q <= row_base_q + stride_bytes_q;
                    y_q <= y_q + COORD_W'(1);
                    x_word_q <= '0;
                    state_q <= STATE_REQ;
                end
            end else begin
                current_addr_q <= current_addr_q + ADDR_W'(4);
                x_word_q <= x_word_q + COORD_W'(2);
                state_q <= STATE_REQ;
            end
        end
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= STATE_IDLE;
            stride_bytes_q <= '0;
            row_base_q <= '0;
            current_addr_q <= '0;
            x_word_q <= '0;
            y_q <= '0;
            rsp_word_q <= '0;
            error_q <= 1'b0;
            done_q <= 1'b0;
        end else begin
            done_q <= 1'b0;
            case (state_q)
                STATE_IDLE: begin
                    if (start_valid) begin
                        stride_bytes_q <= stride_bytes;
                        row_base_q <= fb_base;
                        current_addr_q <= fb_base;
                        x_word_q <= '0;
                        y_q <= '0;
                        error_q <= 1'b0;
                        state_q <= STATE_REQ;
                    end
                end

                STATE_REQ: begin
                    if (mem_req_ready) begin
                        state_q <= STATE_RSP;
                    end
                end

                STATE_RSP: begin
                    if (mem_rsp_valid) begin
                        rsp_word_q <= mem_rsp_rdata;
                        error_q <= error_q || mem_rsp_error || rsp_id_error;
                        state_q <= STATE_PIXEL_LO;
                    end
                end

                STATE_PIXEL_LO: begin
                    if (pixel_ready) begin
                        if (last_low_pixel) begin
                            advance_word_or_finish();
                        end else begin
                            state_q <= STATE_PIXEL_HI;
                        end
                    end
                end

                STATE_PIXEL_HI: begin
                    if (pixel_ready) begin
                        advance_word_or_finish();
                    end
                end

                default: begin
                    state_q <= STATE_IDLE;
                    error_q <= 1'b1;
                end
            endcase
        end
    end
endmodule
