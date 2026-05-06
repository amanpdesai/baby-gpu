module tb_memory_arbiter_rr;
    localparam int CLIENTS = 3;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int LOCAL_ID_W = 2;
    localparam int MASK_W = DATA_W / 8;
    localparam int SOURCE_ID_W = 2;
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W;

    logic clk;
    logic rst_n;
    logic [CLIENTS-1:0] client_req_valid;
    logic [CLIENTS-1:0] client_req_ready;
    logic [CLIENTS-1:0] client_req_write;
    logic [(CLIENTS*ADDR_W)-1:0] client_req_addr;
    logic [(CLIENTS*DATA_W)-1:0] client_req_wdata;
    logic [(CLIENTS*MASK_W)-1:0] client_req_wmask;
    logic [(CLIENTS*LOCAL_ID_W)-1:0] client_req_id;
    logic [CLIENTS-1:0] client_rsp_valid;
    logic [CLIENTS-1:0] client_rsp_ready;
    logic [(CLIENTS*DATA_W)-1:0] client_rsp_rdata;
    logic [(CLIENTS*LOCAL_ID_W)-1:0] client_rsp_id;
    logic [CLIENTS-1:0] client_rsp_error;
    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [MASK_W-1:0] mem_req_wmask;
    logic [MEM_ID_W-1:0] mem_req_id;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [DATA_W-1:0] mem_rsp_rdata;
    logic [MEM_ID_W-1:0] mem_rsp_id;
    logic mem_rsp_error;
    int errors;

    memory_arbiter_rr #(
        .CLIENTS(CLIENTS),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .client_req_valid(client_req_valid),
        .client_req_ready(client_req_ready),
        .client_req_write(client_req_write),
        .client_req_addr(client_req_addr),
        .client_req_wdata(client_req_wdata),
        .client_req_wmask(client_req_wmask),
        .client_req_id(client_req_id),
        .client_rsp_valid(client_rsp_valid),
        .client_rsp_ready(client_rsp_ready),
        .client_rsp_rdata(client_rsp_rdata),
        .client_rsp_id(client_rsp_id),
        .client_rsp_error(client_rsp_error),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wmask(mem_req_wmask),
        .mem_req_id(mem_req_id),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_rdata(mem_rsp_rdata),
        .mem_rsp_id(mem_rsp_id),
        .mem_rsp_error(mem_rsp_error)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                errors++;
            end
        end
    endtask

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic settle;
        begin
            #1;
        end
    endtask

    task automatic set_client_req(
        input int idx,
        input bit valid,
        input bit write,
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] wdata,
        input logic [MASK_W-1:0] wmask,
        input logic [LOCAL_ID_W-1:0] local_id
    );
        begin
            client_req_valid[idx] = valid;
            client_req_write[idx] = write;
            client_req_addr[(idx*ADDR_W) +: ADDR_W] = addr;
            client_req_wdata[(idx*DATA_W) +: DATA_W] = wdata;
            client_req_wmask[(idx*MASK_W) +: MASK_W] = wmask;
            client_req_id[(idx*LOCAL_ID_W) +: LOCAL_ID_W] = local_id;
        end
    endtask

    task automatic reset_dut;
        begin
            client_req_valid = '0;
            client_req_write = '0;
            client_req_addr = '0;
            client_req_wdata = '0;
            client_req_wmask = '0;
            client_req_id = '0;
            client_rsp_ready = '1;
            mem_req_ready = 1'b0;
            mem_rsp_valid = 1'b0;
            mem_rsp_rdata = '0;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            rst_n = 1'b0;
            tick();
            rst_n = 1'b1;
            tick();
        end
    endtask

    task automatic accept_grant;
        begin
            mem_req_ready = 1'b1;
            tick();
            mem_req_ready = 1'b0;
            settle();
        end
    endtask

    task automatic expect_grant(
        input int idx,
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] wdata,
        input logic [MASK_W-1:0] wmask,
        input logic [LOCAL_ID_W-1:0] local_id,
        input string label
    );
        logic [MEM_ID_W-1:0] expected_id;
        begin
            expected_id = {SOURCE_ID_W'(idx), local_id};
            settle();
            check(mem_req_valid, {label, " request valid"});
            check(mem_req_addr == addr, {label, " forwards address"});
            check(mem_req_wdata == wdata, {label, " forwards write data"});
            check(mem_req_wmask == wmask, {label, " forwards write mask"});
            check(mem_req_id == expected_id, {label, " forwards source-local ID"});
        end
    endtask

    task automatic test_rotates_after_accept;
        begin
            reset_dut();
            set_client_req(0, 1'b1, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1);
            set_client_req(1, 1'b1, 1'b1, 32'h0000_0020, 32'hBBBB_1111, 4'b0011, 2'd2);
            set_client_req(2, 1'b1, 1'b0, 32'h0000_0030, 32'hCCCC_2222, 4'b1100, 2'd3);

            expect_grant(0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "first grant");
            accept_grant();
            expect_grant(1, 32'h0000_0020, 32'hBBBB_1111, 4'b0011, 2'd2, "second grant");
            accept_grant();
            expect_grant(2, 32'h0000_0030, 32'hCCCC_2222, 4'b1100, 2'd3, "third grant");
            accept_grant();
            expect_grant(0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "wrapped grant");
        end
    endtask

    task automatic test_skips_inactive_clients;
        begin
            reset_dut();
            set_client_req(0, 1'b1, 1'b0, 32'h0000_0100, 32'h0000_0001, 4'b1111, 2'd0);
            set_client_req(1, 1'b0, 1'b0, 32'h0000_0200, 32'h0000_0002, 4'b1111, 2'd1);
            set_client_req(2, 1'b1, 1'b1, 32'h0000_0300, 32'h0000_0003, 4'b0101, 2'd2);

            expect_grant(0, 32'h0000_0100, 32'h0000_0001, 4'b1111, 2'd0, "initial active grant");
            accept_grant();
            expect_grant(2, 32'h0000_0300, 32'h0000_0003, 4'b0101, 2'd2, "skipped inactive grant");
        end
    endtask

    task automatic test_backpressure_holds_rotation;
        begin
            reset_dut();
            set_client_req(0, 1'b1, 1'b0, 32'h0000_1000, 32'h1111_1111, 4'b1111, 2'd1);
            set_client_req(1, 1'b1, 1'b0, 32'h0000_2000, 32'h2222_2222, 4'b1111, 2'd2);
            set_client_req(2, 1'b1, 1'b0, 32'h0000_3000, 32'h3333_3333, 4'b1111, 2'd3);

            mem_req_ready = 1'b0;
            expect_grant(0, 32'h0000_1000, 32'h1111_1111, 4'b1111, 2'd1, "stalled grant");
            tick();
            tick();
            expect_grant(0, 32'h0000_1000, 32'h1111_1111, 4'b1111, 2'd1, "still stalled grant");
            accept_grant();
            expect_grant(1, 32'h0000_2000, 32'h2222_2222, 4'b1111, 2'd2, "post-stall grant");
        end
    endtask

    task automatic test_ready_onehot;
        begin
            reset_dut();
            set_client_req(0, 1'b1, 1'b0, 32'h0, 32'h0, 4'b1111, 2'd0);
            set_client_req(1, 1'b1, 1'b0, 32'h0, 32'h0, 4'b1111, 2'd1);
            set_client_req(2, 1'b1, 1'b0, 32'h0, 32'h0, 4'b1111, 2'd2);

            mem_req_ready = 1'b0;
            settle();
            check(client_req_ready == 3'b000, "no client ready when memory stalls");
            mem_req_ready = 1'b1;
            settle();
            check(client_req_ready == 3'b001, "only granted client ready");
            tick();
            settle();
            check(client_req_ready == 3'b010, "ready rotates after accept");
        end
    endtask

    task automatic test_response_routing;
        begin
            reset_dut();
            mem_rsp_valid = 1'b1;
            mem_rsp_rdata = 32'hCAFE_BABE;
            mem_rsp_id = {2'd2, 2'd1};
            mem_rsp_error = 1'b1;
            client_rsp_ready = 3'b101;
            settle();

            check(client_rsp_valid == 3'b100, "response routes only to source client");
            check(client_rsp_rdata[(2*DATA_W) +: DATA_W] == 32'hCAFE_BABE, "response data forwards");
            check(client_rsp_id[(2*LOCAL_ID_W) +: LOCAL_ID_W] == 2'd1, "response local ID strips source");
            check(client_rsp_error == 3'b100, "response error routes with valid");
            check(mem_rsp_ready, "response ready uses selected client ready");

            mem_rsp_id = {2'd3, 2'd0};
            settle();
            check(client_rsp_valid == 3'b000, "invalid source produces no client response");
            check(mem_rsp_ready, "invalid source is drained");
        end
    endtask

    initial begin
        errors = 0;
        test_rotates_after_accept();
        test_skips_inactive_clients();
        test_backpressure_holds_rotation();
        test_ready_onehot();
        test_response_routing();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
