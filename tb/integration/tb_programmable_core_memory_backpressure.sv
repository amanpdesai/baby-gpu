import isa_pkg::*;

module tb_programmable_core_memory_backpressure;
    localparam int LANES = 4;
    localparam int DATA_W = 32;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int PC_W = 8;
    localparam int REGS = 16;
    localparam int REG_ADDR_W = $clog2(REGS);
    localparam int IMEM_ADDR_W = PC_W;

    localparam logic [31:0] LOAD_DATA = 32'hCAFE_BABE;

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

    function automatic logic [31:0] lane_word(
        input logic [(LANES*DATA_W)-1:0] payload,
        input int lane
    );
        begin
            lane_word = payload[(lane*DATA_W)+:DATA_W];
        end
    endfunction

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
            check(launch_ready, "launch_ready before memory backpressure test");
        end
    endtask

    task automatic launch_kernel;
        begin
            wait_launch_ready();
            @(negedge clk);
            launch_valid = 1'b1;
            check(launch_ready, "backpressure kernel launch accepted");
            step();
            @(negedge clk);
            launch_valid = 1'b0;
        end
    endtask

    task automatic expect_request_with_stall(
        input logic expected_write,
        input logic [ADDR_W-1:0] expected_addr,
        input logic [31:0] expected_wdata,
        input logic [3:0] expected_wmask,
        input int stall_cycles,
        input string label
    );
        int cycles;
        begin
            cycles = 0;
            while (!data_req_valid && cycles < 80) begin
                check(!error, {label, " request wait sees no error"});
                check(!done, {label, " request wait not done"});
                step();
                cycles++;
            end

            check(data_req_valid, {label, " request becomes valid"});
            check(data_req_write == expected_write, {label, " request write bit"});
            check(data_req_addr == expected_addr, {label, " request address"});
            check(data_req_wdata == expected_wdata, {label, " request write data"});
            check(data_req_wmask == expected_wmask, {label, " request mask"});

            repeat (stall_cycles) begin
                check(data_req_valid, {label, " request held valid under backpressure"});
                check(data_req_write == expected_write, {label, " stalled write bit stable"});
                check(data_req_addr == expected_addr, {label, " stalled address stable"});
                check(data_req_wdata == expected_wdata, {label, " stalled write data stable"});
                check(data_req_wmask == expected_wmask, {label, " stalled mask stable"});
                step();
            end

            @(negedge clk);
            data_req_ready = 1'b1;
            check(data_req_valid, {label, " request still valid before accept"});
            step();
            @(negedge clk);
            data_req_ready = 1'b0;
        end
    endtask

    task automatic respond_after_stall(
        input logic [31:0] response_data,
        input int stall_cycles,
        input string label
    );
        begin
            repeat (stall_cycles) begin
                check(data_rsp_ready, {label, " response ready while stalled"});
                check(!data_req_valid, {label, " no new request before response"});
                step();
            end

            @(negedge clk);
            data_rsp_rdata = response_data;
            data_rsp_valid = 1'b1;
            check(data_rsp_ready, {label, " response accepted when valid"});
            step();
            @(negedge clk);
            data_rsp_valid = 1'b0;
            data_rsp_rdata = '0;
        end
    endtask

    task automatic wait_done;
        int cycles;
        begin
            cycles = 0;
            while (!done && cycles < 80) begin
                check(!error, "core remains error-free after stalled memory sequence");
                check(!imem_fetch_error, "instruction fetch remains in range");
                step();
                cycles++;
            end

            check(done, "programmable core completes stalled memory kernel");
            check(!busy, "programmable core returns idle after stalled memory kernel");
            check(!error, "programmable core has no sticky error after stalled memory kernel");
            check(!imem_fetch_error, "instruction memory has no sticky error");
        end
    endtask

    initial begin
        reset = 1'b1;
        launch_valid = 1'b0;
        grid_x = 16'd1;
        grid_y = 16'd1;
        arg_base = '0;
        framebuffer_base = '0;
        framebuffer_width = '0;
        framebuffer_height = '0;
        imem_write_en = 1'b0;
        imem_write_addr = '0;
        imem_write_data = '0;
        data_req_ready = 1'b0;
        data_rsp_valid = 1'b0;
        data_rsp_rdata = '0;
        debug_read_addr = '0;

        repeat (3) step();
        reset = 1'b0;
        step();

        write_imem(8'd0, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd16));
        write_imem(8'd1, isa_pkg::isa_m_type(ISA_OP_LOAD, 4'd2, 4'd1, 18'd0));
        write_imem(8'd2, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd3, 4'd0, 18'd32));
        write_imem(8'd3, isa_pkg::isa_m_type(ISA_OP_STORE, 4'd2, 4'd3, 18'd0));
        write_imem(8'd4, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd4, 4'd0, 18'd34));
        write_imem(8'd5, isa_pkg::isa_m_type(ISA_OP_STORE16, 4'd2, 4'd4, 18'd0));
        write_imem(8'd6, isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0));

        launch_kernel();

        expect_request_with_stall(1'b0, 32'd16, 32'h0000_0000, 4'h0, 3, "LOAD");
        respond_after_stall(LOAD_DATA, 4, "LOAD");
        expect_request_with_stall(1'b1, 32'd32, LOAD_DATA, 4'hF, 2, "STORE");
        respond_after_stall(32'h0000_0000, 3, "STORE");
        expect_request_with_stall(1'b1, 32'd32, 32'hBABE_0000, 4'hC, 4, "STORE16");
        respond_after_stall(32'h0000_0000, 2, "STORE16");
        wait_done();

        debug_read_addr = 4'd2;
        #1;
        check(lane_word(debug_read_data, 0) == LOAD_DATA, "lane 0 retained loaded data");

        $finish;
    end
endmodule
