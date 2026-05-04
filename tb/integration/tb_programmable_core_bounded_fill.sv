import isa_pkg::*;
`include "tb/common/kernel_program_loader.svh"

module tb_programmable_core_bounded_fill;
    import kernel_asm_pkg::*;

    localparam int LANES = 4;
    localparam int DATA_W = 32;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int PC_W = 8;
    localparam int REGS = 16;
    localparam int REG_ADDR_W = $clog2(REGS);
    localparam int IMEM_ADDR_W = PC_W;
    localparam int DMEM_WORDS = 64;

    localparam logic [ADDR_W-1:0] FRAMEBUFFER_BASE = 32'h0000_0040;
    localparam int FRAMEBUFFER_WIDTH = 4;
    localparam int FRAMEBUFFER_HEIGHT = 3;
    localparam int FILL_WIDTH = 3;
    localparam int FILL_HEIGHT = 2;
    localparam logic [15:0] FILL_COLOR = 16'h04d2;

    logic clk;
    logic reset;
    logic launch_valid;
    logic launch_ready;
    logic [COORD_W-1:0] grid_x;
    logic [COORD_W-1:0] grid_y;
    logic [ADDR_W-1:0] arg_base;
    logic [ADDR_W-1:0] framebuffer_base;
    logic [COORD_W-1:0] framebuffer_width;
    logic [COORD_W-1:0] framebuffer_height;
    logic [PC_W-1:0] instruction_addr;
    logic [ISA_WORD_W-1:0] instruction;

    logic core_req_valid;
    logic core_req_ready;
    logic core_req_write;
    logic [ADDR_W-1:0] core_req_addr;
    logic [31:0] core_req_wdata;
    logic [3:0] core_req_wmask;
    logic core_rsp_valid;
    logic core_rsp_ready;
    logic [31:0] core_rsp_rdata;

    logic tb_mem_active;
    logic tb_req_valid;
    logic tb_req_ready;
    logic tb_req_write;
    logic [ADDR_W-1:0] tb_req_addr;
    logic [31:0] tb_req_wdata;
    logic [3:0] tb_req_wmask;
    logic tb_rsp_valid;
    logic tb_rsp_ready;
    logic [31:0] tb_rsp_rdata;

    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [31:0] mem_req_wdata;
    logic [3:0] mem_req_wmask;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [31:0] mem_rsp_rdata;
    logic mem_error;

    logic [REG_ADDR_W-1:0] debug_read_addr;
    logic [(LANES*DATA_W)-1:0] debug_read_data;
    logic busy;
    logic done;
    logic error;
    logic imem_write_en;
    logic [IMEM_ADDR_W-1:0] imem_write_addr;
    logic [ISA_WORD_W-1:0] imem_write_data;
    logic imem_fetch_error;

    programmable_core #(
        .LANES(LANES),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .PC_W(PC_W),
        .REGS(REGS),
        .REG_ADDR_W(REG_ADDR_W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .launch_valid(launch_valid),
        .launch_ready(launch_ready),
        .grid_x(grid_x),
        .grid_y(grid_y),
        .arg_base(arg_base),
        .framebuffer_base(framebuffer_base),
        .framebuffer_width(framebuffer_width),
        .framebuffer_height(framebuffer_height),
        .instruction_addr(instruction_addr),
        .instruction(instruction),
        .data_req_valid(core_req_valid),
        .data_req_ready(core_req_ready),
        .data_req_write(core_req_write),
        .data_req_addr(core_req_addr),
        .data_req_wdata(core_req_wdata),
        .data_req_wmask(core_req_wmask),
        .data_rsp_valid(core_rsp_valid),
        .data_rsp_ready(core_rsp_ready),
        .data_rsp_rdata(core_rsp_rdata),
        .busy(busy),
        .done(done),
        .error(error),
        .debug_read_addr(debug_read_addr),
        .debug_read_data(debug_read_data)
    );

    instruction_memory #(
        .WORD_W(ISA_WORD_W),
        .ADDR_W(IMEM_ADDR_W)
    ) imem (
        .clk(clk),
        .write_en(imem_write_en),
        .write_addr(imem_write_addr),
        .write_data(imem_write_data),
        .fetch_addr(instruction_addr),
        .fetch_instruction(instruction),
        .fetch_error(imem_fetch_error)
    );

    data_memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(32),
        .DEPTH_WORDS(DMEM_WORDS)
    ) dmem (
        .clk(clk),
        .reset(reset),
        .req_valid(mem_req_valid),
        .req_ready(mem_req_ready),
        .req_write(mem_req_write),
        .req_addr(mem_req_addr),
        .req_wdata(mem_req_wdata),
        .req_wmask(mem_req_wmask),
        .rsp_valid(mem_rsp_valid),
        .rsp_ready(mem_rsp_ready),
        .rsp_rdata(mem_rsp_rdata),
        .error(mem_error)
    );

    assign mem_req_valid = tb_mem_active ? tb_req_valid : core_req_valid;
    assign mem_req_write = tb_mem_active ? tb_req_write : core_req_write;
    assign mem_req_addr = tb_mem_active ? tb_req_addr : core_req_addr;
    assign mem_req_wdata = tb_mem_active ? tb_req_wdata : core_req_wdata;
    assign mem_req_wmask = tb_mem_active ? tb_req_wmask : core_req_wmask;
    assign mem_rsp_ready = tb_mem_active ? tb_rsp_ready : core_rsp_ready;

    assign core_req_ready = !tb_mem_active && mem_req_ready;
    assign core_rsp_valid = !tb_mem_active && mem_rsp_valid;
    assign core_rsp_rdata = mem_rsp_rdata;

    assign tb_req_ready = tb_mem_active && mem_req_ready;
    assign tb_rsp_valid = tb_mem_active && mem_rsp_valid;
    assign tb_rsp_rdata = mem_rsp_rdata;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $error("CHECK FAILED: %s", message);
                $fatal(1);
            end
        end
    endtask

    task automatic write_imem(
        input logic [IMEM_ADDR_W-1:0] addr,
        input logic [ISA_WORD_W-1:0] word
    );
        begin
            @(negedge clk);
            imem_write_en = 1'b1;
            imem_write_addr = addr;
            imem_write_data = word;
            @(negedge clk);
            imem_write_en = 1'b0;
            imem_write_addr = '0;
            imem_write_data = '0;
        end
    endtask

    task automatic mem_transact(
        input logic write,
        input logic [ADDR_W-1:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] wmask,
        input logic [31:0] expected_rdata
    );
        begin
            @(negedge clk);
            tb_mem_active = 1'b1;
            tb_req_valid = 1'b1;
            tb_req_write = write;
            tb_req_addr = addr;
            tb_req_wdata = wdata;
            tb_req_wmask = wmask;
            tb_rsp_ready = 1'b1;

            step();
            check(tb_req_ready, "testbench memory request accepted");

            @(negedge clk);
            tb_req_valid = 1'b0;
            tb_req_write = 1'b0;
            tb_req_addr = '0;
            tb_req_wdata = '0;
            tb_req_wmask = '0;

            check(tb_rsp_valid, "testbench memory response returned");
            if (!write) begin
                check(tb_rsp_rdata == expected_rdata, "testbench memory read data matches");
            end

            step();
            tb_rsp_ready = 1'b0;
            tb_mem_active = 1'b0;
        end
    endtask

    task automatic mem_write_word(
        input logic [ADDR_W-1:0] addr,
        input logic [31:0] data
    );
        begin
            mem_transact(1'b1, addr, data, 4'b1111, '0);
        end
    endtask

    task automatic mem_read_expect(
        input logic [ADDR_W-1:0] addr,
        input logic [31:0] expected
    );
        begin
            mem_transact(1'b0, addr, '0, '0, expected);
        end
    endtask

    task automatic launch_kernel(
        input logic [COORD_W-1:0] launch_grid_x,
        input logic [COORD_W-1:0] launch_grid_y
    );
        int cycles;
        begin
            grid_x = launch_grid_x;
            grid_y = launch_grid_y;
            launch_valid = 1'b1;
            cycles = 0;
            while (!launch_ready) begin
                check(!error, "core stays out of error while waiting to launch");
                step();
                cycles = cycles + 1;
                check(cycles < 32, "launch_ready timeout");
            end
            step();
            launch_valid = 1'b0;
        end
    endtask

    task automatic wait_kernel_done;
        int cycles;
        begin
            cycles = 0;
            while (!done && !error) begin
                step();
                cycles = cycles + 1;
                check(cycles < 512, "kernel completion timeout");
            end
            check(done, "kernel reports done");
            check(!error, "kernel completes without error");
            check(!mem_error, "data memory stays out of error");
            check(!imem_fetch_error, "instruction fetch stays in range");
        end
    endtask

    task automatic load_bounded_fill_program;
        logic [ISA_WORD_W-1:0] kernel_words [0:16];
        begin
            kernel_words[0] = kgpu_movsr(4'd1, ISA_SR_GLOBAL_ID_Y);
            kernel_words[1] = kgpu_movsr(4'd2, ISA_SR_FRAMEBUFFER_WIDTH);
            kernel_words[2] = kgpu_mul(4'd3, 4'd1, 4'd2);
            kernel_words[3] = kgpu_movsr(4'd4, ISA_SR_GLOBAL_ID_X);
            kernel_words[4] = kgpu_add(4'd3, 4'd3, 4'd4);
            kernel_words[5] = kgpu_movi(4'd5, 18'd2);
            kernel_words[6] = kgpu_mul(4'd3, 4'd3, 4'd5);
            kernel_words[7] = kgpu_movsr(4'd6, ISA_SR_FRAMEBUFFER_BASE);
            kernel_words[8] = kgpu_add(4'd7, 4'd6, 4'd3);
            kernel_words[9] = kgpu_movi(4'd8, 18'(FILL_COLOR));
            kernel_words[10] = kgpu_movi(4'd9, 18'(FILL_WIDTH));
            kernel_words[11] = kgpu_cmp(4'd10, 4'd4, 4'd9, ISA_CMP_LTU);
            kernel_words[12] = kgpu_movi(4'd11, 18'(FILL_HEIGHT));
            kernel_words[13] = kgpu_cmp(4'd12, 4'd1, 4'd11, ISA_CMP_LTU);
            kernel_words[14] = kgpu_and(4'd13, 4'd10, 4'd12);
            kernel_words[15] = kgpu_pstore16(4'd8, 4'd7, 4'd13, 14'd0);
            kernel_words[16] = kgpu_end();
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    initial begin
        reset = 1'b1;
        launch_valid = 1'b0;
        grid_x = '0;
        grid_y = '0;
        arg_base = 32'h0000_0100;
        framebuffer_base = FRAMEBUFFER_BASE;
        framebuffer_width = COORD_W'(FRAMEBUFFER_WIDTH);
        framebuffer_height = COORD_W'(FRAMEBUFFER_HEIGHT);
        debug_read_addr = '0;
        imem_write_en = 1'b0;
        imem_write_addr = '0;
        imem_write_data = '0;
        tb_mem_active = 1'b0;
        tb_req_valid = 1'b0;
        tb_req_write = 1'b0;
        tb_req_addr = '0;
        tb_req_wdata = '0;
        tb_req_wmask = '0;
        tb_rsp_ready = 1'b0;

        repeat (2) step();
        reset = 1'b0;
        step();

        load_bounded_fill_program();

        mem_write_word(FRAMEBUFFER_BASE + 32'd0, 32'hAAAA_AAAA);
        mem_write_word(FRAMEBUFFER_BASE + 32'd4, 32'hBBBB_BBBB);
        mem_write_word(FRAMEBUFFER_BASE + 32'd8, 32'hCCCC_CCCC);
        mem_write_word(FRAMEBUFFER_BASE + 32'd12, 32'hDDDD_DDDD);
        mem_write_word(FRAMEBUFFER_BASE + 32'd16, 32'hEEEE_EEEE);
        mem_write_word(FRAMEBUFFER_BASE + 32'd20, 32'hFFFF_FFFF);

        launch_kernel(COORD_W'(FRAMEBUFFER_WIDTH), COORD_W'(FRAMEBUFFER_HEIGHT));
        wait_kernel_done();

        mem_read_expect(FRAMEBUFFER_BASE + 32'd0, {FILL_COLOR, FILL_COLOR});
        mem_read_expect(FRAMEBUFFER_BASE + 32'd4, {16'hBBBB, FILL_COLOR});
        mem_read_expect(FRAMEBUFFER_BASE + 32'd8, {FILL_COLOR, FILL_COLOR});
        mem_read_expect(FRAMEBUFFER_BASE + 32'd12, {16'hDDDD, FILL_COLOR});
        mem_read_expect(FRAMEBUFFER_BASE + 32'd16, 32'hEEEE_EEEE);
        mem_read_expect(FRAMEBUFFER_BASE + 32'd20, 32'hFFFF_FFFF);

        $display("tb_programmable_core_bounded_fill PASS");
        $finish;
    end
endmodule
