import isa_pkg::*;

module tb_programmable_core_lane_scaling;
    logic clk;
    logic reset;
    logic done_lanes2;
    logic done_lanes8;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1'b1;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        wait(done_lanes2 && done_lanes8);
        repeat (2) @(posedge clk);
        $display("PASS");
        $finish;
    end

    lane_scaling_case #(
        .LANES(2),
        .GRID_X(5),
        .CASE_ID(2)
    ) u_lanes2 (
        .clk(clk),
        .reset(reset),
        .done(done_lanes2)
    );

    lane_scaling_case #(
        .LANES(8),
        .GRID_X(10),
        .CASE_ID(8)
    ) u_lanes8 (
        .clk(clk),
        .reset(reset),
        .done(done_lanes8)
    );
endmodule

module lane_scaling_case #(
    parameter int LANES = 4,
    parameter int GRID_X = 5,
    parameter int CASE_ID = 0,
    parameter int DATA_W = 32,
    parameter int COORD_W = 16,
    parameter int ADDR_W = 32,
    parameter int PC_W = 8,
    parameter int REGS = 16,
    parameter int REG_ADDR_W = $clog2(REGS),
    parameter int IMEM_WORDS = 16
    ) (
    input logic clk,
    input logic reset,
    output logic done
);
    localparam int MAX_READY_CYCLES = 20;
    localparam int MAX_RUN_CYCLES = 300;

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
    logic error;
    logic [REG_ADDR_W-1:0] debug_read_addr;
    logic [(LANES*DATA_W)-1:0] debug_read_data;

    logic [ISA_WORD_W-1:0] imem [0:IMEM_WORDS-1];

    assign instruction = (instruction_addr < IMEM_WORDS[PC_W-1:0]) ? imem[instruction_addr] : '0;

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
        .data_rsp_rdata(32'h0000_0000),
        .busy(busy),
        .done(),
        .error(error),
        .debug_read_addr(debug_read_addr),
        .debug_read_data(debug_read_data)
    );

    function automatic logic [DATA_W-1:0] lane_data(input int lane);
    begin
        lane_data = debug_read_data[(lane*DATA_W)+:DATA_W];
    end
    endfunction

    function automatic int expected_final_linear_id(input int lane);
        int last_base;
        int tail_count;
        int previous_base;
    begin
        last_base = ((GRID_X - 1) / LANES) * LANES;
        tail_count = GRID_X - last_base;
        previous_base = (last_base >= LANES) ? (last_base - LANES) : 0;

        if (lane < tail_count) begin
            expected_final_linear_id = last_base + lane;
        end else begin
            expected_final_linear_id = previous_base + lane;
        end
    end
    endfunction

    task automatic check(input logic condition, input string message);
    begin
        if (!condition) begin
            $error("CHECK FAILED [case %0d]: %s", CASE_ID, message);
            $fatal(1);
        end
    end
    endtask

    task automatic step();
    begin
        @(posedge clk);
    end
    endtask

    task automatic wait_launch_accept();
        int cycle;
    begin
        cycle = 0;
        while (!launch_ready) begin
            check(cycle < MAX_READY_CYCLES, "launch handshake timeout");
            step();
            cycle = cycle + 1;
        end
    end
    endtask

    task automatic wait_core_idle();
        int cycle;
    begin
        cycle = 0;
        while (busy) begin
            check(!error, "programmable core stays out of error");
            check(cycle < MAX_RUN_CYCLES, "programmable core run timeout");
            step();
            cycle = cycle + 1;
        end
    end
    endtask

    initial begin
        $readmemh("tests/kernels/group_special_registers.memh", imem);
    end

    initial begin
        done = 1'b0;
        launch_valid = 1'b0;
        grid_x = COORD_W'(GRID_X);
        grid_y = COORD_W'(1);
        arg_base = 32'h0000_1000;
        framebuffer_base = 32'h0002_0000;
        framebuffer_width = COORD_W'(64);
        framebuffer_height = COORD_W'(64);
        debug_read_addr = '0;

        wait(!reset);
        step();
        check(launch_ready, "programmable core ready before lane-scaling launch");

        @(negedge clk);
        launch_valid = 1'b1;
        wait_launch_accept();

        @(negedge clk);
        launch_valid = 1'b0;

        wait_core_idle();

        debug_read_addr = 4'd1;
        #1;
        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            check(lane_data(lane) == DATA_W'(expected_final_linear_id(lane)),
                  $sformatf("R1 final linear_global_id lane %0d", lane));
        end

        debug_read_addr = 4'd2;
        #1;
        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            check(lane_data(lane) == DATA_W'(expected_final_linear_id(lane)),
                  $sformatf("R2 final global_id_x lane %0d", lane));
        end

        debug_read_addr = 4'd3;
        #1;
        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            check(lane_data(lane) == '0, $sformatf("R3 final global_id_y lane %0d", lane));
        end

        done = 1'b1;
    end
endmodule
