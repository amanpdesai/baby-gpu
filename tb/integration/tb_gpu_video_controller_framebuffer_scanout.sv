import isa_pkg::*;

module tb_gpu_video_controller_framebuffer_scanout;
    `include "tb/common/gpu_core_command_driver.svh"
    `include "tb/common/kernel_program_loader.svh"

    localparam int COORD_W = 4;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int FIFO_DEPTH = 8;
    localparam int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1);
    localparam int IMEM_ADDR_W = 8;
    localparam int GRID_X = 3;
    localparam int GRID_Y = 2;
    localparam logic [31:0] FRAMEBUFFER_BASE = 32'h0000_0040;
    localparam logic [31:0] STRIDE_BYTES = 32'd8;

    logic clk;
    logic reset;
    logic enable;
    logic clear_errors;
    logic cmd_valid;
    logic cmd_ready;
    logic [31:0] cmd_data;
    logic imem_write_en;
    logic [IMEM_ADDR_W-1:0] imem_write_addr;
    logic [ISA_WORD_W-1:0] imem_write_data;
    logic busy;
    logic [7:0] error_status;

    logic tick_enable;
    logic source_select;
    logic [1:0] pattern_select;
    logic [15:0] solid_rgb;
    logic scanout_start_valid;
    logic scanout_start_ready;
    logic fifo_flush;
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

    gpu_video_controller_system #(
        .H_ACTIVE(GRID_X),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(GRID_Y),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_COUNT_W(FIFO_COUNT_W),
        .CHECKER_SHIFT(1),
        .DEPTH_WORDS(64),
        .GPU_FB_WIDTH(4),
        .GPU_FB_HEIGHT(3),
        .GPU_PC_W(IMEM_ADDR_W)
    ) dut (
        .clk(clk),
        .rst_n(!reset),
        .gpu_enable(enable),
        .gpu_clear_errors(clear_errors),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_data(cmd_data),
        .imem_write_en(imem_write_en),
        .imem_write_addr(imem_write_addr),
        .imem_write_data(imem_write_data),
        .gpu_busy(busy),
        .gpu_error_status(error_status),
        .tick_enable(tick_enable),
        .source_select(source_select),
        .pattern_select(pattern_select),
        .solid_rgb(solid_rgb),
        .scanout_start_valid(scanout_start_valid),
        .scanout_start_ready(scanout_start_ready),
        .fb_base(FRAMEBUFFER_BASE),
        .stride_bytes(STRIDE_BYTES),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic load_gradient_program;
        logic [ISA_WORD_W-1:0] kernel_words [0:15];
        begin
            $readmemh("tests/kernels/framebuffer_gradient.memh", kernel_words);
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    function automatic logic [15:0] expected_pixel(input int px, input int py);
        begin
            expected_pixel = 16'(16'h0060 + px + (py * 16));
        end
    endfunction

    task automatic wait_for_video_buffer;
        int timeout;
        begin
            timeout = 0;
            while (!scanout_done && timeout < 200) begin
                step();
                timeout = timeout + 1;
            end
            check(timeout < 200, "video controller scanout fill timed out");
            check(scanout_done, "video controller finished framebuffer fetches");
            check(fifo_count == FIFO_COUNT_W'(GRID_X * GRID_Y), "video fifo holds full GPU frame");
            check(!scanout_error, "video scanout has no memory error");
            check(!fifo_overflow, "video fifo has no overflow while prefetching frame");
        end
    endtask

    task automatic expect_active_pixel(input int px, input int py);
        begin
            #1;
            check(pixel_valid, "video output active pixel valid");
            check(active, "video output active");
            check(x == COORD_W'(px), "video output x matches");
            check(y == COORD_W'(py), "video output y matches");
            check(rgb == expected_pixel(px, py), "video output RGB matches GPU framebuffer");
            check(!source_missing, "video output source present");
            check(!framebuffer_underrun, "video output has no framebuffer underrun");
            check(!framebuffer_coordinate_mismatch, "video output has no coordinate mismatch");
            if (px == 0) begin
                check(line_start, "video output line_start on first pixel");
            end
            if (px == 0 && py == 0) begin
                check(frame_start, "video output frame_start on first pixel");
            end
            step();
        end
    endtask

    task automatic drain_row_porch;
        begin
            repeat (3) begin
                #1;
                check(!pixel_valid, "video output suppresses pixels outside active row");
                step();
            end
        end
    endtask

    task automatic display_gpu_framebuffer;
        begin
            source_select = 1'b1;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "video controller accepts framebuffer scanout start");
            step();
            scanout_start_valid = 1'b0;
            wait_for_video_buffer();

            tick_enable = 1'b1;
            for (int py = 0; py < GRID_Y; py = py + 1) begin
                for (int px = 0; px < GRID_X; px = px + 1) begin
                    expect_active_pixel(px, py);
                end
                if (py + 1 < GRID_Y) begin
                    drain_row_porch();
                end
            end
            tick_enable = 1'b0;

            check(fifo_empty, "video fifo drains after displaying GPU frame");
            check(!fifo_underflow, "video output has no fifo underflow");
            check(!fifo_overflow, "video output has no fifo overflow");
        end
    endtask

    initial begin
        init_command_driver();
        tick_enable = 1'b0;
        source_select = 1'b0;
        pattern_select = 2'd0;
        solid_rgb = 16'h0000;
        scanout_start_valid = 1'b0;
        fifo_flush = 1'b0;

        step();
        reset = 1'b0;
        step();

        load_gradient_program();
        set_reg(KGPU_REG_FB_BASE, FRAMEBUFFER_BASE);
        configure_launch(32'h0000_0000, 32'(GRID_X), 32'(GRID_Y), 32'h0000_0000);
        launch_kernel();
        send_word(KGPU_CMD_WAIT_IDLE);
        wait_idle(400, "gpu video controller framebuffer kernel timed out");

        check(error_status == 8'h00, "GPU framebuffer producer has no errors");
        display_gpu_framebuffer();

        $display("tb_gpu_video_controller_framebuffer_scanout PASS");
        $finish;
    end
endmodule
