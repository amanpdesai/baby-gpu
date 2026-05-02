module tb_data_memory;
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int DEPTH_WORDS = 4;
    localparam int MASK_W = DATA_W / 8;

    logic clk;
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
        clk = 1'b0;
        forever #5 clk = !clk;
    end

    task automatic clear_inputs;
        begin
            req_valid = 1'b0;
            req_write = 1'b0;
            req_addr = '0;
            req_wdata = '0;
            req_wmask = '0;
            rsp_ready = 1'b1;
        end
    endtask

    task automatic reset_dut;
        begin
            clear_inputs();
            reset = 1'b1;
            repeat (2) @(posedge clk);
            reset = 1'b0;
            @(negedge clk);
        end
    endtask

    task automatic transact;
        input logic write;
        input logic [ADDR_W-1:0] addr;
        input logic [DATA_W-1:0] wdata;
        input logic [MASK_W-1:0] wmask;
        input logic [DATA_W-1:0] expected_rsp;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = write;
            req_addr = addr;
            req_wdata = wdata;
            req_wmask = wmask;
            rsp_ready = 1'b1;

            @(posedge clk);
            if (!req_ready) begin
                $fatal(1, "request was not accepted");
            end

            @(negedge clk);
            req_valid = 1'b0;
            req_write = 1'b0;
            req_addr = '0;
            req_wdata = '0;
            req_wmask = '0;

            if (!rsp_valid) begin
                $fatal(1, "missing response");
            end
            if (rsp_rdata != expected_rsp) begin
                $fatal(1, "response mismatch: got 0x%08h expected 0x%08h", rsp_rdata, expected_rsp);
            end

            @(posedge clk);
            @(negedge clk);
        end
    endtask

    initial begin
        reset = 1'b0;
        clear_inputs();

        reset_dut();
        transact(1'b1, 8'h00, 32'ha5a55a5a, 4'b1111, 32'h00000000);
        transact(1'b0, 8'h00, 32'h00000000, 4'b0000, 32'ha5a55a5a);
        if (error) begin
            $fatal(1, "unexpected error after aligned full-word access");
        end

        reset_dut();
        transact(1'b1, 8'h00, 32'h11223344, 4'b1111, 32'h00000000);
        transact(1'b1, 8'h00, 32'h0000abcd, 4'b0011, 32'h00000000);
        transact(1'b0, 8'h00, 32'h00000000, 4'b0000, 32'h1122abcd);
        transact(1'b1, 8'h02, 32'h56780000, 4'b1100, 32'h00000000);
        transact(1'b0, 8'h00, 32'h00000000, 4'b0000, 32'h5678abcd);
        transact(1'b1, 8'h00, 32'hffff0000, 4'b0000, 32'h00000000);
        transact(1'b0, 8'h00, 32'h00000000, 4'b0000, 32'h5678abcd);
        if (error) begin
            $fatal(1, "unexpected error after masked writes");
        end

        reset_dut();
        transact(1'b1, 8'h00, 32'hcafebabe, 4'b1111, 32'h00000000);
        @(negedge clk);
        req_valid = 1'b1;
        req_write = 1'b0;
        req_addr = 8'h00;
        req_wdata = '0;
        req_wmask = '0;
        rsp_ready = 1'b0;
        @(posedge clk);
        @(negedge clk);
        req_valid = 1'b0;
        if (!rsp_valid || rsp_rdata != 32'hcafebabe) begin
            $fatal(1, "backpressured response missing initial data");
        end

        req_valid = 1'b1;
        req_write = 1'b1;
        req_addr = 8'h04;
        req_wdata = 32'h12345678;
        req_wmask = 4'b1111;
        repeat (3) begin
            @(posedge clk);
            @(negedge clk);
            if (req_ready) begin
                $fatal(1, "request ready asserted while response backpressured");
            end
            if (!rsp_valid || rsp_rdata != 32'hcafebabe) begin
                $fatal(1, "backpressured response changed");
            end
        end
        req_valid = 1'b0;
        rsp_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        transact(1'b0, 8'h04, 32'h00000000, 4'b0000, 32'h00000000);

        reset_dut();
        transact(1'b1, 8'h00, 32'hfeedface, 4'b1111, 32'h00000000);
        reset_dut();
        transact(1'b0, 8'h00, 32'h00000000, 4'b0000, 32'h00000000);
        if (error) begin
            $fatal(1, "unexpected error after reset-clear check");
        end

        reset_dut();
        transact(1'b0, 8'h01, 32'h00000000, 4'b0000, 32'h00000000);
        if (!error) begin
            $fatal(1, "unaligned access did not raise sticky error");
        end

        reset_dut();
        transact(1'b0, 8'h10, 32'h00000000, 4'b0000, 32'h00000000);
        if (!error) begin
            $fatal(1, "out-of-range access did not raise sticky error");
        end

        reset_dut();
        transact(1'b1, 8'h10, 32'h12345678, 4'b1111, 32'h00000000);
        if (!error) begin
            $fatal(1, "out-of-range write did not raise sticky error");
        end

        $display("tb_data_memory PASS");
        $finish;
    end
endmodule
