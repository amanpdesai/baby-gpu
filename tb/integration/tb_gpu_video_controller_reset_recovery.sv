import isa_pkg::*;

module tb_gpu_video_controller_reset_recovery;
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
        .DEPTH_WORDS(64),
        .GPU_FB_WIDTH(4),
        .GPU_FB_HEIGHT(3),
        .GPU_PC_W(IMEM_ADDR_W)
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
        .fb_base(FRAMEBUFFER_BASE),
        .stride_bytes(STRIDE_BYTES),
        .fifo_flush(fifo_flush),
        .swap_enable(1'b0),
        .swap_request(1'b0),
        .swap_ready(),
        .swap_pending(),
        .swap_pulse(),
        .swap_front_base(),
        .swap_back_base(),
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

    task automatic load_gradient_program;
        logic [31:0] kernel_words [0:255];
        begin
            $readmemh("tests/kernels/framebuffer_gradient.memh", kernel_words);
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    task automatic reset_system;
        begin
            reset = 1'b1;
            memory_req_stall = 1'b0;
            enable = 1'b1;
            clear_errors = 1'b0;
            cmd_valid = 1'b0;
            cmd_data = 32'h0000_0000;
            imem_write_en = 1'b0;
            imem_write_addr = '0;
            imem_write_data = '0;
            tick_enable = 1'b0;
            source_select = 1'b0;
            pattern_select = 1'b0;
            solid_rgb = 16'h0000;
            scanout_start_valid = 1'b0;
            fifo_flush = 1'b0;
            repeat (3) step();

            reset = 1'b0;
            step();
            clear_errors = 1'b1;
            step();
            clear_errors = 1'b0;
            step();

            check(!busy, "GPU is idle after reset");
            check(error_status == 8'h00, "GPU errors clear after reset");
            check(!scanout_busy, "video scanout is idle after reset");
            check(!debug_gpu_mem_req_valid, "GPU memory request is clear after reset");
            check(!debug_video_mem_req_valid, "video memory request is clear after reset");
        end
    endtask

    task automatic wait_for_gpu_request;
        int timeout;
        begin
            timeout = 0;
            while (!debug_gpu_mem_req_valid && timeout < 200) begin
                step();
                timeout = timeout + 1;
            end
            check(debug_gpu_mem_req_valid, "stalled GPU memory request becomes pending");
        end
    endtask

    task automatic wait_for_video_request;
        int timeout;
        begin
            timeout = 0;
            while (!debug_video_mem_req_valid && timeout < 50) begin
                step();
                timeout = timeout + 1;
            end
            check(debug_video_mem_req_valid, "stalled video memory request becomes pending");
        end
    endtask

    task automatic wait_for_gpu_and_video_requests;
        int timeout;
        begin
            timeout = 0;
            while (!(debug_gpu_mem_req_valid && debug_video_mem_req_valid) && timeout < 200) begin
                step();
                timeout = timeout + 1;
            end
            check(debug_gpu_mem_req_valid, "stalled GPU memory request is pending with video");
            check(debug_video_mem_req_valid, "stalled video memory request remains pending with GPU");
        end
    endtask

    task automatic launch_gradient_kernel;
        begin
            load_gradient_program();
            set_reg(KGPU_REG_FB_BASE, FRAMEBUFFER_BASE);
            configure_launch(32'h0000_0000, 32'(GRID_X), 32'(GRID_Y), 32'h0000_0000);
            launch_kernel();
            send_word(KGPU_CMD_WAIT_IDLE);
        end
    endtask

    task automatic run_gradient_kernel;
        begin
            launch_gradient_kernel();
            wait_idle(400, "GPU framebuffer kernel timed out after reset recovery");
            check(error_status == 8'h00, "GPU framebuffer kernel has no error after reset recovery");
        end
    endtask

    task automatic prefetch_framebuffer;
        int timeout;
        begin
            source_select = 1'b1;
            tick_enable = 1'b0;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "video scanout can start after reset recovery");
            step();
            scanout_start_valid = 1'b0;

            timeout = 0;
            while (!scanout_done && timeout < 200) begin
                step();
                timeout = timeout + 1;
            end
            check(scanout_done, "video scanout completes after reset recovery");
            check(fifo_count == FIFO_COUNT_W'(GRID_X * GRID_Y), "video FIFO fills after reset recovery");
            check(!scanout_error, "video scanout has no memory error after reset recovery");
            check(!fifo_overflow, "video FIFO has no overflow after reset recovery");
            check(!framebuffer_underrun, "video framebuffer has no underrun after reset recovery");
        end
    endtask

    task automatic prove_full_recovery;
        begin
            memory_req_stall = 1'b0;
            tick_enable = 1'b0;
            fifo_flush = 1'b1;
            step();
            fifo_flush = 1'b0;
            step();

            run_gradient_kernel();
            prefetch_framebuffer();
        end
    endtask

    task automatic assert_reset_clears_pending_memory;
        begin
            reset = 1'b1;
            step();
            check(!busy, "reset clears GPU busy state");
            check(!scanout_busy, "reset clears video scanout busy state");
            check(!debug_gpu_mem_req_valid, "reset clears pending GPU memory request");
            check(!debug_video_mem_req_valid, "reset clears pending video memory request");
            check(!debug_gpu_mem_req_fire, "reset suppresses GPU memory fire");
            check(!debug_video_mem_req_fire, "reset suppresses video memory fire");
            memory_req_stall = 1'b0;
            scanout_start_valid = 1'b0;
            tick_enable = 1'b0;
            cmd_valid = 1'b0;
            reset = 1'b0;
            step();
            check(error_status == 8'h00, "reset recovery leaves GPU error clear");
        end
    endtask

    task automatic test_reset_during_video_request;
        begin
            reset_system();
            source_select = 1'b1;
            tick_enable = 1'b1;
            memory_req_stall = 1'b1;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "video scanout starts before reset");
            step();
            scanout_start_valid = 1'b0;
            wait_for_video_request();

            assert_reset_clears_pending_memory();
            prove_full_recovery();
        end
    endtask

    task automatic test_reset_during_gpu_request;
        begin
            reset_system();
            memory_req_stall = 1'b1;
            launch_gradient_kernel();
            wait_for_gpu_request();

            assert_reset_clears_pending_memory();
            prove_full_recovery();
        end
    endtask

    task automatic test_reset_during_concurrent_requests;
        begin
            reset_system();
            source_select = 1'b1;
            tick_enable = 1'b1;
            memory_req_stall = 1'b1;
            scanout_start_valid = 1'b1;
            check(scanout_start_ready, "video scanout starts before concurrent reset");
            step();
            scanout_start_valid = 1'b0;
            wait_for_video_request();

            launch_gradient_kernel();
            wait_for_gpu_and_video_requests();

            assert_reset_clears_pending_memory();
            prove_full_recovery();
        end
    endtask

    initial begin
        test_reset_during_video_request();
        test_reset_during_gpu_request();
        test_reset_during_concurrent_requests();

        $display("tb_gpu_video_controller_reset_recovery PASS");
        $finish;
    end
endmodule
