module tb_memory_arbiter_rr_4client_data_memory;
    localparam int CLIENTS = 4;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int DEPTH_WORDS = 16;
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
    logic data_req_ready;
    logic data_rsp_valid;
    logic data_rsp_ready;
    logic [DATA_W-1:0] data_rsp_rdata;
    logic data_error;
    logic [MEM_ID_W-1:0] pending_mem_id_q;
    int errors;

    memory_arbiter_rr #(
        .CLIENTS(CLIENTS),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) arbiter (
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

    data_memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH_WORDS(DEPTH_WORDS)
    ) memory (
        .clk(clk),
        .reset(!rst_n),
        .req_valid(mem_req_valid),
        .req_ready(data_req_ready),
        .req_write(mem_req_write),
        .req_addr(mem_req_addr),
        .req_wdata(mem_req_wdata),
        .req_wmask(mem_req_wmask),
        .rsp_valid(data_rsp_valid),
        .rsp_ready(data_rsp_ready),
        .rsp_rdata(data_rsp_rdata),
        .error(data_error)
    );

    assign mem_req_ready = data_req_ready;
    assign data_rsp_ready = mem_rsp_ready;
    assign mem_rsp_valid = data_rsp_valid;
    assign mem_rsp_rdata = data_rsp_rdata;
    assign mem_rsp_id = pending_mem_id_q;
    assign mem_rsp_error = data_error;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_mem_id_q <= '0;
        end else if (mem_req_valid && mem_req_ready) begin
            pending_mem_id_q <= mem_req_id;
        end
    end

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

    task automatic clear_client_req(input int idx);
        begin
            client_req_valid[idx] = 1'b0;
            client_req_write[idx] = 1'b0;
            client_req_addr[(idx*ADDR_W) +: ADDR_W] = '0;
            client_req_wdata[(idx*DATA_W) +: DATA_W] = '0;
            client_req_wmask[(idx*MASK_W) +: MASK_W] = '0;
            client_req_id[(idx*LOCAL_ID_W) +: LOCAL_ID_W] = '0;
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
            rst_n = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            tick();
        end
    endtask

    task automatic expect_response(
        input int idx,
        input logic [DATA_W-1:0] expected_data,
        input logic [LOCAL_ID_W-1:0] expected_id,
        input string label
    );
        logic [CLIENTS-1:0] expected_valid;
        begin
            expected_valid = CLIENTS'(1) << idx;
            check(client_rsp_valid == expected_valid, {label, " routes only to selected client"});
            check(client_rsp_rdata[(idx*DATA_W) +: DATA_W] == expected_data, {label, " returns expected data"});
            check(client_rsp_id[(idx*LOCAL_ID_W) +: LOCAL_ID_W] == expected_id, {label, " returns local ID"});
            check(client_rsp_error == '0, {label, " returns no error"});
        end
    endtask

    task automatic accept_expected_request(
        input int idx,
        input logic [DATA_W-1:0] expected_response,
        input logic [LOCAL_ID_W-1:0] expected_id,
        input string label
    );
        begin
            settle();
            check(client_req_ready == (CLIENTS'(1) << idx), {label, " grants expected client"});
            tick();
            expect_response(idx, expected_response, expected_id, label);
            clear_client_req(idx);
        end
    endtask

    task automatic seed_full_word_writes;
        begin
            set_client_req(0, 1'b1, 1'b1, 8'h00, 32'h1111_2222, 4'b1111, 2'd1);
            set_client_req(1, 1'b1, 1'b1, 8'h04, 32'h3333_4444, 4'b1111, 2'd2);
            set_client_req(2, 1'b1, 1'b1, 8'h08, 32'h5555_6666, 4'b1111, 2'd3);
            set_client_req(3, 1'b1, 1'b1, 8'h0c, 32'h7777_8888, 4'b1111, 2'd0);
        end
    endtask

    task automatic seed_full_word_reads;
        begin
            set_client_req(0, 1'b1, 1'b0, 8'h00, '0, '0, 2'd1);
            set_client_req(1, 1'b1, 1'b0, 8'h04, '0, '0, 2'd2);
            set_client_req(2, 1'b1, 1'b0, 8'h08, '0, '0, 2'd3);
            set_client_req(3, 1'b1, 1'b0, 8'h0c, '0, '0, 2'd0);
        end
    endtask

    task automatic test_concurrent_write_readback;
        begin
            reset_dut();
            seed_full_word_writes();
            accept_expected_request(0, 32'h0000_0000, 2'd1, "client 0 write");
            accept_expected_request(1, 32'h0000_0000, 2'd2, "client 1 write");
            accept_expected_request(2, 32'h0000_0000, 2'd3, "client 2 write");
            accept_expected_request(3, 32'h0000_0000, 2'd0, "client 3 write");

            seed_full_word_reads();
            accept_expected_request(0, 32'h1111_2222, 2'd1, "client 0 readback");
            accept_expected_request(1, 32'h3333_4444, 2'd2, "client 1 readback");
            accept_expected_request(2, 32'h5555_6666, 2'd3, "client 2 readback");
            accept_expected_request(3, 32'h7777_8888, 2'd0, "client 3 readback");
        end
    endtask

    task automatic test_concurrent_masked_writes;
        begin
            reset_dut();
            seed_full_word_writes();
            accept_expected_request(0, 32'h0000_0000, 2'd1, "seed client 0 write");
            accept_expected_request(1, 32'h0000_0000, 2'd2, "seed client 1 write");
            accept_expected_request(2, 32'h0000_0000, 2'd3, "seed client 2 write");
            accept_expected_request(3, 32'h0000_0000, 2'd0, "seed client 3 write");

            set_client_req(0, 1'b1, 1'b1, 8'h00, 32'h0000_aaaa, 4'b0011, 2'd0);
            set_client_req(1, 1'b1, 1'b1, 8'h04, 32'hbbbb_0000, 4'b1100, 2'd1);
            set_client_req(2, 1'b1, 1'b1, 8'h0a, 32'hcccc_0000, 4'b1100, 2'd2);
            set_client_req(3, 1'b1, 1'b1, 8'h0c, 32'h0000_dddd, 4'b0011, 2'd3);
            accept_expected_request(0, 32'h0000_0000, 2'd0, "client 0 masked write");
            accept_expected_request(1, 32'h0000_0000, 2'd1, "client 1 masked write");
            accept_expected_request(2, 32'h0000_0000, 2'd2, "client 2 high-half write");
            accept_expected_request(3, 32'h0000_0000, 2'd3, "client 3 low-half write");

            seed_full_word_reads();
            accept_expected_request(0, 32'h1111_aaaa, 2'd1, "client 0 masked readback");
            accept_expected_request(1, 32'hbbbb_4444, 2'd2, "client 1 masked readback");
            accept_expected_request(2, 32'hcccc_6666, 2'd3, "client 2 masked readback");
            accept_expected_request(3, 32'h7777_dddd, 2'd0, "client 3 masked readback");
        end
    endtask

    task automatic test_response_backpressure_blocks_next_client;
        begin
            reset_dut();
            seed_full_word_writes();
            accept_expected_request(0, 32'h0000_0000, 2'd1, "backpressure seed client 0 write");
            accept_expected_request(1, 32'h0000_0000, 2'd2, "backpressure seed client 1 write");
            accept_expected_request(2, 32'h0000_0000, 2'd3, "backpressure seed client 2 write");
            accept_expected_request(3, 32'h0000_0000, 2'd0, "backpressure seed client 3 write");

            set_client_req(2, 1'b1, 1'b0, 8'h08, '0, '0, 2'd2);
            set_client_req(3, 1'b1, 1'b1, 8'h10, 32'h9999_aaaa, 4'b1111, 2'd3);
            client_rsp_ready[2] = 1'b0;

            settle();
            check(client_req_ready == 4'b0100, "client 2 read wins before stalled response");
            tick();
            check(client_rsp_valid == 4'b0100, "client 2 response is held under backpressure");
            check(client_rsp_rdata[(2*DATA_W) +: DATA_W] == 32'h5555_6666, "held client 2 response data is stable");
            check(!mem_req_ready, "memory request ready drops while selected response is stalled");
            check(client_req_ready == 4'b0000, "client 3 request is blocked by response backpressure");

            clear_client_req(2);
            client_rsp_ready[2] = 1'b1;
            tick();
            check(client_req_ready == 4'b1000, "client 3 request grants after held response drains");
            tick();
            expect_response(3, 32'h0000_0000, 2'd3, "client 3 post-backpressure write");
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        client_req_valid = '0;
        client_req_write = '0;
        client_req_addr = '0;
        client_req_wdata = '0;
        client_req_wmask = '0;
        client_req_id = '0;
        client_rsp_ready = '1;

        test_concurrent_write_readback();
        test_concurrent_masked_writes();
        test_response_backpressure_blocks_next_client();

        if (errors == 0) begin
            $display("tb_memory_arbiter_rr_4client_data_memory PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
