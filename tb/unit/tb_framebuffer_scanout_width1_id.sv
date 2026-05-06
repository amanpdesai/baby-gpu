module tb_framebuffer_scanout_width1_id;
    localparam int FRAME_WIDTH = 1;
    localparam int FRAME_HEIGHT = 1;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 8;
    localparam int COLOR_W = 16;
    localparam int LOCAL_ID_W = 3;
    localparam int MASK_W = DATA_W / 8;

    logic clk;
    logic rst_n;
    logic start_valid;
    logic start_ready;
    logic [ADDR_W-1:0] fb_base;
    logic [ADDR_W-1:0] stride_bytes;
    logic busy;
    logic done;
    logic error;
    logic pixel_valid;
    logic pixel_ready;
    logic [COORD_W-1:0] pixel_x;
    logic [COORD_W-1:0] pixel_y;
    logic [COLOR_W-1:0] pixel_color;
    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [MASK_W-1:0] mem_req_wmask;
    logic [LOCAL_ID_W-1:0] mem_req_id;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [DATA_W-1:0] mem_rsp_rdata;
    logic [LOCAL_ID_W-1:0] mem_rsp_id;
    logic mem_rsp_error;
    int errors;

    framebuffer_scanout #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_valid(start_valid),
        .start_ready(start_ready),
        .fb_base(fb_base),
        .stride_bytes(stride_bytes),
        .busy(busy),
        .done(done),
        .error(error),
        .pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_color(pixel_color),
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

    task automatic reset_dut;
        begin
            start_valid = 1'b0;
            fb_base = 32'h0000_3002;
            stride_bytes = 32'd2;
            pixel_ready = 1'b1;
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

    initial begin
        errors = 0;
        reset_dut();

        start_valid = 1'b1;
        tick();
        start_valid = 1'b0;
        settle();

        check(mem_req_valid, "width1 request valid");
        check(mem_req_addr == 32'h0000_3002, "width1 starts at framebuffer base");
        check(mem_req_id == 3'b000, "width1 request ID zero extended to LOCAL_ID_W");
        mem_req_ready = 1'b1;
        tick();
        mem_req_ready = 1'b0;
        settle();

        check(mem_rsp_ready, "width1 waits for response");
        mem_rsp_rdata = 32'hDEAD_5A5A;
        mem_rsp_id = 3'b101;
        mem_rsp_error = 1'b0;
        mem_rsp_valid = 1'b1;
        tick();
        mem_rsp_valid = 1'b0;
        settle();

        check(pixel_valid, "width1 emits low-half pixel");
        check(pixel_x == 8'd0, "width1 pixel x");
        check(pixel_y == 8'd0, "width1 pixel y");
        check(pixel_color == 16'h5A5A, "width1 uses low halfword");
        tick();

        check(done, "width1 frame completes after one pixel");
        check(!busy, "width1 returns idle");
        check(error, "mismatched response ID sets sticky error");

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
