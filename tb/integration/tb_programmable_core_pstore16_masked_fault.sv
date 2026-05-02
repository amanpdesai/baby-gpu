import isa_pkg::*;

module tb_programmable_core_pstore16_masked_fault;
    localparam int LANES = 4;
    localparam int DATA_W = 32;
    localparam int COORD_W = 16;
    localparam int ADDR_W = 32;
    localparam int PC_W = 8;
    localparam int REGS = 16;
    localparam int REG_ADDR_W = $clog2(REGS);
    localparam int IMEM_ADDR_W = PC_W;
    localparam int DMEM_WORDS = 64;

    localparam logic [ADDR_W-1:0] STORE_BASE = 32'h0000_0040;

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

    logic core_req_valid;
    logic core_req_ready;
    logic core_req_write;
    logic [ADDR_W-1:0] core_req_addr;
    logic [31:0] core_req_wdata;
    logic [3:0] core_req_wmask;
    logic core_rsp_valid;
    logic core_rsp_ready;
    logic [31:0] core_rsp_rdata;
    logic core_busy;
    logic core_done;
    logic core_error;
    logic [REG_ADDR_W-1:0] debug_read_addr;
    logic [(LANES*DATA_W)-1:0] debug_read_data;

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

    assign mem_req_valid = tb_mem_active ? tb_req_valid : core_req_valid;
    assign mem_req_write = tb_mem_active ? tb_req_write : core_req_write;
    assign mem_req_addr = tb_mem_active ? tb_req_addr : core_req_addr;
    assign mem_req_wdata = tb_mem_active ? tb_req_wdata : core_req_wdata;
    assign mem_req_wmask = tb_mem_active ? tb_req_wmask : core_req_wmask;
    assign mem_rsp_ready = tb_mem_active ? tb_rsp_ready : core_rsp_ready;

    assign tb_req_ready = tb_mem_active && mem_req_ready;
    assign tb_rsp_valid = tb_mem_active && mem_rsp_valid;
    assign tb_rsp_rdata = mem_rsp_rdata;

    assign core_req_ready = !tb_mem_active && mem_req_ready;
    assign core_rsp_valid = !tb_mem_active && mem_rsp_valid;
    assign core_rsp_rdata = mem_rsp_rdata;

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
        .data_req_valid(core_req_valid),
        .data_req_ready(core_req_ready),
        .data_req_write(core_req_write),
        .data_req_addr(core_req_addr),
        .data_req_wdata(core_req_wdata),
        .data_req_wmask(core_req_wmask),
        .data_rsp_valid(core_rsp_valid),
        .data_rsp_ready(core_rsp_ready),
        .data_rsp_rdata(core_rsp_rdata),
        .busy(core_busy),
        .done(core_done),
        .error(core_error),
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

    task automatic mem_transact(
        input logic is_write,
        input logic [ADDR_W-1:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] wmask,
        input logic [31:0] expected_rdata
    );
        begin
            @(negedge clk);
            tb_mem_active = 1'b1;
            tb_req_valid = 1'b1;
            tb_req_write = is_write;
            tb_req_addr = addr;
            tb_req_wdata = wdata;
            tb_req_wmask = wmask;
            tb_rsp_ready = 1'b1;

            step();
            check(tb_req_ready, "testbench memory request accepted");
            check(tb_rsp_valid, "testbench memory response returned");
            if (!is_write) begin
                check(tb_rsp_rdata == expected_rdata, "testbench memory read data matches");
            end

            @(negedge clk);
            tb_req_valid = 1'b0;
            tb_req_write = 1'b0;
            tb_req_addr = '0;
            tb_req_wdata = '0;
            tb_req_wmask = '0;
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
            mem_transact(1'b1, addr, data, 4'hF, 32'h0000_0000);
        end
    endtask

    task automatic mem_expect_word(
        input logic [ADDR_W-1:0] addr,
        input logic [31:0] expected
    );
        begin
            mem_transact(1'b0, addr, 32'h0000_0000, 4'h0, expected);
        end
    endtask

    task automatic wait_for_done;
        int cycles;
        begin
            cycles = 0;
            while (!core_done && cycles < 200) begin
                check(!core_error, "core error remains clear while running");
                check(!mem_error, "data memory error remains clear while running");
                check(!imem_fetch_error, "instruction fetch error remains clear while running");
                step();
                cycles++;
            end

            check(core_done, "programmable core completed predicated store kernel");
            check(!core_error, "programmable core completed without sticky error");
            check(!mem_error, "data memory completed without sticky error");
            check(!imem_fetch_error, "instruction memory completed without fetch error");
            check(!core_busy, "programmable core returned idle after completion");
            cycles = 0;
            while (!launch_ready && cycles < 8) begin
                step();
                cycles++;
            end
            check(launch_ready, "programmable core accepts a new launch after completion");
        end
    endtask

    task automatic run_kernel;
        begin
            @(negedge clk);
            launch_valid = 1'b1;
            check(launch_ready, "launch accepted");
            step();
            @(negedge clk);
            launch_valid = 1'b0;
            wait_for_done();
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
        tb_mem_active = 1'b0;
        tb_req_valid = 1'b0;
        tb_req_write = 1'b0;
        tb_req_addr = '0;
        tb_req_wdata = '0;
        tb_req_wmask = '0;
        tb_rsp_ready = 1'b0;
        debug_read_addr = '0;

        repeat (3) step();
        reset = 1'b0;
        step();

        mem_write_word(STORE_BASE + 32'd0, 32'hAAAA_AAAA);
        mem_write_word(STORE_BASE + 32'd4, 32'hBBBB_BBBB);
        mem_write_word(STORE_BASE + 32'd8, 32'hCCCC_CCCC);
        mem_write_word(STORE_BASE + 32'd12, 32'hDDDD_DDDD);

        write_imem(8'd0, isa_pkg::isa_s_type(ISA_OP_MOVSR, 4'd1, ISA_SR_LANE_ID));
        write_imem(8'd1, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd1));
        write_imem(8'd2, isa_pkg::isa_r_type(ISA_OP_AND, 4'd3, 4'd1, 4'd2));
        write_imem(8'd3, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd4, 4'd0, 18'd0));
        write_imem(8'd4, isa_pkg::isa_cmp_type(4'd5, 4'd3, 4'd4, ISA_CMP_EQ));
        write_imem(8'd5, isa_pkg::isa_r_type(ISA_OP_SHL, 4'd7, 4'd1, 4'd2));
        write_imem(8'd6, isa_pkg::isa_r_type(ISA_OP_ADD, 4'd8, 4'd7, 4'd3));
        write_imem(8'd7, isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd6, 4'd0, 18'h0_05A5));
        write_imem(8'd8, isa_pkg::isa_p_type(ISA_OP_PSTORE16, 4'd6, 4'd8, 4'd5, 14'd64));
        write_imem(8'd9, isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0));

        run_kernel();

        mem_expect_word(STORE_BASE + 32'd0, 32'hAAAA_05A5);
        mem_expect_word(STORE_BASE + 32'd4, 32'hBBBB_05A5);
        mem_expect_word(STORE_BASE + 32'd8, 32'hCCCC_CCCC);
        mem_expect_word(STORE_BASE + 32'd12, 32'hDDDD_DDDD);

        $finish;
    end
endmodule
