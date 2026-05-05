module memory_arbiter #(
    parameter int CLIENTS = 2,
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int LOCAL_ID_W = 1,
    localparam int MASK_W = DATA_W / 8,
    localparam int SOURCE_ID_W = (CLIENTS <= 1) ? 1 : $clog2(CLIENTS),
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W
) (
    input logic [CLIENTS-1:0] client_req_valid,
    output logic [CLIENTS-1:0] client_req_ready,
    input logic [CLIENTS-1:0] client_req_write,
    input logic [(CLIENTS*ADDR_W)-1:0] client_req_addr,
    input logic [(CLIENTS*DATA_W)-1:0] client_req_wdata,
    input logic [(CLIENTS*MASK_W)-1:0] client_req_wmask,
    input logic [(CLIENTS*LOCAL_ID_W)-1:0] client_req_id,

    output logic [CLIENTS-1:0] client_rsp_valid,
    input logic [CLIENTS-1:0] client_rsp_ready,
    output logic [(CLIENTS*DATA_W)-1:0] client_rsp_rdata,
    output logic [(CLIENTS*LOCAL_ID_W)-1:0] client_rsp_id,
    output logic [CLIENTS-1:0] client_rsp_error,

    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic mem_req_write,
    output logic [ADDR_W-1:0] mem_req_addr,
    output logic [DATA_W-1:0] mem_req_wdata,
    output logic [MASK_W-1:0] mem_req_wmask,
    output logic [MEM_ID_W-1:0] mem_req_id,

    input logic mem_rsp_valid,
    output logic mem_rsp_ready,
    input logic [DATA_W-1:0] mem_rsp_rdata,
    input logic [MEM_ID_W-1:0] mem_rsp_id,
    input logic mem_rsp_error
);
    logic [SOURCE_ID_W-1:0] selected_source;
    logic [SOURCE_ID_W-1:0] rsp_source;
    logic [31:0] rsp_source_u32;
    logic [LOCAL_ID_W-1:0] rsp_local_id;
    logic selected_valid;
    logic rsp_source_valid;

    function automatic logic [SOURCE_ID_W-1:0] first_request(input logic [CLIENTS-1:0] valid);
        int client;
        begin
            first_request = '0;
            for (client = CLIENTS - 1; client >= 0; client--) begin
                if (valid[client]) begin
                    first_request = SOURCE_ID_W'(client);
                end
            end
        end
    endfunction

    initial begin
        if (CLIENTS < 1) $fatal(1, "memory_arbiter requires CLIENTS >= 1");
        if (ADDR_W < 1) $fatal(1, "memory_arbiter requires ADDR_W >= 1");
        if (DATA_W < 8 || (DATA_W % 8) != 0) $fatal(1, "memory_arbiter requires byte-addressable DATA_W");
        if (LOCAL_ID_W < 1) $fatal(1, "memory_arbiter requires LOCAL_ID_W >= 1");
        if (SOURCE_ID_W > 32) $fatal(1, "memory_arbiter supports SOURCE_ID_W <= 32");
    end

    assign selected_valid = |client_req_valid;
    assign selected_source = first_request(client_req_valid);

    assign mem_req_valid = selected_valid;
    assign mem_req_write = client_req_write[selected_source];
    assign mem_req_addr = client_req_addr[(selected_source*ADDR_W) +: ADDR_W];
    assign mem_req_wdata = client_req_wdata[(selected_source*DATA_W) +: DATA_W];
    assign mem_req_wmask = client_req_wmask[(selected_source*MASK_W) +: MASK_W];
    assign mem_req_id = {
        selected_source,
        client_req_id[(selected_source*LOCAL_ID_W) +: LOCAL_ID_W]
    };

    assign rsp_source = mem_rsp_id[MEM_ID_W-1 -: SOURCE_ID_W];
    assign rsp_local_id = mem_rsp_id[LOCAL_ID_W-1:0];
    assign rsp_source_u32 = {{(32-SOURCE_ID_W){1'b0}}, rsp_source};
    assign rsp_source_valid = (rsp_source_u32 < CLIENTS);
    assign mem_rsp_ready = rsp_source_valid ? client_rsp_ready[rsp_source] : 1'b1;

    genvar client_idx;
    generate
        for (client_idx = 0; client_idx < CLIENTS; client_idx++) begin : gen_clients
            assign client_req_ready[client_idx] =
                selected_valid &&
                (selected_source == SOURCE_ID_W'(client_idx)) &&
                mem_req_ready;

            assign client_rsp_valid[client_idx] =
                mem_rsp_valid &&
                rsp_source_valid &&
                (rsp_source == SOURCE_ID_W'(client_idx));

            assign client_rsp_rdata[(client_idx*DATA_W) +: DATA_W] = mem_rsp_rdata;
            assign client_rsp_id[(client_idx*LOCAL_ID_W) +: LOCAL_ID_W] = rsp_local_id;
            assign client_rsp_error[client_idx] = client_rsp_valid[client_idx] && mem_rsp_error;
        end
    endgenerate
endmodule
