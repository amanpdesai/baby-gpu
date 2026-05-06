module tb_framebuffer_scanout_arbiter;
    localparam int CLIENTS = 2;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int COORD_W = 8;
    localparam int COLOR_W = 16;
    localparam int LOCAL_ID_W = 1;
    localparam int MASK_W = DATA_W / 8;
    localparam int SOURCE_ID_W = 1;
    localparam int MEM_ID_W = SOURCE_ID_W + LOCAL_ID_W;

    logic clk;
    logic rst_n;
    logic writer_pixel_valid;
    logic writer_pixel_ready;
    logic [COORD_W-1:0] writer_pixel_x;
    logic [COORD_W-1:0] writer_pixel_y;
    logic [COLOR_W-1:0] writer_pixel_color;
    logic writer_req_valid;
    logic writer_req_ready;
    logic writer_req_write;
    logic [ADDR_W-1:0] writer_req_addr;
    logic [DATA_W-1:0] writer_req_wdata;
    logic [MASK_W-1:0] writer_req_wmask;

    logic scanout_start_valid;
    logic scanout_start_ready;
    logic scanout_busy;
    logic scanout_done;
    logic scanout_error;
    logic scanout_pixel_valid;
    logic scanout_pixel_ready;
    logic [COORD_W-1:0] scanout_pixel_x;
    logic [COORD_W-1:0] scanout_pixel_y;
    logic [COLOR_W-1:0] scanout_pixel_color;
    logic scanout_req_valid;
    logic scanout_req_ready;
    logic scanout_req_write;
    logic [ADDR_W-1:0] scanout_req_addr;
    logic [DATA_W-1:0] scanout_req_wdata;
    logic [MASK_W-1:0] scanout_req_wmask;
    logic [LOCAL_ID_W-1:0] scanout_req_id;
    logic scanout_rsp_valid;
    logic scanout_rsp_ready;
    logic [DATA_W-1:0] scanout_rsp_rdata;
    logic [LOCAL_ID_W-1:0] scanout_rsp_id;
    logic scanout_rsp_error;

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
    int errors;

    framebuffer_writer #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W)
    ) writer (
        .pixel_valid(writer_pixel_valid),
        .pixel_ready(writer_pixel_ready),
        .pixel_x(writer_pixel_x),
        .pixel_y(writer_pixel_y),
        .pixel_color(writer_pixel_color),
        .fb_base(32'h0000_4000),
        .fb_width(8'd4),
        .fb_height(8'd1),
        .stride_bytes(32'd8),
        .mem_req_valid(writer_req_valid),
        .mem_req_ready(writer_req_ready),
        .mem_req_write(writer_req_write),
        .mem_req_addr(writer_req_addr),
        .mem_req_wdata(writer_req_wdata),
        .mem_req_wmask(writer_req_wmask)
    );

    framebuffer_scanout #(
        .FRAME_WIDTH(2),
        .FRAME_HEIGHT(1),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W),
        .LOCAL_ID_W(LOCAL_ID_W)
    ) scanout (
        .clk(clk),
        .rst_n(rst_n),
        .start_valid(scanout_start_valid),
        .start_ready(scanout_start_ready),
        .fb_base(32'h0000_4000),
        .stride_bytes(32'd8),
        .busy(scanout_busy),
        .done(scanout_done),
        .error(scanout_error),
        .pixel_valid(scanout_pixel_valid),
        .pixel_ready(scanout_pixel_ready),
        .pixel_x(scanout_pixel_x),
        .pixel_y(scanout_pixel_y),
        .pixel_color(scanout_pixel_color),
        .mem_req_valid(scanout_req_valid),
        .mem_req_ready(scanout_req_ready),
        .mem_req_write(scanout_req_write),
        .mem_req_addr(scanout_req_addr),
        .mem_req_wdata(scanout_req_wdata),
        .mem_req_wmask(scanout_req_wmask),
        .mem_req_id(scanout_req_id),
        .mem_rsp_valid(scanout_rsp_valid),
        .mem_rsp_ready(scanout_rsp_ready),
        .mem_rsp_rdata(scanout_rsp_rdata),
        .mem_rsp_id(scanout_rsp_id),
        .mem_rsp_error(scanout_rsp_error)
    );

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

    assign client_req_valid = {scanout_req_valid, writer_req_valid};
    assign client_req_write = {scanout_req_write, writer_req_write};
    assign client_req_addr = {scanout_req_addr, writer_req_addr};
    assign client_req_wdata = {scanout_req_wdata, writer_req_wdata};
    assign client_req_wmask = {scanout_req_wmask, writer_req_wmask};
    assign client_req_id = {scanout_req_id, 1'b0};
    assign writer_req_ready = client_req_ready[0];
    assign scanout_req_ready = client_req_ready[1];
    assign client_rsp_ready = {scanout_rsp_ready, 1'b1};
    assign scanout_rsp_valid = client_rsp_valid[1];
    assign scanout_rsp_rdata = client_rsp_rdata[(1*DATA_W) +: DATA_W];
    assign scanout_rsp_id = client_rsp_id[(1*LOCAL_ID_W) +: LOCAL_ID_W];
    assign scanout_rsp_error = client_rsp_error[1];

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

    initial begin
        errors = 0;
        rst_n = 1'b0;
        writer_pixel_valid = 1'b0;
        writer_pixel_x = 8'd1;
        writer_pixel_y = 8'd0;
        writer_pixel_color = 16'h7E0F;
        scanout_start_valid = 1'b0;
        scanout_pixel_ready = 1'b1;
        mem_req_ready = 1'b0;
        mem_rsp_valid = 1'b0;
        mem_rsp_rdata = '0;
        mem_rsp_id = '0;
        mem_rsp_error = 1'b0;
        tick();
        rst_n = 1'b1;
        tick();

        writer_pixel_valid = 1'b1;
        scanout_start_valid = 1'b1;
        tick();
        scanout_start_valid = 1'b0;
        settle();

        check(writer_req_valid, "writer request valid during contention");
        check(scanout_req_valid, "scanout request valid during contention");
        check(mem_req_valid, "arbiter exposes contended request");
        check(mem_req_write, "writer wins first round-robin slot");
        check(mem_req_addr == 32'h0000_4000, "writer request address");
        check(mem_req_wdata == {16'h7E0F, 16'h0000}, "writer high-half data");
        check(mem_req_wmask == 4'b1100, "writer high-half mask");
        check(mem_req_id == 2'b00, "writer request source ID");

        mem_req_ready = 1'b1;
        settle();
        check(writer_pixel_ready, "writer accepted by arbiter");
        tick();
        mem_req_ready = 1'b0;
        writer_pixel_valid = 1'b0;
        settle();

        check(mem_req_valid, "scanout request follows writer");
        check(!mem_req_write, "scanout request is read");
        check(mem_req_addr == 32'h0000_4000, "scanout request address");
        check(mem_req_id == 2'b10, "scanout request source ID");
        mem_req_ready = 1'b1;
        tick();
        mem_req_ready = 1'b0;
        settle();

        check(scanout_rsp_ready, "scanout waits for routed response");
        mem_rsp_rdata = 32'h2222_1111;
        mem_rsp_id = 2'b10;
        mem_rsp_valid = 1'b1;
        tick();
        mem_rsp_valid = 1'b0;
        settle();

        check(scanout_pixel_valid, "scanout emits first routed pixel");
        check(scanout_pixel_x == 8'd0, "first pixel x");
        check(scanout_pixel_color == 16'h1111, "first pixel color");
        tick();
        check(scanout_pixel_valid, "scanout emits second routed pixel");
        check(scanout_pixel_x == 8'd1, "second pixel x");
        check(scanout_pixel_color == 16'h2222, "second pixel color");
        tick();
        check(scanout_done, "scanout completes after routed response");
        check(!scanout_error, "routed response has no scanout error");
        check(!client_rsp_valid[0], "writer client receives no scanout response");

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
