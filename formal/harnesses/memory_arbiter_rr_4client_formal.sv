module memory_arbiter_rr_4client_formal(
    input logic clk
);
    localparam int CLIENTS = 4;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int LOCAL_ID_W = 2;
    localparam int MASK_W = DATA_W / 8;
    localparam int SOURCE_ID_W = 2;
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W;

    (* anyseq *) logic rst_n;
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
    logic past_valid;
    logic [SOURCE_ID_W-1:0] grant_source;
    logic [SOURCE_ID_W-1:0] rsp_source;
    logic [LOCAL_ID_W-1:0] rsp_local_id;

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

    assign grant_source = mem_req_id[MEM_ID_W-1 -: SOURCE_ID_W];
    assign rsp_source = mem_rsp_id[MEM_ID_W-1 -: SOURCE_ID_W];
    assign rsp_local_id = mem_rsp_id[LOCAL_ID_W-1:0];

    initial begin
        past_valid = 1'b0;
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        if (!past_valid) begin
            assume(!rst_n);
        end else begin
            assume(rst_n);
        end
    end

    always_ff @(posedge clk) begin
        if (past_valid && rst_n) begin
            assert(mem_req_valid == |client_req_valid);
            assert($onehot0(client_req_ready));

            if (client_req_valid == 4'b0001) begin
                assert(grant_source == 2'd0);
                assert(mem_req_write == client_req_write[0]);
                assert(mem_req_addr == client_req_addr[0 +: ADDR_W]);
                assert(mem_req_wdata == client_req_wdata[0 +: DATA_W]);
                assert(mem_req_wmask == client_req_wmask[0 +: MASK_W]);
                assert(mem_req_id[LOCAL_ID_W-1:0] == client_req_id[0 +: LOCAL_ID_W]);
            end

            if (client_req_valid == 4'b0010) begin
                assert(grant_source == 2'd1);
                assert(mem_req_write == client_req_write[1]);
                assert(mem_req_addr == client_req_addr[ADDR_W +: ADDR_W]);
                assert(mem_req_wdata == client_req_wdata[DATA_W +: DATA_W]);
                assert(mem_req_wmask == client_req_wmask[MASK_W +: MASK_W]);
                assert(mem_req_id[LOCAL_ID_W-1:0] == client_req_id[LOCAL_ID_W +: LOCAL_ID_W]);
            end

            if (client_req_valid == 4'b0100) begin
                assert(grant_source == 2'd2);
                assert(mem_req_write == client_req_write[2]);
                assert(mem_req_addr == client_req_addr[(2*ADDR_W) +: ADDR_W]);
                assert(mem_req_wdata == client_req_wdata[(2*DATA_W) +: DATA_W]);
                assert(mem_req_wmask == client_req_wmask[(2*MASK_W) +: MASK_W]);
                assert(mem_req_id[LOCAL_ID_W-1:0] == client_req_id[(2*LOCAL_ID_W) +: LOCAL_ID_W]);
            end

            if (client_req_valid == 4'b1000) begin
                assert(grant_source == 2'd3);
                assert(mem_req_write == client_req_write[3]);
                assert(mem_req_addr == client_req_addr[(3*ADDR_W) +: ADDR_W]);
                assert(mem_req_wdata == client_req_wdata[(3*DATA_W) +: DATA_W]);
                assert(mem_req_wmask == client_req_wmask[(3*MASK_W) +: MASK_W]);
                assert(mem_req_id[LOCAL_ID_W-1:0] == client_req_id[(3*LOCAL_ID_W) +: LOCAL_ID_W]);
            end

            if (mem_req_valid && mem_req_ready) begin
                assert(client_req_ready != 4'b0000);
            end

            if (mem_rsp_valid) begin
                assert(client_rsp_valid == (4'b0001 << rsp_source));
                assert(client_rsp_rdata[(rsp_source*DATA_W) +: DATA_W] == mem_rsp_rdata);
                assert(client_rsp_id[(rsp_source*LOCAL_ID_W) +: LOCAL_ID_W] == rsp_local_id);
                assert(client_rsp_error == (mem_rsp_error ? (4'b0001 << rsp_source) : 4'b0000));
            end

            if (
                $past(rst_n) &&
                $past(client_req_valid == 4'b1111) &&
                $past(mem_req_ready) &&
                $past(mem_req_valid) &&
                $past(grant_source == 2'd0) &&
                client_req_valid == 4'b1111 &&
                mem_req_ready &&
                mem_req_valid
            ) begin
                cover(grant_source == 2'd1);
            end

            cover(mem_rsp_valid && rsp_source == 2'd3 && client_rsp_valid == 4'b1000 && mem_rsp_ready);
        end
    end
endmodule
