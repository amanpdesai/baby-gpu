module video_pixel_fifo #(
    parameter int COORD_W = 12,
    parameter int COLOR_W = 16,
    parameter int DEPTH = 4,
    parameter int COUNT_W = $clog2(DEPTH + 1)
) (
    input logic clk,
    input logic rst_n,
    input logic flush,

    input logic in_valid,
    output logic in_ready,
    input logic [COORD_W-1:0] in_x,
    input logic [COORD_W-1:0] in_y,
    input logic [COLOR_W-1:0] in_color,

    output logic out_valid,
    input logic out_ready,
    output logic [COORD_W-1:0] out_x,
    output logic [COORD_W-1:0] out_y,
    output logic [COLOR_W-1:0] out_color,

    output logic full,
    output logic empty,
    output logic [COUNT_W-1:0] count,
    output logic overflow,
    output logic underflow
);
    localparam int PIXEL_W = (2 * COORD_W) + COLOR_W;
    localparam int REQUIRED_COUNT_W = (DEPTH < 1) ? 1 : $clog2(DEPTH + 1);
    localparam logic [COUNT_W-1:0] DEPTH_COUNT = COUNT_W'(DEPTH);

    logic [(DEPTH*PIXEL_W)-1:0] payload_q;
    logic [COUNT_W-1:0] count_q;
    logic [COUNT_W-1:0] push_index;
    logic [PIXEL_W-1:0] in_payload;
    logic [PIXEL_W-1:0] out_payload;
    logic push;
    logic pop;

    initial begin
        if (COORD_W < 1) begin
            $fatal(1, "video_pixel_fifo requires COORD_W >= 1");
        end
        if (COLOR_W < 1) begin
            $fatal(1, "video_pixel_fifo requires COLOR_W >= 1");
        end
        if (DEPTH < 1) begin
            $fatal(1, "video_pixel_fifo requires DEPTH >= 1");
        end
        if (COUNT_W < 1) begin
            $fatal(1, "video_pixel_fifo requires COUNT_W >= 1");
        end
        if (COUNT_W < REQUIRED_COUNT_W) begin
            $fatal(1, "video_pixel_fifo COUNT_W cannot represent DEPTH");
        end
    end

    assign full = count_q == DEPTH_COUNT;
    assign empty = count_q == '0;
    assign out_valid = !flush && !empty;
    assign in_ready = !flush && (!full || (out_ready && out_valid));
    assign push = in_valid && in_ready;
    assign pop = out_ready && out_valid;
    assign overflow = !flush && in_valid && !in_ready;
    assign underflow = !flush && out_ready && !out_valid;
    assign count = count_q;
    assign push_index = pop ? (count_q - COUNT_W'(1)) : count_q;
    assign in_payload = {in_x, in_y, in_color};
    assign out_payload = payload_q[0 +: PIXEL_W];
    assign out_x = out_payload[(COLOR_W + COORD_W) +: COORD_W];
    assign out_y = out_payload[COLOR_W +: COORD_W];
    assign out_color = out_payload[0 +: COLOR_W];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload_q <= '0;
            count_q <= '0;
        end else if (flush) begin
            payload_q <= '0;
            count_q <= '0;
        end else begin
            if (pop) begin
                for (int i = 0; i < (DEPTH - 1); i++) begin
                    payload_q[(i*PIXEL_W) +: PIXEL_W] <= payload_q[((i + 1)*PIXEL_W) +: PIXEL_W];
                end
                payload_q[((DEPTH - 1)*PIXEL_W) +: PIXEL_W] <= '0;
            end

            if (push) begin
                payload_q[(push_index*PIXEL_W) +: PIXEL_W] <= in_payload;
            end

            case ({push, pop})
                2'b10: count_q <= count_q + COUNT_W'(1);
                2'b01: count_q <= count_q - COUNT_W'(1);
                default: count_q <= count_q;
            endcase
        end
    end
endmodule
