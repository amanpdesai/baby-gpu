module tb_framebuffer_scanout_even_width;
    localparam int FRAME_WIDTH = 4;
    localparam int FRAME_HEIGHT = 1;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 8;
    localparam int COLOR_W = 16;
    localparam int LOCAL_ID_W = 1;
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
            fb_base = 32'h0000_2000;
            stride_bytes = 32'd8;
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

    task automatic start_frame;
        begin
            check(start_ready, "idle scanout accepts start");
            start_valid = 1'b1;
            tick();
            start_valid = 1'b0;
            settle();
            check(busy, "scanout is busy after start");
        end
    endtask

    task automatic accept_request(input logic [ADDR_W-1:0] expected_addr);
        begin
            settle();
            check(mem_req_valid, "request valid");
            check(!mem_req_write, "request is a read");
            check(mem_req_addr == expected_addr, "request address");
            check(mem_req_wdata == '0, "read request write data zero");
            check(mem_req_wmask == '0, "read request mask zero");
            check(mem_req_id == '0, "request ID zero");
            mem_req_ready = 1'b1;
            tick();
            mem_req_ready = 1'b0;
            settle();
        end
    endtask

    task automatic return_word(input logic [DATA_W-1:0] word);
        begin
            check(mem_rsp_ready, "scanout ready for response");
            mem_rsp_rdata = word;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;
            settle();
        end
    endtask

    task automatic expect_pixel(
        input logic [COORD_W-1:0] x,
        input logic [COLOR_W-1:0] color,
        input string label
    );
        begin
            settle();
            check(pixel_valid, {label, " valid"});
            check(pixel_x == x, {label, " x"});
            check(pixel_y == 8'd0, {label, " y"});
            check(pixel_color == color, {label, " color"});
            tick();
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();
        start_frame();

        accept_request(32'h0000_2000);
        return_word(32'h2222_1111);
        expect_pixel(8'd0, 16'h1111, "pixel0");
        expect_pixel(8'd1, 16'h2222, "pixel1");

        accept_request(32'h0000_2004);
        return_word(32'h4444_3333);
        expect_pixel(8'd2, 16'h3333, "pixel2");
        expect_pixel(8'd3, 16'h4444, "pixel3");
        check(done, "even-width high half completes frame");
        check(!busy, "scanout returns idle");
        check(!error, "clean even-width frame has no error");

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
