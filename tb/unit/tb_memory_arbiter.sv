module tb_memory_arbiter;
    localparam int CLIENTS = 2;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int LOCAL_ID_W = 2;
    localparam int MASK_W = DATA_W / 8;
    localparam int SOURCE_ID_W = 1;
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W;

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

    memory_arbiter #(
        .CLIENTS(CLIENTS),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) dut (
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

    task automatic settle;
        begin
            #1;
        end
    endtask

    task automatic check(input bit condition, input string message);
        begin
            if (!condition) begin
                $fatal(1, "%s", message);
            end
        end
    endtask

    task automatic set_req(
        input int client,
        input logic valid,
        input logic write,
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] wdata,
        input logic [MASK_W-1:0] wmask,
        input logic [LOCAL_ID_W-1:0] id
    );
        begin
            client_req_valid[client] = valid;
            client_req_write[client] = write;
            client_req_addr[(client*ADDR_W) +: ADDR_W] = addr;
            client_req_wdata[(client*DATA_W) +: DATA_W] = wdata;
            client_req_wmask[(client*MASK_W) +: MASK_W] = wmask;
            client_req_id[(client*LOCAL_ID_W) +: LOCAL_ID_W] = id;
        end
    endtask

    task automatic reset_inputs;
        begin
            client_req_valid = '0;
            client_req_write = '0;
            client_req_addr = '0;
            client_req_wdata = '0;
            client_req_wmask = '0;
            client_req_id = '0;
            client_rsp_ready = '1;
            mem_req_ready = 1'b1;
            mem_rsp_valid = 1'b0;
            mem_rsp_rdata = '0;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            settle();
        end
    endtask

    task automatic test_client0_request;
        begin
            reset_inputs();
            set_req(0, 1'b1, 1'b1, 32'h0000_0040, 32'hCAFE_BABE, 4'b1111, 2'b10);
            settle();

            check(mem_req_valid, "client0 drives memory request valid");
            check(mem_req_write, "client0 write bit is forwarded");
            check(mem_req_addr == 32'h0000_0040, "client0 address is forwarded");
            check(mem_req_wdata == 32'hCAFE_BABE, "client0 write data is forwarded");
            check(mem_req_wmask == 4'b1111, "client0 write mask is forwarded");
            check(mem_req_id == 3'b010, "client0 source and local ID are forwarded");
            check(client_req_ready == 2'b01, "only selected client0 sees ready");
        end
    endtask

    task automatic test_low_index_priority;
        begin
            reset_inputs();
            set_req(0, 1'b1, 1'b0, 32'h0000_0010, 32'h1111_2222, 4'b0000, 2'b01);
            set_req(1, 1'b1, 1'b1, 32'h0000_0020, 32'h3333_4444, 4'b0011, 2'b11);
            settle();

            check(mem_req_valid, "contended request is valid");
            check(!mem_req_write, "client0 wins priority over client1");
            check(mem_req_addr == 32'h0000_0010, "priority forwards client0 address");
            check(mem_req_id == 3'b001, "priority forwards client0 ID");
            check(client_req_ready == 2'b01, "priority ready is only for client0");
        end
    endtask

    task automatic test_client1_request;
        begin
            reset_inputs();
            set_req(1, 1'b1, 1'b1, 32'h0000_0080, 32'h1234_5678, 4'b1100, 2'b01);
            settle();

            check(mem_req_valid, "client1 drives memory request valid");
            check(mem_req_write, "client1 write bit is forwarded");
            check(mem_req_addr == 32'h0000_0080, "client1 address is forwarded");
            check(mem_req_wdata == 32'h1234_5678, "client1 data is forwarded");
            check(mem_req_wmask == 4'b1100, "client1 mask is forwarded");
            check(mem_req_id == 3'b101, "client1 source and local ID are forwarded");
            check(client_req_ready == 2'b10, "only selected client1 sees ready");
        end
    endtask

    task automatic test_backpressure;
        begin
            reset_inputs();
            mem_req_ready = 1'b0;
            set_req(1, 1'b1, 1'b0, 32'h0000_00A0, 32'h0, 4'b0000, 2'b00);
            settle();

            check(mem_req_valid, "request remains valid while memory is stalled");
            check(client_req_ready == 2'b00, "no client ready while memory is stalled");
            check(mem_req_addr == 32'h0000_00A0, "stalled request payload is forwarded");
        end
    endtask

    task automatic test_response_route_client1;
        begin
            reset_inputs();
            client_rsp_ready = 2'b10;
            mem_rsp_valid = 1'b1;
            mem_rsp_id = 3'b111;
            mem_rsp_rdata = 32'hDEAD_BEEF;
            mem_rsp_error = 1'b1;
            settle();

            check(client_rsp_valid == 2'b10, "response routes to client1");
            check(mem_rsp_ready, "response ready follows selected client1");
            check(client_rsp_rdata[DATA_W +: DATA_W] == 32'hDEAD_BEEF, "client1 receives response data");
            check(client_rsp_id[LOCAL_ID_W +: LOCAL_ID_W] == 2'b11, "client1 receives local response ID");
            check(client_rsp_error == 2'b10, "response error routes to client1");
        end
    endtask

    task automatic test_response_backpressure;
        begin
            reset_inputs();
            client_rsp_ready = 2'b01;
            mem_rsp_valid = 1'b1;
            mem_rsp_id = 3'b101;
            settle();

            check(client_rsp_valid == 2'b10, "client1 response remains valid under backpressure");
            check(!mem_rsp_ready, "memory response ready follows backpressured client1");
        end
    endtask

    initial begin
        test_client0_request();
        test_low_index_priority();
        test_client1_request();
        test_backpressure();
        test_response_route_client1();
        test_response_backpressure();
        $display("tb_memory_arbiter PASS");
        $finish;
    end
endmodule
