module memory_arbiter_formal;
    localparam int CLIENTS = 2;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int LOCAL_ID_W = 2;
    localparam int MASK_W = DATA_W / 8;
    localparam int SOURCE_ID_W = 1;
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W;

    (* anyseq *) logic [CLIENTS-1:0] client_req_valid;
    logic [CLIENTS-1:0] client_req_ready;
    (* anyseq *) logic [CLIENTS-1:0] client_req_write;
    (* anyseq *) logic [(CLIENTS*ADDR_W)-1:0] client_req_addr;
    (* anyseq *) logic [(CLIENTS*DATA_W)-1:0] client_req_wdata;
    (* anyseq *) logic [(CLIENTS*MASK_W)-1:0] client_req_wmask;
    (* anyseq *) logic [(CLIENTS*LOCAL_ID_W)-1:0] client_req_id;
    logic [CLIENTS-1:0] client_rsp_valid;
    (* anyseq *) logic [CLIENTS-1:0] client_rsp_ready;
    logic [(CLIENTS*DATA_W)-1:0] client_rsp_rdata;
    logic [(CLIENTS*LOCAL_ID_W)-1:0] client_rsp_id;
    logic [CLIENTS-1:0] client_rsp_error;
    logic mem_req_valid;
    (* anyseq *) logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [MASK_W-1:0] mem_req_wmask;
    logic [MEM_ID_W-1:0] mem_req_id;
    (* anyseq *) logic mem_rsp_valid;
    logic mem_rsp_ready;
    (* anyseq *) logic [DATA_W-1:0] mem_rsp_rdata;
    (* anyseq *) logic [MEM_ID_W-1:0] mem_rsp_id;
    (* anyseq *) logic mem_rsp_error;

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

    always @* begin
        assert(mem_req_valid == |client_req_valid);

        if (!client_req_valid[0] && !client_req_valid[1]) begin
            assert(client_req_ready == 2'b00);
        end

        if (client_req_valid[0]) begin
            assert(client_req_ready[0] == mem_req_ready);
            assert(!client_req_ready[1]);
            assert(mem_req_write == client_req_write[0]);
            assert(mem_req_addr == client_req_addr[0 +: ADDR_W]);
            assert(mem_req_wdata == client_req_wdata[0 +: DATA_W]);
            assert(mem_req_wmask == client_req_wmask[0 +: MASK_W]);
            assert(mem_req_id == {1'b0, client_req_id[0 +: LOCAL_ID_W]});
        end else if (client_req_valid[1]) begin
            assert(!client_req_ready[0]);
            assert(client_req_ready[1] == mem_req_ready);
            assert(mem_req_write == client_req_write[1]);
            assert(mem_req_addr == client_req_addr[ADDR_W +: ADDR_W]);
            assert(mem_req_wdata == client_req_wdata[DATA_W +: DATA_W]);
            assert(mem_req_wmask == client_req_wmask[MASK_W +: MASK_W]);
            assert(mem_req_id == {1'b1, client_req_id[LOCAL_ID_W +: LOCAL_ID_W]});
        end

        if (mem_rsp_valid && mem_rsp_id[MEM_ID_W-1]) begin
            assert(client_rsp_valid == 2'b10);
            assert(mem_rsp_ready == client_rsp_ready[1]);
            assert(client_rsp_rdata[DATA_W +: DATA_W] == mem_rsp_rdata);
            assert(client_rsp_id[LOCAL_ID_W +: LOCAL_ID_W] == mem_rsp_id[LOCAL_ID_W-1:0]);
            assert(client_rsp_error[1] == mem_rsp_error);
            assert(!client_rsp_error[0]);
        end else if (mem_rsp_valid && !mem_rsp_id[MEM_ID_W-1]) begin
            assert(client_rsp_valid == 2'b01);
            assert(mem_rsp_ready == client_rsp_ready[0]);
            assert(client_rsp_rdata[0 +: DATA_W] == mem_rsp_rdata);
            assert(client_rsp_id[0 +: LOCAL_ID_W] == mem_rsp_id[LOCAL_ID_W-1:0]);
            assert(client_rsp_error[0] == mem_rsp_error);
            assert(!client_rsp_error[1]);
        end else begin
            assert(client_rsp_valid == 2'b00);
            assert(client_rsp_error == 2'b00);
        end

        cover(client_req_valid == 2'b10 && mem_req_ready && mem_req_id == 3'b101);
        cover(mem_rsp_valid && mem_rsp_id == 3'b111 && client_rsp_valid == 2'b10 && mem_rsp_ready);
    end
endmodule
