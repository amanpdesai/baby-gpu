module video_test_pattern #(
    parameter int COORD_W = 12,
    parameter int H_ACTIVE = 640,
    parameter int CHECKER_SHIFT = 4
) (
    input logic pixel_valid,
    input logic active,
    input logic [1:0] pattern_select,
    input logic [15:0] solid_rgb,
    input logic [COORD_W-1:0] x,
    input logic [COORD_W-1:0] y,

    output logic rgb_valid,
    output logic [15:0] rgb
);
    localparam logic [1:0] PATTERN_SOLID = 2'd0;
    localparam logic [1:0] PATTERN_BARS = 2'd1;
    localparam logic [1:0] PATTERN_CHECKER = 2'd2;
    localparam logic [1:0] PATTERN_GRADIENT = 2'd3;

    localparam int BAR_COUNT = 8;
    localparam int BAR_W = (H_ACTIVE + BAR_COUNT - 1) / BAR_COUNT;

    initial begin
        if (COORD_W < 1) begin
            $fatal(1, "video_test_pattern requires COORD_W >= 1");
        end
        if (H_ACTIVE < 1) begin
            $fatal(1, "video_test_pattern requires H_ACTIVE >= 1");
        end
        if (CHECKER_SHIFT < 0 || CHECKER_SHIFT >= COORD_W) begin
            $fatal(1, "video_test_pattern CHECKER_SHIFT must select a valid coordinate bit");
        end
        if (COORD_W < 32 && 64'(H_ACTIVE) > (64'd1 << COORD_W)) begin
            $fatal(1, "video_test_pattern H_ACTIVE exceeds COORD_W");
        end
    end

    function automatic logic [4:0] low5(input logic [COORD_W-1:0] value);
        begin
            low5 = '0;
            for (int i = 0; i < 5; i++) begin
                if (i < COORD_W) begin
                    low5[i] = value[i];
                end
            end
        end
    endfunction

    function automatic logic [5:0] low6(input logic [COORD_W-1:0] value);
        begin
            low6 = '0;
            for (int i = 0; i < 6; i++) begin
                if (i < COORD_W) begin
                    low6[i] = value[i];
                end
            end
        end
    endfunction

    function automatic logic [15:0] color_bar(input logic [COORD_W-1:0] xpos);
        begin
            if (xpos < COORD_W'(BAR_W)) begin
                color_bar = 16'hFFFF;
            end else if (xpos < COORD_W'(BAR_W * 2)) begin
                color_bar = 16'hFFE0;
            end else if (xpos < COORD_W'(BAR_W * 3)) begin
                color_bar = 16'h07FF;
            end else if (xpos < COORD_W'(BAR_W * 4)) begin
                color_bar = 16'h07E0;
            end else if (xpos < COORD_W'(BAR_W * 5)) begin
                color_bar = 16'hF81F;
            end else if (xpos < COORD_W'(BAR_W * 6)) begin
                color_bar = 16'hF800;
            end else if (xpos < COORD_W'(BAR_W * 7)) begin
                color_bar = 16'h001F;
            end else begin
                color_bar = 16'h0000;
            end
        end
    endfunction

    always_comb begin
        rgb_valid = pixel_valid;
        rgb = 16'h0000;

        if (active) begin
            case (pattern_select)
                PATTERN_SOLID: begin
                    rgb = solid_rgb;
                end
                PATTERN_BARS: begin
                    rgb = color_bar(x);
                end
                PATTERN_CHECKER: begin
                    rgb = (x[CHECKER_SHIFT] ^ y[CHECKER_SHIFT]) ? 16'hFFFF : 16'h0000;
                end
                PATTERN_GRADIENT: begin
                    rgb = {low5(x), low6(y), low5(x ^ y)};
                end
                default: begin
                    rgb = 16'h0000;
                end
            endcase
        end
    end
endmodule
