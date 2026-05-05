import isa_pkg::*;
`include "tb/common/kernel_program_loader.svh"

module tb_programmable_core_memory_fault;
    localparam int LANES = 4;
    localparam int DATA_W = 32;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int PC_W = 8;
    localparam int REGS = 16;
    localparam int REG_ADDR_W = $clog2(REGS);
    localparam int IMEM_ADDR_W = PC_W;

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
    logic imem_fetch_error;
    logic imem_write_en;
    logic [IMEM_ADDR_W-1:0] imem_write_addr;
    logic [ISA_WORD_W-1:0] imem_write_data;
    logic data_req_valid;
    logic data_req_ready;
    logic data_req_write;
    logic [ADDR_W-1:0] data_req_addr;
    logic [31:0] data_req_wdata;
    logic [3:0] data_req_wmask;
    logic data_rsp_valid;
    logic data_rsp_ready;
    logic [31:0] data_rsp_rdata;
    logic busy;
    logic done;
    logic error;
    logic [REG_ADDR_W-1:0] debug_read_addr;
    logic [(LANES*DATA_W)-1:0] debug_read_data;

    assign data_req_ready = 1'b1;
    assign data_rsp_valid = 1'b0;
    assign data_rsp_rdata = '0;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    programmable_core #(
        .LANES(LANES),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .PC_W(PC_W),
        .REGS(REGS)
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
        .data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),
        .data_req_write(data_req_write),
        .data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),
        .data_req_wmask(data_req_wmask),
        .data_rsp_valid(data_rsp_valid),
        .data_rsp_ready(data_rsp_ready),
        .data_rsp_rdata(data_rsp_rdata),
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
            step();
            imem_write_en = 1'b0;
            imem_write_addr = '0;
            imem_write_data = '0;
        end
    endtask

    task automatic wait_launch_ready;
        int cycles;
        begin
            cycles = 0;
            while (!launch_ready && cycles < 20) begin
                check(!error, "core stays out of error before launch");
                step();
                cycles++;
            end
            check(launch_ready, "launch_ready before memory fault test");
        end
    endtask

    task automatic launch_kernel;
        begin
            wait_launch_ready();
            @(negedge clk);
            launch_valid = 1'b1;
            check(launch_ready, "fault kernel launch accepted");
            step();
            @(negedge clk);
            launch_valid = 1'b0;
        end
    endtask

    task automatic load_memory_fault_program;
        logic [ISA_WORD_W-1:0] kernel_words [0:3];
        begin
            $readmemh("tests/kernels/memory_fault_unaligned_store.memh", kernel_words);
            `KGPU_LOAD_PROGRAM(kernel_words)
        end
    endtask

    task automatic wait_memory_fault;
        int cycles;
        begin
            cycles = 0;
            while (!error && cycles < 80) begin
                check(!done, "unaligned STORE does not complete successfully");
                check(!data_req_valid, "unaligned STORE issues no external request");
                check(!data_rsp_ready, "unaligned STORE waits for no response");
                check(!imem_fetch_error, "unaligned STORE fetch stays in range");
                step();
                cycles++;
            end

            check(error, "unaligned STORE raises programmable-core error");
            check(!done, "unaligned STORE remains failed, not done");
            check(!launch_ready, "error state blocks new launches");
            check(!data_req_valid, "error state has no outstanding memory request");
            check(!data_rsp_ready, "error state has no outstanding memory response wait");
            check(!imem_fetch_error, "instruction memory never faults during memory fault test");
        end
    endtask

    initial begin
        reset = 1'b1;
        launch_valid = 1'b0;
        grid_x = 16'd4;
        grid_y = 16'd1;
        arg_base = '0;
        framebuffer_base = '0;
        framebuffer_width = '0;
        framebuffer_height = '0;
        imem_write_en = 1'b0;
        imem_write_addr = '0;
        imem_write_data = '0;
        debug_read_addr = '0;

        repeat (3) step();
        reset = 1'b0;
        step();

        load_memory_fault_program();

        launch_kernel();
        wait_memory_fault();

        $finish;
    end
endmodule
