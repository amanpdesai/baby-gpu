module tb_load_store_unit;
    localparam int LANES = 4;
    localparam int DATA_W = 32;
    localparam int ADDR_W = 32;

    localparam logic [1:0] OP_LOAD = 2'd0;
    localparam logic [1:0] OP_STORE = 2'd1;
    localparam logic [1:0] OP_STORE16 = 2'd2;
    localparam logic [1:0] OP_INVALID = 2'd3;

    logic clk;
    logic reset;
    logic start_valid;
    logic start_ready;
    logic [1:0] op;
    logic [LANES-1:0] active_mask;
    logic [(LANES*ADDR_W)-1:0] lane_addr;
    logic [(LANES*DATA_W)-1:0] lane_wdata;
    logic busy;
    logic done;
    logic error;
    logic [(LANES*DATA_W)-1:0] lane_rdata;
    logic [LANES-1:0] lane_rvalid;
    logic req_valid;
    logic req_ready;
    logic req_write;
    logic [ADDR_W-1:0] req_addr;
    logic [DATA_W-1:0] req_wdata;
    logic [(DATA_W/8)-1:0] req_wmask;
    logic rsp_valid;
    logic rsp_ready;
    logic [DATA_W-1:0] rsp_rdata;

    load_store_unit #(
        .LANES(LANES),
        .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start_valid(start_valid),
        .start_ready(start_ready),
        .op(op),
        .active_mask(active_mask),
        .lane_addr(lane_addr),
        .lane_wdata(lane_wdata),
        .busy(busy),
        .done(done),
        .error(error),
        .lane_rdata(lane_rdata),
        .lane_rvalid(lane_rvalid),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wmask(req_wmask),
        .rsp_valid(rsp_valid),
        .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $fatal(1, "FAIL: %s", message);
            end
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic set_lane_addr(input int lane, input logic [ADDR_W-1:0] value);
        begin
            lane_addr[lane*ADDR_W +: ADDR_W] = value;
        end
    endtask

    task automatic set_lane_wdata(input int lane, input logic [DATA_W-1:0] value);
        begin
            lane_wdata[lane*DATA_W +: DATA_W] = value;
        end
    endtask

    task automatic reset_dut;
        begin
            reset = 1'b1;
            start_valid = 1'b0;
            op = OP_LOAD;
            active_mask = '0;
            lane_addr = '0;
            lane_wdata = '0;
            req_ready = 1'b0;
            rsp_valid = 1'b0;
            rsp_rdata = '0;
            tick();
            tick();
            reset = 1'b0;
            tick();
            check(start_ready, "ready after reset");
            check(!busy, "not busy after reset");
            check(!done, "done clear after reset");
            check(!error, "error clear after reset");
        end
    endtask

    task automatic start_cmd(
        input logic [1:0] cmd_op,
        input logic [LANES-1:0] cmd_mask
    );
        begin
            check(start_ready, "start accepted only when ready");
            op = cmd_op;
            active_mask = cmd_mask;
            start_valid = 1'b1;
            tick();
            start_valid = 1'b0;
        end
    endtask

    task automatic wait_for_req_valid;
        int cycle;
        begin
            cycle = 0;
            while (!req_valid && (cycle < 8)) begin
                tick();
                cycle = cycle + 1;
            end
            check(req_valid, "timed out waiting for req_valid");
        end
    endtask

    task automatic wait_for_done;
        int cycle;
        begin
            cycle = 0;
            while (!done && (cycle < 16)) begin
                tick();
                cycle = cycle + 1;
            end
            check(done, "timed out waiting for done");
        end
    endtask

    task automatic send_rsp(input logic [DATA_W-1:0] rdata);
        begin
            rsp_rdata = rdata;
            rsp_valid = 1'b1;
            tick();
            rsp_valid = 1'b0;
            rsp_rdata = '0;
        end
    endtask

    task automatic expect_store_req(
        input logic [ADDR_W-1:0] exp_addr,
        input logic [DATA_W-1:0] exp_wdata,
        input logic [(DATA_W/8)-1:0] exp_wmask,
        input string message
    );
        begin
            wait_for_req_valid();
            check(req_write, {message, " write"});
            check(req_addr == exp_addr, {message, " addr"});
            check(req_wdata == exp_wdata, {message, " wdata"});
            check(req_wmask == exp_wmask, {message, " wmask"});
            tick();
            check(rsp_ready, {message, " waits for write response"});
            send_rsp('0);
        end
    endtask

    task automatic expect_load_req(
        input logic [ADDR_W-1:0] exp_addr,
        input logic [DATA_W-1:0] rsp_data,
        input string message
    );
        begin
            wait_for_req_valid();
            check(!req_write, {message, " read"});
            check(req_addr == exp_addr, {message, " address"});
            check(req_wmask == 4'b0000, {message, " mask"});
            req_ready = 1'b1;
            tick();
            req_ready = 1'b0;
            check(rsp_ready, {message, " waits for read response"});
            send_rsp(rsp_data);
        end
    endtask

    task automatic test_single_lane_load_response_backpressure;
        begin
            reset_dut();
            set_lane_addr(2, 32'h0000_0040);
            req_ready = 1'b0;
            rsp_valid = 1'b1;
            rsp_rdata = 32'hCAFE_1234;
            start_cmd(OP_LOAD, 4'b0100);
            wait_for_req_valid();
            check(!req_write, "load request is read");
            check(req_addr == 32'h0000_0040, "load request lane address");
            check(!rsp_ready, "response backpressured before request handshake");
            tick();
            check(req_valid, "load request remains valid under request backpressure");
            check(req_addr == 32'h0000_0040, "load request address stable");
            req_ready = 1'b1;
            tick();
            req_ready = 1'b0;
            check(rsp_ready, "response accepted after request handshake");
            tick();
            rsp_valid = 1'b0;
            wait_for_done();
            check(lane_rvalid == 4'b0100, "only active load lane writes back");
            check(lane_rdata[2*DATA_W +: DATA_W] == 32'hCAFE_1234, "load response routed to lane");
        end
    endtask

    task automatic test_multi_lane_load_order;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0010);
            set_lane_addr(2, 32'h0000_0020);
            set_lane_addr(3, 32'h0000_0030);
            req_ready = 1'b0;
            start_cmd(OP_LOAD, 4'b1101);

            expect_load_req(32'h0000_0010, 32'hAAAA_0000, "load lane 0");
            expect_load_req(32'h0000_0020, 32'hBBBB_0002, "load lane 2");
            expect_load_req(32'h0000_0030, 32'hCCCC_0003, "load lane 3");
            wait_for_done();

            check(lane_rvalid == 4'b1101, "multi-lane load writes only active lanes");
            check(lane_rdata[0*DATA_W +: DATA_W] == 32'hAAAA_0000, "lane 0 load response");
            check(lane_rdata[1*DATA_W +: DATA_W] == 32'h0000_0000, "inactive lane unchanged");
            check(lane_rdata[2*DATA_W +: DATA_W] == 32'hBBBB_0002, "lane 2 load response");
            check(lane_rdata[3*DATA_W +: DATA_W] == 32'hCCCC_0003, "lane 3 load response");
        end
    endtask

    task automatic test_multi_lane_store_order;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0010);
            set_lane_addr(2, 32'h0000_0020);
            set_lane_addr(3, 32'h0000_0030);
            set_lane_wdata(0, 32'h1111_0000);
            set_lane_wdata(2, 32'h2222_0002);
            set_lane_wdata(3, 32'h3333_0003);
            req_ready = 1'b1;
            start_cmd(OP_STORE, 4'b1101);
            expect_store_req(32'h0000_0010, 32'h1111_0000, 4'b1111, "store lane 0");
            expect_store_req(32'h0000_0020, 32'h2222_0002, 4'b1111, "store lane 2");
            expect_store_req(32'h0000_0030, 32'h3333_0003, 4'b1111, "store lane 3");
            wait_for_done();
            check(lane_rvalid == 4'b0000, "stores do not produce load write enables");
        end
    endtask

    task automatic test_inactive_lanes_skipped;
        begin
            reset_dut();
            req_ready = 1'b1;
            start_cmd(OP_STORE, 4'b0000);
            tick();
            check(done, "empty active mask completes immediately");
            check(!busy, "empty active mask leaves LSU idle");
            check(!error, "empty active mask does not flag error");
            check(!req_valid, "empty active mask issues no request");
            wait_for_done();
            check(lane_rvalid == 4'b0000, "inactive lanes produce no load write enables");
        end
    endtask

    task automatic test_req_payload_stability;
        logic [ADDR_W-1:0] held_addr;
        logic [DATA_W-1:0] held_wdata;
        logic [(DATA_W/8)-1:0] held_wmask;
        begin
            reset_dut();
            set_lane_addr(1, 32'h0000_0080);
            set_lane_wdata(1, 32'hABCD_EF01);
            req_ready = 1'b0;
            start_cmd(OP_STORE, 4'b0010);
            wait_for_req_valid();
            held_addr = req_addr;
            held_wdata = req_wdata;
            held_wmask = req_wmask;
            op = OP_LOAD;
            active_mask = 4'b1000;
            lane_addr = '1;
            lane_wdata = '1;
            for (int cycle = 0; cycle < 3; cycle++) begin
                tick();
                check(req_valid, "request valid held under backpressure");
                check(req_addr == held_addr, "request address stable under backpressure");
                check(req_wdata == held_wdata, "request write data stable under backpressure");
                check(req_wmask == held_wmask, "request write mask stable under backpressure");
            end
            req_ready = 1'b1;
            tick();
            req_ready = 1'b0;
            check(rsp_ready, "store waits for write response after request acceptance");
            send_rsp('0);
            wait_for_done();
        end
    endtask

    task automatic test_start_rejected_while_busy;
        begin
            reset_dut();
            set_lane_addr(1, 32'h0000_0080);
            set_lane_wdata(1, 32'h1357_2468);
            req_ready = 1'b0;
            start_cmd(OP_STORE, 4'b0010);
            wait_for_req_valid();

            op = OP_LOAD;
            active_mask = 4'b1000;
            start_valid = 1'b1;
            tick();
            check(!start_ready, "second start is rejected while LSU is busy");
            check(req_valid, "busy rejection keeps current request valid");
            check(req_addr == 32'h0000_0080, "busy rejection keeps current request address");
            start_valid = 1'b0;

            req_ready = 1'b1;
            tick();
            req_ready = 1'b0;
            check(rsp_ready, "busy-rejection store waits for write response");
            send_rsp('0);
            wait_for_done();
        end
    endtask

    task automatic test_unaligned_32_bit_error;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0002);
            req_ready = 1'b1;
            start_cmd(OP_LOAD, 4'b0001);
            tick();
            check(error, "unaligned 32-bit load flags error");
            check(!req_valid, "unaligned 32-bit load issues no request");
            check(!done, "unaligned error does not signal done");
        end
    endtask

    task automatic test_store16_odd_address_error;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0101);
            set_lane_wdata(0, 32'h0000_55AA);
            req_ready = 1'b1;
            start_cmd(OP_STORE16, 4'b0001);
            tick();
            check(error, "odd-address STORE16 flags error");
            check(!req_valid, "odd-address STORE16 issues no request");
            check(!done, "odd-address STORE16 error does not signal done");
        end
    endtask

    task automatic test_invalid_op_error;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0180);
            set_lane_wdata(0, 32'hFACE_CAFE);
            req_ready = 1'b1;
            start_cmd(OP_INVALID, 4'b0001);
            tick();
            check(error, "invalid LSU op flags error");
            check(!done, "invalid LSU op does not signal done");
            check(!req_valid, "invalid LSU op issues no request");
            check(!rsp_ready, "invalid LSU op waits for no response");
            check(lane_rvalid == 4'b0000, "invalid LSU op produces no load write enables");
            check(start_ready, "invalid LSU op returns to idle");
        end
    endtask

    task automatic test_masked_lanes_do_not_fault;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0200);
            set_lane_addr(1, 32'h0000_0201);
            set_lane_addr(2, 32'h0000_0202);
            set_lane_addr(3, 32'h0000_0203);
            set_lane_wdata(0, 32'h0000_1111);
            set_lane_wdata(2, 32'h0000_2222);
            req_ready = 1'b1;

            start_cmd(OP_STORE16, 4'b0101);
            expect_store_req(32'h0000_0200, 32'h0000_1111, 4'b0011,
                             "masked odd lane does not fault before low-half store16");
            expect_store_req(32'h0000_0200, 32'h2222_0000, 4'b1100,
                             "masked odd lane does not fault before high-half store16");
            wait_for_done();
            check(!error, "masked odd-address lanes do not set LSU error");
        end
    endtask

    task automatic test_store16_masks;
        begin
            reset_dut();
            set_lane_addr(0, 32'h0000_0100);
            set_lane_addr(1, 32'h0000_0102);
            set_lane_wdata(0, 32'h0000_55AA);
            set_lane_wdata(1, 32'h0000_A55A);
            req_ready = 1'b1;
            start_cmd(OP_STORE16, 4'b0011);
            expect_store_req(32'h0000_0100, 32'h0000_55AA, 4'b0011, "store16 low half");
            expect_store_req(32'h0000_0100, 32'hA55A_0000, 4'b1100, "store16 high half");
            wait_for_done();
        end
    endtask

    initial begin
        test_single_lane_load_response_backpressure();
        test_multi_lane_load_order();
        test_multi_lane_store_order();
        test_inactive_lanes_skipped();
        test_req_payload_stability();
        test_start_rejected_while_busy();
        test_unaligned_32_bit_error();
        test_store16_odd_address_error();
        test_invalid_op_error();
        test_masked_lanes_do_not_fault();
        test_store16_masks();
        $display("tb_load_store_unit PASS");
        $finish;
    end
endmodule
