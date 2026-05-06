import isa_pkg::*;

module tb_gpu_core_command_framebuffer_scanout;
    `include "tb/common/gpu_core_command_driver.svh"
    `include "tb/common/kernel_program_loader.svh"

    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int MASK_W = DATA_W / 8;
    localparam int COORD_W = 8;
    localparam int COLOR_W = 16;
    localparam int MEM_ID_W = 2;
    localparam int MEM_WORDS = 64;
    localparam int IMEM_ADDR_W = 8;
    localparam int GRID_X = 3;
    localparam int GRID_Y = 2;
    localparam logic [31:0] FRAMEBUFFER_BASE = 32'h0000_0040;
    localparam logic [31:0] STRIDE_BYTES = 32'd8;
    localparam logic OWNER_GPU = 1'b0;
    localparam logic OWNER_SCANOUT = 1'b1;

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

    logic gpu_mem_req_valid;
    logic gpu_mem_req_ready;
    logic gpu_mem_req_write;
    logic [31:0] gpu_mem_req_addr;
    logic [31:0] gpu_mem_req_wdata;
    logic [MASK_W-1:0] gpu_mem_req_wmask;
    logic [MEM_ID_W-1:0] gpu_mem_req_id;
    logic gpu_mem_rsp_valid;
    logic gpu_mem_rsp_ready;
    logic [31:0] gpu_mem_rsp_rdata;
    logic [MEM_ID_W-1:0] gpu_mem_rsp_id;

    logic scan_start_valid;
    logic scan_start_ready;
    logic scan_busy;
    logic scan_done;
    logic scan_error;
    logic scan_pixel_valid;
    logic scan_pixel_ready;
    logic [COORD_W-1:0] scan_pixel_x;
    logic [COORD_W-1:0] scan_pixel_y;
    logic [COLOR_W-1:0] scan_pixel_color;
    logic scan_mem_req_valid;
    logic scan_mem_req_ready;
    logic scan_mem_req_write;
    logic [31:0] scan_mem_req_addr;
    logic [31:0] scan_mem_req_wdata;
    logic [MASK_W-1:0] scan_mem_req_wmask;
    logic scan_mem_req_id;
    logic scan_mem_rsp_valid;
    logic scan_mem_rsp_ready;
    logic [31:0] scan_mem_rsp_rdata;
    logic scan_mem_rsp_id;
    logic scan_mem_rsp_error;

    logic memory_owner;
    logic data_req_valid;
    logic data_req_ready;
    logic data_req_write;
    logic [ADDR_W-1:0] data_req_addr;
    logic [DATA_W-1:0] data_req_wdata;
    logic [MASK_W-1:0] data_req_wmask;
    logic data_rsp_valid;
    logic data_rsp_ready;
    logic [DATA_W-1:0] data_rsp_rdata;
    logic data_rsp_error;
    logic [MEM_ID_W-1:0] pending_gpu_rsp_id;
    logic pending_scan_rsp_id;
    logic saw_gpu_mem_req;
    int scan_pixels;

    gpu_core #(
        .FB_WIDTH(4),
        .FB_HEIGHT(3),
        .FIFO_DEPTH(16),
        .ADDR_W(32),
        .DATA_W(DATA_W),
        .COORD_W(16),
        .MEM_ID_W(MEM_ID_W)
    ) gpu (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .clear_errors(clear_errors),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_data(cmd_data),
        .imem_write_en(imem_write_en),
        .imem_write_addr(imem_write_addr),
        .imem_write_data(imem_write_data),
        .busy(busy),
        .error_status(error_status),
        .mem_req_valid(gpu_mem_req_valid),
        .mem_req_ready(gpu_mem_req_ready),
        .mem_req_write(gpu_mem_req_write),
        .mem_req_addr(gpu_mem_req_addr),
        .mem_req_wdata(gpu_mem_req_wdata),
        .mem_req_wmask(gpu_mem_req_wmask),
        .mem_req_id(gpu_mem_req_id),
        .mem_rsp_valid(gpu_mem_rsp_valid),
        .mem_rsp_ready(gpu_mem_rsp_ready),
        .mem_rsp_rdata(gpu_mem_rsp_rdata),
        .mem_rsp_id(gpu_mem_rsp_id)
    );

    framebuffer_scanout #(
        .FRAME_WIDTH(GRID_X),
        .FRAME_HEIGHT(GRID_Y),
        .ADDR_W(32),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .LOCAL_ID_W(1)
    ) scanout (
        .clk(clk),
        .rst_n(!reset),
        .start_valid(scan_start_valid),
        .start_ready(scan_start_ready),
        .fb_base(FRAMEBUFFER_BASE),
        .stride_bytes(STRIDE_BYTES),
        .busy(scan_busy),
        .done(scan_done),
        .error(scan_error),
        .pixel_valid(scan_pixel_valid),
        .pixel_ready(scan_pixel_ready),
        .pixel_x(scan_pixel_x),
        .pixel_y(scan_pixel_y),
        .pixel_color(scan_pixel_color),
        .mem_req_valid(scan_mem_req_valid),
        .mem_req_ready(scan_mem_req_ready),
        .mem_req_write(scan_mem_req_write),
        .mem_req_addr(scan_mem_req_addr),
        .mem_req_wdata(scan_mem_req_wdata),
        .mem_req_wmask(scan_mem_req_wmask),
        .mem_req_id(scan_mem_req_id),
        .mem_rsp_valid(scan_mem_rsp_valid),
        .mem_rsp_ready(scan_mem_rsp_ready),
        .mem_rsp_rdata(scan_mem_rsp_rdata),
        .mem_rsp_id(scan_mem_rsp_id),
        .mem_rsp_error(scan_mem_rsp_error)
    );

    data_memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH_WORDS(MEM_WORDS)
    ) memory (
        .clk(clk),
        .reset(reset),
        .req_valid(data_req_valid),
        .req_ready(data_req_ready),
        .req_write(data_req_write),
        .req_addr(data_req_addr),
        .req_wdata(data_req_wdata),
        .req_wmask(data_req_wmask),
        .rsp_valid(data_rsp_valid),
        .rsp_ready(data_rsp_ready),
        .rsp_rdata(data_rsp_rdata),
        .error(data_rsp_error)
    );

    assign data_req_valid = (memory_owner == OWNER_GPU) ? gpu_mem_req_valid : scan_mem_req_valid;
    assign data_req_write = (memory_owner == OWNER_GPU) ? gpu_mem_req_write : scan_mem_req_write;
    assign data_req_addr = (memory_owner == OWNER_GPU) ? gpu_mem_req_addr[ADDR_W-1:0] :
        scan_mem_req_addr[ADDR_W-1:0];
    assign data_req_wdata = (memory_owner == OWNER_GPU) ? gpu_mem_req_wdata : scan_mem_req_wdata;
    assign data_req_wmask = (memory_owner == OWNER_GPU) ? gpu_mem_req_wmask : scan_mem_req_wmask;
    assign data_rsp_ready = (memory_owner == OWNER_GPU) ? gpu_mem_rsp_ready : scan_mem_rsp_ready;

    assign gpu_mem_req_ready = (memory_owner == OWNER_GPU) && data_req_ready;
    assign gpu_mem_rsp_valid = (memory_owner == OWNER_GPU) && data_rsp_valid;
    assign gpu_mem_rsp_rdata = data_rsp_rdata;
    assign gpu_mem_rsp_id = pending_gpu_rsp_id;

    assign scan_mem_req_ready = (memory_owner == OWNER_SCANOUT) && data_req_ready;
    assign scan_mem_rsp_valid = (memory_owner == OWNER_SCANOUT) && data_rsp_valid;
    assign scan_mem_rsp_rdata = data_rsp_rdata;
    assign scan_mem_rsp_id = pending_scan_rsp_id;
    assign scan_mem_rsp_error = data_rsp_error;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            pending_gpu_rsp_id <= '0;
            pending_scan_rsp_id <= 1'b0;
            saw_gpu_mem_req <= 1'b0;
        end else if (data_req_valid && data_req_ready) begin
            if (memory_owner == OWNER_GPU) begin
                pending_gpu_rsp_id <= gpu_mem_req_id;
                saw_gpu_mem_req <= 1'b1;
            end else begin
                pending_scan_rsp_id <= scan_mem_req_id;
            end
        end
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

    task automatic check_scanout_pixel;
        int expected_x;
        int expected_y;
        begin
            expected_x = scan_pixels % GRID_X;
            expected_y = scan_pixels / GRID_X;
            check(scan_pixel_x == COORD_W'(expected_x), "scanout x matches GPU-written pixel");
            check(scan_pixel_y == COORD_W'(expected_y), "scanout y matches GPU-written pixel");
            check(scan_pixel_color == expected_pixel(expected_x, expected_y),
                "scanout color matches GPU-written gradient");
            scan_pixels = scan_pixels + 1;
        end
    endtask

    task automatic scan_framebuffer;
        int timeout;
        begin
            memory_owner = OWNER_SCANOUT;
            scan_pixels = 0;
            scan_pixel_ready = 1'b1;
            scan_start_valid = 1'b1;
            step();
            scan_start_valid = 1'b0;
            timeout = 0;

            while (!scan_done && timeout < 200) begin
                if (scan_pixel_valid) begin
                    check_scanout_pixel();
                end
                step();
                timeout = timeout + 1;
            end

            if (scan_pixel_valid) begin
                check_scanout_pixel();
            end

            check(timeout < 200, "framebuffer scanout timed out");
            check(scan_pixels == (GRID_X * GRID_Y), "scanout emitted every GPU-written pixel");
            check(!scan_error, "scanout sees no memory errors");
        end
    endtask

    initial begin
        init_command_driver();
        memory_owner = OWNER_GPU;
        scan_start_valid = 1'b0;
        scan_pixel_ready = 1'b0;

        step();
        reset = 1'b0;
        step();

        load_gradient_program();
        set_reg(KGPU_REG_FB_BASE, FRAMEBUFFER_BASE);
        configure_launch(32'h0000_0000, 32'(GRID_X), 32'(GRID_Y), 32'h0000_0000);
        launch_kernel();
        send_word(KGPU_CMD_WAIT_IDLE);
        wait_idle(400, "command-driven framebuffer scanout kernel timed out");

        check(error_status == 8'h00, "GPU framebuffer producer has no errors");
        check(saw_gpu_mem_req, "GPU framebuffer producer reached data memory");
        check(!data_rsp_valid, "GPU producer leaves no pending memory response before scanout");

        scan_framebuffer();

        $display("tb_gpu_core_command_framebuffer_scanout PASS");
        $finish;
    end
endmodule
