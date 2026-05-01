module data_memory_formal (
    input logic clk
);
    localparam int ADDR_W = 4;
    localparam int DATA_W = 32;
    localparam int DEPTH_WORDS = 1;
    localparam int MASK_W = DATA_W / 8;

    logic reset;
    logic req_valid;
    logic req_ready;
    logic req_write;
    logic [ADDR_W-1:0] req_addr;
    logic [DATA_W-1:0] req_wdata;
    logic [MASK_W-1:0] req_wmask;
    logic rsp_valid;
    logic rsp_ready;
    logic [DATA_W-1:0] rsp_rdata;
    logic error;
    logic [3:0] cycle_q;
    logic past_valid;

    data_memory #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH_WORDS(DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wmask(req_wmask),
        .rsp_valid(rsp_valid),
        .rsp_ready(rsp_ready),
        .rsp_rdata(rsp_rdata),
        .error(error)
    );

    initial begin
        cycle_q = '0;
        past_valid = 1'b0;
    end

    always_comb begin
        reset = (cycle_q == 4'd0);
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr = 4'h0;
        req_wdata = '0;
        req_wmask = '0;
        rsp_ready = (cycle_q != 4'd2);

        unique case (cycle_q)
            4'd1: begin
                req_valid = 1'b1;
                req_write = 1'b1;
                req_wdata = 32'hAABB_CCDD;
                req_wmask = 4'b1111;
            end
            4'd3: begin
                req_valid = 1'b1;
                req_write = 1'b1;
                req_wdata = 32'h1122_3344;
                req_wmask = 4'b0101;
            end
            4'd5: begin
                req_valid = 1'b1;
                req_write = 1'b1;
                req_addr = 4'h2;
                req_wdata = 32'h5678_0000;
                req_wmask = 4'b1100;
            end
            4'd7: begin
                req_valid = 1'b1;
                req_write = 1'b0;
            end
            default: begin
                req_valid = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        cycle_q <= cycle_q + 4'd1;

        if (past_valid && $past(reset)) begin
            assert(!rsp_valid);
            assert(rsp_rdata == '0);
            assert(!error);
            assert(req_ready);
        end

        if (past_valid && !reset) begin
            assert(req_ready == (!rsp_valid || rsp_ready));
        end

        if (past_valid && !$past(reset) && !reset && $past(rsp_valid && !rsp_ready)) begin
            assert(rsp_valid);
            assert(rsp_rdata == $past(rsp_rdata));
            assert(error == $past(error));
        end

        if (past_valid && (cycle_q == 4'd2)) begin
            assert(rsp_valid);
            assert(!req_ready);
            assert(!error);
            assert(rsp_rdata == '0);
        end

        if (past_valid && (cycle_q == 4'd8)) begin
            assert(rsp_valid);
            assert(!error);
            assert(rsp_rdata == 32'h5678_CC44);
        end
    end
endmodule
