module framebuffer_writer_formal;
    // Bounded combinational proof for the RGB565 framebuffer write adapter.
    localparam int ADDR_W = 8;
    localparam int DATA_W = 32;
    localparam int COORD_W = 4;
    localparam int COLOR_W = 16;

    (* anyseq *) logic pixel_valid;
    logic pixel_ready;
    (* anyseq *) logic [COORD_W-1:0] pixel_x;
    (* anyseq *) logic [COORD_W-1:0] pixel_y;
    (* anyseq *) logic [COLOR_W-1:0] pixel_color;
    (* anyseq *) logic [ADDR_W-1:0] fb_base;
    (* anyseq *) logic [COORD_W-1:0] fb_width;
    (* anyseq *) logic [COORD_W-1:0] fb_height;
    (* anyseq *) logic [ADDR_W-1:0] stride_bytes;
    logic mem_req_valid;
    (* anyseq *) logic mem_req_ready;
    logic mem_req_write;
    logic [ADDR_W-1:0] mem_req_addr;
    logic [DATA_W-1:0] mem_req_wdata;
    logic [(DATA_W/8)-1:0] mem_req_wmask;

    logic in_bounds;
    logic [ADDR_W-1:0] expected_byte_addr;

    assign in_bounds = (pixel_x < fb_width) && (pixel_y < fb_height);
    assign expected_byte_addr = fb_base + (ADDR_W'(pixel_y) * stride_bytes) + (ADDR_W'(pixel_x) << 1);

    framebuffer_writer #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COORD_W(COORD_W),
        .COLOR_W(COLOR_W)
    ) dut (
        .pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_color(pixel_color),
        .fb_base(fb_base),
        .fb_width(fb_width),
        .fb_height(fb_height),
        .stride_bytes(stride_bytes),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wmask(mem_req_wmask)
    );

    always_comb begin
        assert(mem_req_write);
        assert(mem_req_valid == (pixel_valid && in_bounds));
        assert(pixel_ready == (in_bounds ? mem_req_ready : 1'b1));
        assert(mem_req_addr == {expected_byte_addr[ADDR_W-1:2], 2'b00});

        if (expected_byte_addr[1]) begin
            assert(mem_req_wdata == {pixel_color, 16'h0000});
            assert(mem_req_wmask == 4'b1100);
        end else begin
            assert(mem_req_wdata == {16'h0000, pixel_color});
            assert(mem_req_wmask == 4'b0011);
        end
    end
endmodule
