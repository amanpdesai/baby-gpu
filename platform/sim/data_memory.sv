module data_memory #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int DEPTH_WORDS = 1024,
    localparam int MASK_W = DATA_W / 8
) (
    input  logic                  clk,
    input  logic                  reset,

    input  logic                  req_valid,
    output logic                  req_ready,
    input  logic                  req_write,
    input  logic [ADDR_W-1:0]     req_addr,
    input  logic [DATA_W-1:0]     req_wdata,
    input  logic [MASK_W-1:0]     req_wmask,

    output logic                  rsp_valid,
    input  logic                  rsp_ready,
    output logic [DATA_W-1:0]     rsp_rdata,

    output logic                  error
);
    logic [DATA_W-1:0] mem [0:DEPTH_WORDS-1];

    logic              rsp_valid_q;
    logic [DATA_W-1:0] rsp_rdata_q;
    logic              error_q;

    logic [ADDR_W-1:0] req_word_addr;
    logic              req_index_in_range;
    logic              req_unaligned;
    logic              req_out_of_range;
    logic              req_error;
    logic              req_halfword_write;
    logic              req_fire;

    assign rsp_valid = rsp_valid_q;
    assign rsp_rdata = rsp_rdata_q;
    assign error = error_q;

    // Blocking one-request memory. A request accepted on cycle N returns a
    // response on cycle N+1. While a response is backpressured, request ready
    // drops and response payload remains stable.
    assign req_ready = !rsp_valid_q || rsp_ready;
    assign req_fire = req_valid && req_ready;

    assign req_word_addr = req_addr >> 2;
    assign req_halfword_write = req_write && (req_wmask == 4'b0011 || req_wmask == 4'b1100);
    assign req_unaligned = req_halfword_write ? req_addr[0] : (req_addr[1:0] != 2'b00);
    assign req_index_in_range = req_word_addr < ADDR_W'(DEPTH_WORDS);
    assign req_out_of_range = !req_index_in_range;
    assign req_error = req_unaligned || req_out_of_range;

    initial begin
        if (DATA_W != 32) begin
            $fatal(1, "data_memory currently supports DATA_W=32 only");
        end
        if (ADDR_W < 2) begin
            $fatal(1, "data_memory requires ADDR_W >= 2");
        end
        if (ADDR_W > 32) begin
            $fatal(1, "data_memory supports ADDR_W <= 32");
        end
        if (DEPTH_WORDS > (1 << (ADDR_W - 2))) begin
            $fatal(1, "data_memory DEPTH_WORDS must fit in ADDR_W byte address space");
        end
        if (DEPTH_WORDS <= 0) begin
            $fatal(1, "data_memory requires DEPTH_WORDS > 0");
        end
    end

    genvar word_g;
    generate
        for (word_g = 0; word_g < DEPTH_WORDS; word_g++) begin : gen_mem_word
            int byte_i;

            always_ff @(posedge clk) begin
                if (reset) begin
                    mem[word_g] <= '0;
                end else if (req_fire && !req_error && req_write && req_word_addr == ADDR_W'(word_g)) begin
                    for (byte_i = 0; byte_i < MASK_W; byte_i++) begin
                        if (req_wmask[byte_i]) begin
                            mem[word_g][(byte_i * 8) +: 8] <= req_wdata[(byte_i * 8) +: 8];
                        end
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (reset) begin
            rsp_valid_q <= 1'b0;
            rsp_rdata_q <= '0;
            error_q <= 1'b0;
        end else if (req_fire) begin
            rsp_valid_q <= 1'b1;
            error_q <= error_q || req_error;

            if (req_error) begin
                rsp_rdata_q <= '0;
            end else if (req_write) begin
                rsp_rdata_q <= '0;
            end else begin
                rsp_rdata_q <= mem[req_word_addr];
            end
        end else if (rsp_ready) begin
            rsp_valid_q <= 1'b0;
        end
    end
endmodule
