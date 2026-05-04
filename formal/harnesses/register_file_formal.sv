module register_file_formal (
    input logic clk
);
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 16;
    localparam int FB_WIDTH_DEFAULT = 160;
    localparam int FB_HEIGHT_DEFAULT = 120;

    localparam logic [ADDR_W-1:0] ADDR_GPU_ID = 32'h0000_0000;
    localparam logic [ADDR_W-1:0] ADDR_GPU_VERSION = 32'h0000_0004;
    localparam logic [ADDR_W-1:0] ADDR_STATUS = 32'h0000_0008;
    localparam logic [ADDR_W-1:0] ADDR_CONTROL = 32'h0000_000C;
    localparam logic [ADDR_W-1:0] ADDR_FB_BASE = 32'h0000_0010;
    localparam logic [ADDR_W-1:0] ADDR_FB_WIDTH = 32'h0000_0014;
    localparam logic [ADDR_W-1:0] ADDR_FB_HEIGHT = 32'h0000_0018;
    localparam logic [ADDR_W-1:0] ADDR_FB_FORMAT = 32'h0000_001C;
    localparam logic [ADDR_W-1:0] ADDR_INTERRUPT_STATUS = 32'h0000_0024;
    localparam logic [ADDR_W-1:0] ADDR_INTERRUPT_ENABLE = 32'h0000_0028;
    localparam logic [ADDR_W-1:0] ADDR_BUSY = 32'h0000_002C;
    localparam logic [ADDR_W-1:0] ADDR_PROGRAM_BASE = 32'h0000_0040;
    localparam logic [ADDR_W-1:0] ADDR_GRID_X = 32'h0000_0044;
    localparam logic [ADDR_W-1:0] ADDR_GRID_Y = 32'h0000_0048;
    localparam logic [ADDR_W-1:0] ADDR_GROUP_SIZE_X = 32'h0000_004C;
    localparam logic [ADDR_W-1:0] ADDR_GROUP_SIZE_Y = 32'h0000_0050;
    localparam logic [ADDR_W-1:0] ADDR_ARG_BASE = 32'h0000_0054;
    localparam logic [ADDR_W-1:0] ADDR_LAUNCH_FLAGS = 32'h0000_0058;
    localparam logic [DATA_W-1:0] GPU_ID = 32'h4250_4755;
    localparam logic [DATA_W-1:0] GPU_VERSION = 32'h0001_0000;
    localparam logic [1:0] FB_FORMAT_RGB565 = 2'd1;

    (* anyseq *) logic reset;
    (* anyseq *) logic write_valid;
    (* anyseq *) logic [ADDR_W-1:0] write_addr;
    (* anyseq *) logic [DATA_W-1:0] write_data;
    (* anyseq *) logic read_valid;
    (* anyseq *) logic [ADDR_W-1:0] read_addr;
    logic [DATA_W-1:0] read_data;
    (* anyseq *) logic status_busy;
    (* anyseq *) logic [7:0] status_errors;
    logic core_enable;
    logic soft_reset_pulse;
    logic clear_errors_pulse;
    logic test_pattern_enable;
    logic [ADDR_W-1:0] fb_base;
    logic [COORD_W-1:0] fb_width;
    logic [COORD_W-1:0] fb_height;
    logic [1:0] fb_format;
    logic [ADDR_W-1:0] launch_program_base;
    logic [COORD_W-1:0] launch_grid_x;
    logic [COORD_W-1:0] launch_grid_y;
    logic [COORD_W-1:0] launch_group_size_x;
    logic [COORD_W-1:0] launch_group_size_y;
    logic [ADDR_W-1:0] launch_arg_base;
    logic [DATA_W-1:0] launch_flags;
    logic [DATA_W-1:0] expected_control_reg;
    logic [DATA_W-1:0] expected_interrupt_status_reg;
    logic [DATA_W-1:0] expected_interrupt_enable_reg;
    logic past_valid;

    register_file #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .FB_WIDTH_DEFAULT(FB_WIDTH_DEFAULT),
        .FB_HEIGHT_DEFAULT(FB_HEIGHT_DEFAULT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .write_valid(write_valid),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_valid(read_valid),
        .read_addr(read_addr),
        .read_data(read_data),
        .status_busy(status_busy),
        .status_errors(status_errors),
        .core_enable(core_enable),
        .soft_reset_pulse(soft_reset_pulse),
        .clear_errors_pulse(clear_errors_pulse),
        .test_pattern_enable(test_pattern_enable),
        .fb_base(fb_base),
        .fb_width(fb_width),
        .fb_height(fb_height),
        .fb_format(fb_format),
        .launch_program_base(launch_program_base),
        .launch_grid_x(launch_grid_x),
        .launch_grid_y(launch_grid_y),
        .launch_group_size_x(launch_group_size_x),
        .launch_group_size_y(launch_group_size_y),
        .launch_arg_base(launch_arg_base),
        .launch_flags(launch_flags)
    );

    initial begin
        past_valid = 1'b0;
        expected_control_reg = '0;
        expected_interrupt_status_reg = '0;
        expected_interrupt_enable_reg = '0;
        assume(reset);
    end

    always_comb begin
        if (!read_valid) begin
            assert(read_data == '0);
        end

        if (read_valid && read_addr == ADDR_GPU_ID) begin
            assert(read_data == GPU_ID);
        end

        if (read_valid && read_addr == ADDR_GPU_VERSION) begin
            assert(read_data == GPU_VERSION);
        end

        if (read_valid && read_addr == ADDR_STATUS) begin
            assert(read_data == {23'd0, status_errors, status_busy});
        end

        if (past_valid && read_valid && read_addr == ADDR_CONTROL) begin
            assert(read_data == expected_control_reg);
            assert(read_data[0] == core_enable);
            assert(read_data[4] == test_pattern_enable);
        end

        if (read_valid && read_addr == ADDR_BUSY) begin
            assert(read_data == {31'd0, status_busy});
        end

        if (read_valid && read_addr == ADDR_FB_BASE) begin
            assert(read_data == fb_base);
        end

        if (read_valid && read_addr == ADDR_FB_WIDTH) begin
            assert(read_data == {16'd0, fb_width});
        end

        if (read_valid && read_addr == ADDR_FB_HEIGHT) begin
            assert(read_data == {16'd0, fb_height});
        end

        if (read_valid && read_addr == ADDR_FB_FORMAT) begin
            assert(read_data == {30'd0, fb_format});
        end

        if (past_valid && read_valid && read_addr == ADDR_INTERRUPT_STATUS) begin
            assert(read_data == expected_interrupt_status_reg);
        end

        if (past_valid && read_valid && read_addr == ADDR_INTERRUPT_ENABLE) begin
            assert(read_data == expected_interrupt_enable_reg);
        end

        if (past_valid && read_valid && read_addr == ADDR_PROGRAM_BASE) begin
            assert(read_data == DATA_W'(launch_program_base));
        end

        if (past_valid && read_valid && read_addr == ADDR_GRID_X) begin
            assert(read_data == {16'd0, launch_grid_x});
        end

        if (past_valid && read_valid && read_addr == ADDR_GRID_Y) begin
            assert(read_data == {16'd0, launch_grid_y});
        end

        if (past_valid && read_valid && read_addr == ADDR_GROUP_SIZE_X) begin
            assert(read_data == {16'd0, launch_group_size_x});
        end

        if (past_valid && read_valid && read_addr == ADDR_GROUP_SIZE_Y) begin
            assert(read_data == {16'd0, launch_group_size_y});
        end

        if (past_valid && read_valid && read_addr == ADDR_ARG_BASE) begin
            assert(read_data == DATA_W'(launch_arg_base));
        end

        if (past_valid && read_valid && read_addr == ADDR_LAUNCH_FLAGS) begin
            assert(read_data == launch_flags);
        end

        if (read_valid
                && read_addr != ADDR_GPU_ID
                && read_addr != ADDR_GPU_VERSION
                && read_addr != ADDR_STATUS
                && read_addr != ADDR_CONTROL
                && read_addr != ADDR_FB_BASE
                && read_addr != ADDR_FB_WIDTH
                && read_addr != ADDR_FB_HEIGHT
                && read_addr != ADDR_FB_FORMAT
                && read_addr != ADDR_INTERRUPT_STATUS
                && read_addr != ADDR_INTERRUPT_ENABLE
                && read_addr != ADDR_BUSY
                && read_addr != ADDR_PROGRAM_BASE
                && read_addr != ADDR_GRID_X
                && read_addr != ADDR_GRID_Y
                && read_addr != ADDR_GROUP_SIZE_X
                && read_addr != ADDR_GROUP_SIZE_Y
                && read_addr != ADDR_ARG_BASE
                && read_addr != ADDR_LAUNCH_FLAGS) begin
            assert(read_data == '0);
        end
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;

        if (reset) begin
            expected_control_reg <= '0;
            expected_interrupt_status_reg <= '0;
            expected_interrupt_enable_reg <= '0;
        end else if (write_valid) begin
            case (write_addr)
                ADDR_CONTROL: begin
                    expected_control_reg[0] <= write_data[0];
                    expected_control_reg[3] <= write_data[3];
                    expected_control_reg[4] <= write_data[4];
                end
                ADDR_INTERRUPT_STATUS: begin
                    expected_interrupt_status_reg <= expected_interrupt_status_reg & ~write_data;
                end
                ADDR_INTERRUPT_ENABLE: begin
                    expected_interrupt_enable_reg <= write_data;
                end
                default: begin
                end
            endcase
        end

        if (!past_valid) begin
            assume(reset);
        end else if ($past(reset)) begin
            assert(!core_enable);
            assert(!test_pattern_enable);
            assert(!soft_reset_pulse);
            assert(!clear_errors_pulse);
            assert(expected_control_reg == '0);
            assert(expected_interrupt_status_reg == '0);
            assert(expected_interrupt_enable_reg == '0);
            assert(fb_base == '0);
            assert(fb_width == COORD_W'(FB_WIDTH_DEFAULT));
            assert(fb_height == COORD_W'(FB_HEIGHT_DEFAULT));
            assert(fb_format == FB_FORMAT_RGB565);
            assert(launch_program_base == '0);
            assert(launch_grid_x == '0);
            assert(launch_grid_y == '0);
            assert(launch_group_size_x == COORD_W'(4));
            assert(launch_group_size_y == COORD_W'(1));
            assert(launch_arg_base == '0);
            assert(launch_flags == '0);
        end else if ($past(write_valid && write_addr == ADDR_CONTROL)) begin
            assert(core_enable == $past(write_data[0]));
            assert(soft_reset_pulse == $past(write_data[1]));
            assert(clear_errors_pulse == $past(write_data[2]));
            assert(test_pattern_enable == $past(write_data[4]));
        end else begin
            assert(!soft_reset_pulse);
            assert(!clear_errors_pulse);
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_BASE)) begin
            assert(fb_base == $past(write_data));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_WIDTH)
                && $past(write_data[COORD_W-1:0] != '0)) begin
            assert(fb_width == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_WIDTH)
                && $past(write_data[COORD_W-1:0] == '0)) begin
            assert(fb_width == $past(fb_width));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_HEIGHT)
                && $past(write_data[COORD_W-1:0] != '0)) begin
            assert(fb_height == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_HEIGHT)
                && $past(write_data[COORD_W-1:0] == '0)) begin
            assert(fb_height == $past(fb_height));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_FORMAT)
                && $past(write_data[1:0] == FB_FORMAT_RGB565)) begin
            assert(fb_format == FB_FORMAT_RGB565);
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_FORMAT)
                && $past(write_data[1:0] != FB_FORMAT_RGB565)) begin
            assert(fb_format == $past(fb_format));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_PROGRAM_BASE)) begin
            assert(launch_program_base == ADDR_W'($past(write_data)));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GRID_X)) begin
            assert(launch_grid_x == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GRID_Y)) begin
            assert(launch_grid_y == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GROUP_SIZE_X)
                && $past(write_data[COORD_W-1:0] != '0)) begin
            assert(launch_group_size_x == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GROUP_SIZE_X)
                && $past(write_data[COORD_W-1:0] == '0)) begin
            assert(launch_group_size_x == $past(launch_group_size_x));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GROUP_SIZE_Y)
                && $past(write_data[COORD_W-1:0] != '0)) begin
            assert(launch_group_size_y == $past(write_data[COORD_W-1:0]));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_GROUP_SIZE_Y)
                && $past(write_data[COORD_W-1:0] == '0)) begin
            assert(launch_group_size_y == $past(launch_group_size_y));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_ARG_BASE)) begin
            assert(launch_arg_base == ADDR_W'($past(write_data)));
        end

        if (past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_LAUNCH_FLAGS)) begin
            assert(launch_flags == $past(write_data));
        end

        cover(past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_CONTROL)
            && soft_reset_pulse && clear_errors_pulse && core_enable && test_pattern_enable);
        cover(past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_BASE)
            && fb_base == 32'h0000_4000);
        cover(past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_WIDTH)
            && $past(write_data[COORD_W-1:0] == '0));
        cover(past_valid && !$past(reset) && $past(write_valid && write_addr == ADDR_FB_FORMAT)
            && $past(write_data[1:0] != FB_FORMAT_RGB565));
    end
endmodule
