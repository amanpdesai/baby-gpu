import isa_pkg::*;

module tb_gpu_video_controller_double_buffer;
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
    localparam logic [31:0] FRONT_BASE = 32'h0000_0040;
    localparam logic [31:0] BACK_BASE = 32'h0000_0080;
    localparam logic [31:0] STRIDE_BYTES = 32'd8;

    logic clk;
    logic reset;
    logic memory_req_stall;
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
    logic swap_request;
    logic swap_ready;
    logic swap_pending;
    logic swap_pulse;
    logic [ADDR_W-1:0] swap_front_base;
    logic [ADDR_W-1:0] swap_back_base;
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
    logic debug_gpu_mem_req_valid;
    logic debug_video_mem_req_valid;
    logic debug_gpu_mem_req_fire;
    logic debug_video_mem_req_fire;

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
        .DEPTH_WORDS(128),
        .GPU_FB_WIDTH(4),
        .GPU_FB_HEIGHT(3),
        .GPU_PC_W(IMEM_ADDR_W),
        .FRONT_BASE_RESET(FRONT_BASE),
        .BACK_BASE_RESET(BACK_BASE)
    ) dut (
        .clk(clk),
        .rst_n(!reset),
        .memory_req_stall(memory_req_stall),
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
        .fb_base(FRONT_BASE),
        .stride_bytes(STRIDE_BYTES),
        .fifo_flush(fifo_flush),
        .swap_enable(1'b1),
        .swap_request(swap_request),
        .swap_ready(swap_ready),
        .swap_pending(swap_pending),
        .swap_pulse(swap_pulse),
        .swap_front_base(swap_front_base),
        .swap_back_base(swap_back_base),
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
        .rgb(rgb),
        .debug_gpu_mem_req_valid(debug_gpu_mem_req_valid),
        .debug_video_mem_req_valid(debug_video_mem_req_valid),
        .debug_gpu_mem_req_fire(debug_gpu_mem_req_fire),
        .debug_video_mem_req_fire(debug_video_mem_req_fire)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [15:0] gradient_pixel(input int px, input int py);
        begin
            gradient_pixel = 16'(16'h0060 + px + (py * 16));
        end
    endfunction

    task automatic load_gradient_program;
        logic [ISA_WORD_W-1:0] kernel_words [0:15];
        begin
            $readmemh("tests/kernels/framebuffer_gradient.memh", kernel_words);
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    task automatic load_bounded_fill_program;
        logic [ISA_WORD_W-1:0] kernel_words [0:31];
        begin
            $readmemh("tests/kernels/bounded_fill_3x2_04d2.memh", kernel_words);
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    task automatic reset_system;
        begin
            init_command_driver();
            tick_enable = 1'b0;
            source_select = 1'b0;
            pattern_select = 2'd0;
            solid_rgb = 16'h0000;
            scanout_start_valid = 1'b0;
            fifo_flush = 1'b0;
            swap_request = 1'b0;
            memory_req_stall = 1'b0;

            step();
            reset = 1'b0;
            step();

            check(swap_front_base == FRONT_BASE, "swap front base resets to front buffer");
            check(swap_back_base == BACK_BASE, "swap back base resets to back buffer");
            check(swap_ready, "swap controller ready after reset");
            check(!swap_pending, "swap controller has no pending request after reset");
        end
    endtask

    task automatic flush_video_fifo;
        begin
            fifo_flush = 1'b1;
            step();
            fifo_flush = 1'b0;
            step();
            check(fifo_empty, "video FIFO flush leaves FIFO empty");
        end
    endtask

    task automatic park_video_in_blanking;
        int timeout;
        int active_pixels;
        begin
            tick_enable = 1'b1;
            timeout = 0;
            while (!(pixel_valid && active && frame_start) && timeout < 160) begin
                step();
                timeout = timeout + 1;
            end
            check(timeout < 160, "video timing reaches frame start before prefetch");

            active_pixels = 0;
            while (active_pixels < (GRID_X * GRID_Y) && timeout < 240) begin
                if (pixel_valid && active) begin
                    active_pixels = active_pixels + 1;
                end
                step();
                timeout = timeout + 1;
            end
            check(active_pixels == (GRID_X * GRID_Y), "video timing drains active frame before prefetch");
            tick_enable = 1'b0;
            step();
            check(!(pixel_valid && active), "video timing is parked outside active pixels");
        end
    endtask

    task automatic run_kernel_to_back_buffer(input bit bounded_fill);
        begin
            if (bounded_fill) begin
                load_bounded_fill_program();
            end else begin
                load_gradient_program();
            end

            set_reg(KGPU_REG_FB_BASE, swap_back_base);
            configure_launch(32'h0000_0000, 32'(GRID_X), 32'(GRID_Y), 32'h0000_0000);
            launch_kernel();
            send_word(KGPU_CMD_WAIT_IDLE);
            wait_idle(400, "back-buffer kernel timed out");
            check(error_status == 8'h00, "back-buffer kernel has no GPU error");
        end
    endtask

    task automatic request_swap_at_frame_boundary;
        logic [ADDR_W-1:0] old_front;
        logic [ADDR_W-1:0] old_back;
        int timeout;
        bit observed_frame_start;
        begin
            old_front = swap_front_base;
            old_back = swap_back_base;
            tick_enable = 1'b0;
            check(swap_ready, "swap request starts when ready");
            swap_request = 1'b1;
            step();
            swap_request = 1'b0;
            check(swap_pending, "swap request remains pending while video timing is stopped");
            check(!swap_pulse, "swap does not commit before a frame boundary");
            check(swap_front_base == old_front, "front base holds before frame-boundary swap");
            check(swap_back_base == old_back, "back base holds before frame-boundary swap");

            tick_enable = 1'b1;
            timeout = 0;
            observed_frame_start = 1'b0;
            while (!swap_pulse && timeout < 80) begin
                @(negedge clk);
                #1;
                if (frame_start) begin
                    observed_frame_start = 1'b1;
                end
                @(posedge clk);
                #1;
                if (frame_start) begin
                    observed_frame_start = 1'b1;
                end
                timeout = timeout + 1;
            end
            if (frame_start) begin
                observed_frame_start = 1'b1;
            end
            check(observed_frame_start, "swap commit waits for observed video frame boundary");
            check(swap_pulse, "swap commits at a video frame boundary");
            check(swap_front_base == old_back, "swap commit exposes old back buffer");
            check(swap_back_base == old_front, "swap commit moves old front to back buffer");
        end
    endtask

    task automatic wait_for_video_buffer;
        int timeout;
        begin
            timeout = 0;
            while (!scanout_done && timeout < 200) begin
                step();
                timeout = timeout + 1;
            end
            check(scanout_done, "video controller finishes framebuffer fetches");
            check(fifo_count == FIFO_COUNT_W'(GRID_X * GRID_Y), "video FIFO holds full displayed frame");
            check(!scanout_error, "video scanout has no memory error");
            check(!fifo_overflow, "video FIFO has no prefetch overflow");
        end
    endtask

    task automatic expect_active_pixel(input int px, input int py, input logic [15:0] expected_rgb);
        begin
            #1;
            check(pixel_valid, "video output active pixel valid");
            check(active, "video output active");
            check(x == COORD_W'(px), "video output x matches");
            check(y == COORD_W'(py), "video output y matches");
            check(!source_missing,
                  $sformatf("video output source present before RGB check px=%0d py=%0d underrun=%0b mismatch=%0b",
                            px, py,
                            framebuffer_underrun, framebuffer_coordinate_mismatch));
            check(!framebuffer_underrun, "video output has no framebuffer underrun before RGB check");
            check(!framebuffer_coordinate_mismatch, "video output has no coordinate mismatch before RGB check");
            check(rgb == expected_rgb,
                  $sformatf("video output RGB matches swapped front buffer px=%0d py=%0d rgb=%04h expected=%04h missing=%0b underrun=%0b mismatch=%0b",
                            px, py, rgb, expected_rgb, source_missing,
                            framebuffer_underrun, framebuffer_coordinate_mismatch));
            step();
        end
    endtask

    task automatic display_front_buffer(input bit bounded_fill);
        int align_timeout;
        logic [15:0] expected_rgb;
        begin
            park_video_in_blanking();
            flush_video_fifo();
            source_select = 1'b1;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "video accepts swapped front-buffer scanout");
            step();
            scanout_start_valid = 1'b0;
            wait_for_video_buffer();

            tick_enable = 1'b1;
            align_timeout = 0;
            #1;
            while (!(pixel_valid && active && x == '0 && y == '0) && align_timeout < 80) begin
                step();
                align_timeout = align_timeout + 1;
            end
            check(align_timeout < 80, "video output reaches frame origin");

            for (int py = 0; py < GRID_Y; py = py + 1) begin
                for (int px = 0; px < GRID_X; px = px + 1) begin
                    expected_rgb = bounded_fill ? 16'h04d2 : gradient_pixel(px, py);
                    expect_active_pixel(px, py, expected_rgb);
                end
                if (py + 1 < GRID_Y) begin
                    repeat (3) step();
                end
            end
            check(!fifo_underflow, "video output has no FIFO underflow");
        end
    endtask

    initial begin
        reset_system();

        run_kernel_to_back_buffer(1'b0);
        request_swap_at_frame_boundary();
        display_front_buffer(1'b0);

        run_kernel_to_back_buffer(1'b1);
        request_swap_at_frame_boundary();
        display_front_buffer(1'b1);

        $display("tb_gpu_video_controller_double_buffer PASS");
        $finish;
    end
endmodule
