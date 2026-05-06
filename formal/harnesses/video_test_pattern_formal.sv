module video_test_pattern_formal;
    localparam int COORD_W = 6;
    localparam int H_ACTIVE = 8;
    localparam int CHECKER_SHIFT = 1;

    localparam logic [1:0] PATTERN_SOLID = 2'd0;
    localparam logic [1:0] PATTERN_BARS = 2'd1;
    localparam logic [1:0] PATTERN_CHECKER = 2'd2;
    localparam logic [1:0] PATTERN_GRADIENT = 2'd3;

    logic pixel_valid;
    logic active;
    logic [1:0] pattern_select;
    logic [15:0] solid_rgb;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic [COORD_W-1:0] xy_xor;
    logic rgb_valid;
    logic [15:0] rgb;

    video_test_pattern #(
        .COORD_W(COORD_W),
        .H_ACTIVE(H_ACTIVE),
        .CHECKER_SHIFT(CHECKER_SHIFT)
    ) dut (
        .pixel_valid(pixel_valid),
        .active(active),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .x(x),
        .y(y),
        .rgb_valid(rgb_valid),
        .rgb(rgb)
    );

    function automatic logic [15:0] expected_bar(input logic [COORD_W-1:0] xpos);
        begin
            if (xpos == COORD_W'(0)) begin
                expected_bar = 16'hFFFF;
            end else if (xpos == COORD_W'(1)) begin
                expected_bar = 16'hFFE0;
            end else if (xpos == COORD_W'(2)) begin
                expected_bar = 16'h07FF;
            end else if (xpos == COORD_W'(3)) begin
                expected_bar = 16'h07E0;
            end else if (xpos == COORD_W'(4)) begin
                expected_bar = 16'hF81F;
            end else if (xpos == COORD_W'(5)) begin
                expected_bar = 16'hF800;
            end else if (xpos == COORD_W'(6)) begin
                expected_bar = 16'h001F;
            end else begin
                expected_bar = 16'h0000;
            end
        end
    endfunction

    always_comb begin
        xy_xor = x ^ y;
        assert(rgb_valid == pixel_valid);

        if (!active) begin
            assert(rgb == 16'h0000);
        end

        if (active && pattern_select == PATTERN_SOLID) begin
            assert(rgb == solid_rgb);
        end

        if (active && pattern_select == PATTERN_BARS) begin
            assert(rgb == expected_bar(x));
        end

        if (active && pattern_select == PATTERN_CHECKER) begin
            assert(rgb == ((x[CHECKER_SHIFT] ^ y[CHECKER_SHIFT]) ? 16'hFFFF : 16'h0000));
        end

        if (active && pattern_select == PATTERN_GRADIENT) begin
            assert(rgb == {x[4:0], y[5:0], xy_xor[4:0]});
        end

        cover(active && pixel_valid && pattern_select == PATTERN_SOLID && rgb == solid_rgb);
        cover(active && pixel_valid && pattern_select == PATTERN_BARS && x == COORD_W'(6)
            && rgb == 16'h001F);
        cover(active && pixel_valid && pattern_select == PATTERN_CHECKER && rgb == 16'hFFFF);
        cover(active && pixel_valid && pattern_select == PATTERN_GRADIENT && rgb != 16'h0000);
        cover(!active && pixel_valid && rgb == 16'h0000);
    end
endmodule
