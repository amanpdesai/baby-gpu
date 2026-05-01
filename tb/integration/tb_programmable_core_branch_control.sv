import isa_pkg::*;

module tb_programmable_core_branch_control;
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

    function automatic logic [DATA_W-1:0] lane_data(input int lane);
        begin
            lane_data = debug_read_data[(lane*DATA_W)+:DATA_W];
        end
    endfunction

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

    task automatic load_branch_program(input logic predicate);
        begin
            write_imem(8'd0, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, {17'd0, predicate}));
            write_imem(8'd1, isa_pkg::isa_b_type(ISA_OP_BRA, 4'd1, 22'd2));
            write_imem(8'd2, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd11));
            write_imem(8'd3, isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0));
            write_imem(8'd4, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd22));
            write_imem(8'd5, isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0));
        end
    endtask

    task automatic launch_full_group();
        int cycles;
        begin
            cycles = 0;
            while (!launch_ready) begin
                check(!error, "core stays out of error before launch");
                check(cycles < 20, "launch_ready timeout");
                cycles = cycles + 1;
                step();
            end

            grid_x = COORD_W'(LANES);
            grid_y = 16'd1;
            arg_base = 32'h0000_1000;
            framebuffer_base = 32'h0000_2000;
            framebuffer_width = 16'd4;
            framebuffer_height = 16'd1;
            launch_valid = 1'b1;
            step();
            launch_valid = 1'b0;
        end
    endtask

    task automatic wait_kernel_done(input string scenario);
        int cycles;
        begin
            cycles = 0;
            while (!done) begin
                check(!error, {scenario, " stays out of error"});
                check(!data_req_valid, {scenario, " issues no memory request"});
                check(!data_rsp_ready, {scenario, " waits for no memory response"});
                check(!imem_fetch_error, {scenario, " fetch stays in range"});
                check(cycles < 120, {scenario, " timeout"});
                cycles = cycles + 1;
                step();
            end

            check(done && !error, {scenario, " completes without error"});
            check(!data_req_valid && !data_rsp_ready, {scenario, " leaves memory idle"});
            check(!imem_fetch_error, {scenario, " leaves fetch in range"});
        end
    endtask

    task automatic expect_all_lanes(input logic [DATA_W-1:0] expected, input string scenario);
        begin
            debug_read_addr = 4'd2;
            #1;
            for (int lane = 0; lane < LANES; lane++) begin
                check(lane_data(lane) == expected, {scenario, " lane result"});
            end
        end
    endtask

    initial begin
        reset_dut();
        load_branch_program(1'b1);
        launch_full_group();
        wait_kernel_done("taken branch");
        expect_all_lanes(32'd22, "taken branch skips fallthrough write");

        reset_dut();
        load_branch_program(1'b0);
        launch_full_group();
        wait_kernel_done("not-taken branch");
        expect_all_lanes(32'd11, "not-taken branch executes fallthrough write");

        $display("tb_programmable_core_branch_control PASS");
        $finish;
    end
endmodule
