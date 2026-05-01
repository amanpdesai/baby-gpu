import isa_pkg::*;

module tb_programmable_core_illegal_instruction;
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
    logic data_req_valid;
    logic data_req_write;
    logic [ADDR_W-1:0] data_req_addr;
    logic [31:0] data_req_wdata;
    logic [3:0] data_req_wmask;
    logic data_rsp_ready;
    logic busy;
    logic done;
    logic error;
    logic [REG_ADDR_W-1:0] debug_read_addr;
    logic [(LANES*DATA_W)-1:0] debug_read_data;

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
        .data_req_valid(data_req_valid),
        .data_req_ready(1'b1),
        .data_req_write(data_req_write),
        .data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),
        .data_req_wmask(data_req_wmask),
        .data_rsp_valid(1'b0),
        .data_rsp_ready(data_rsp_ready),
        .data_rsp_rdata('0),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic step();
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

    task automatic reset_dut();
        begin
            reset = 1'b1;
            launch_valid = 1'b0;
            grid_x = '0;
            grid_y = '0;
            arg_base = '0;
            framebuffer_base = '0;
            framebuffer_width = '0;
            framebuffer_height = '0;
            imem_write_en = 1'b0;
            imem_write_addr = '0;
            imem_write_data = '0;
            debug_read_addr = '0;
            step();
            step();
            reset = 1'b0;
            step();
            check(launch_ready, "launch ready after reset");
            check(!busy && !done && !error, "status clear after reset");
            check(!data_req_valid && !data_rsp_ready, "memory interface idle after reset");
        end
    endtask

    task automatic launch_one_group();
        int cycles;
        begin
            cycles = 0;
            while (!launch_ready) begin
                check(!error, "core stays out of error before launch");
                check(cycles < 20, "launch_ready timeout");
                cycles = cycles + 1;
                step();
            end

            grid_x = 16'd1;
            grid_y = 16'd1;
            arg_base = 32'h0000_1000;
            framebuffer_base = 32'h0000_2000;
            framebuffer_width = 16'd1;
            framebuffer_height = 16'd1;
            launch_valid = 1'b1;
            step();
            launch_valid = 1'b0;
        end
    endtask

    task automatic wait_for_illegal_instruction_error();
        int cycles;
        begin
            cycles = 0;
            while (!error) begin
                check(!done, "illegal instruction does not complete successfully");
                check(!data_req_valid, "illegal instruction issues no memory request");
                check(!data_rsp_ready, "illegal instruction waits for no memory response");
                check(!imem_fetch_error, "illegal instruction fetch stays in range");
                check(cycles < 80, "illegal instruction error timeout");
                cycles = cycles + 1;
                step();
            end

            check(error, "illegal instruction raises programmable-core error");
            check(!done, "illegal instruction does not assert done");
            check(!launch_ready, "error state blocks new launches");
            check(!data_req_valid, "error state keeps memory request idle");
            check(!data_rsp_ready, "error state keeps response channel idle");

            launch_valid = 1'b1;
            step();
            launch_valid = 1'b0;
            check(error, "error state remains set after rejected launch");
            check(!done, "rejected launch does not complete");
            check(!launch_ready, "rejected launch keeps launch_ready low");
            check(!data_req_valid, "rejected launch issues no memory request");
            check(!data_rsp_ready, "rejected launch waits for no memory response");
        end
    endtask

    initial begin
        reset_dut();
        write_imem(8'd0, {6'h3F, 26'd0});
        launch_one_group();
        wait_for_illegal_instruction_error();
        $display("tb_programmable_core_illegal_instruction PASS");
        $finish;
    end
endmodule
