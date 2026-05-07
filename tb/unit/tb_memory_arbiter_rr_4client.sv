module tb_memory_arbiter_rr_4client;
    localparam int CLIENTS = 4;
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    task automatic expect_grant(
        input int idx,
        input bit write,
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
            check(mem_req_write == write, {label, " forwards write flag"});
            check(mem_req_addr == addr, {label, " forwards address"});
            check(mem_req_wdata == wdata, {label, " forwards data"});
            check(mem_req_wmask == wmask, {label, " forwards mask"});
            check(mem_req_id == expected_id, {label, " forwards source-local ID"});
            check(
                client_req_ready == (mem_req_ready ? (CLIENTS'(1) << idx) : '0),
                {label, " drives ready only when memory accepts"}
            );
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

    task automatic seed_all_clients;
        begin
            set_client_req(0, 1'b1, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1);
            set_client_req(1, 1'b1, 1'b1, 32'h0000_0020, 32'hBBBB_1111, 4'b0011, 2'd2);
            set_client_req(2, 1'b1, 1'b0, 32'h0000_0030, 32'hCCCC_2222, 4'b1100, 2'd3);
            set_client_req(3, 1'b1, 1'b1, 32'h0000_0040, 32'hDDDD_3333, 4'b0101, 2'd0);
        end
    endtask

    task automatic test_four_client_rotation;
        begin
            reset_dut();
            seed_all_clients();

            expect_grant(0, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "client 0 grant");
            accept_grant();
            expect_grant(1, 1'b1, 32'h0000_0020, 32'hBBBB_1111, 4'b0011, 2'd2, "client 1 grant");
            accept_grant();
            expect_grant(2, 1'b0, 32'h0000_0030, 32'hCCCC_2222, 4'b1100, 2'd3, "client 2 grant");
            accept_grant();
            expect_grant(3, 1'b1, 32'h0000_0040, 32'hDDDD_3333, 4'b0101, 2'd0, "client 3 grant");
            accept_grant();
            expect_grant(0, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "wrapped client 0 grant");
        end
    endtask

    task automatic test_backpressure_holds_grant;
        begin
            reset_dut();
            seed_all_clients();

            mem_req_ready = 1'b0;
            expect_grant(0, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "stalled client 0 grant");
            tick();
            tick();
            expect_grant(0, 1'b0, 32'h0000_0010, 32'hAAAA_0000, 4'b1111, 2'd1, "held client 0 grant");
            accept_grant();
            expect_grant(1, 1'b1, 32'h0000_0020, 32'hBBBB_1111, 4'b0011, 2'd2, "post-stall client 1 grant");
        end
    endtask

    task automatic test_single_high_client_grant;
        begin
            reset_dut();
            set_client_req(3, 1'b1, 1'b1, 32'h0000_0100, 32'hFACE_CAFE, 4'b1010, 2'd2);
            expect_grant(3, 1'b1, 32'h0000_0100, 32'hFACE_CAFE, 4'b1010, 2'd2, "single high client grant");
        end
    endtask

    task automatic test_response_routing_all_clients;
        int idx;
        logic [CLIENTS-1:0] expected_valid;
        begin
            reset_dut();

            for (idx = 0; idx < CLIENTS; idx++) begin
                mem_rsp_valid = 1'b1;
                mem_rsp_rdata = 32'hCAFE_0000 | 32'(idx);
                mem_rsp_id = {SOURCE_ID_W'(idx), LOCAL_ID_W'(idx[1:0])};
                mem_rsp_error = idx[0];
                client_rsp_ready = CLIENTS'(1) << idx;
                settle();

                expected_valid = CLIENTS'(1) << idx;
                check(client_rsp_valid == expected_valid, "response routes only to selected client");
                check(client_rsp_rdata[(idx*DATA_W) +: DATA_W] == mem_rsp_rdata, "response data forwards");
                check(client_rsp_id[(idx*LOCAL_ID_W) +: LOCAL_ID_W] == LOCAL_ID_W'(idx[1:0]), "response ID strips source");
                check(client_rsp_error == (idx[0] ? expected_valid : '0), "response error is valid-scoped");
                check(mem_rsp_ready, "response ready follows selected client");
            end
        end
    endtask

    initial begin
        errors = 0;

        test_four_client_rotation();
        test_backpressure_holds_grant();
        test_single_high_client_grant();
        test_response_routing_all_clients();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
