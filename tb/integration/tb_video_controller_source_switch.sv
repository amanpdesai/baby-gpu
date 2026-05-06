module tb_video_controller_source_switch;
    localparam int COORD_W = 4;
    localparam int ADDR_W = 32;
    localparam int DATA_W = 32;
    localparam int MASK_W = DATA_W / 8;
    localparam int LOCAL_ID_W = 1;
    localparam int FIFO_COUNT_W = 1;

    logic clk;
    logic rst_n;
    logic tick_enable;
    logic source_select;
    logic scanout_start_valid;
    logic fifo_flush;
    logic scanout_start_ready;
    logic scanout_busy;
    logic scanout_done;
    logic scanout_error;
    logic fifo_full;
    logic fifo_empty;
    logic [FIFO_COUNT_W-1:0] fifo_count;
    logic fifo_overflow;
    logic fifo_underflow;
    logic framebuffer_underrun;
    logic framebuffer_coordinate_mismatch;
    logic source_missing;
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
    logic pixel_valid;
    logic active;
    logic line_start;
    logic frame_start;
    logic hsync;
    logic vsync;
    logic [COORD_W-1:0] x;
    logic [COORD_W-1:0] y;
    logic [15:0] rgb;
    logic sampled_pixel_valid;
    logic sampled_active;
    logic [COORD_W-1:0] sampled_x;
    logic [COORD_W-1:0] sampled_y;
    logic [15:0] sampled_rgb;
    logic sampled_source_missing;
    logic sampled_framebuffer_underrun;
    logic sampled_framebuffer_coordinate_mismatch;
    integer errors;

    video_controller #(
        .H_ACTIVE(2),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(1),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .COORD_W(COORD_W),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .LOCAL_ID_W(LOCAL_ID_W),
        .FIFO_DEPTH(1),
        .FIFO_COUNT_W(FIFO_COUNT_W),
        .CHECKER_SHIFT(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick_enable(tick_enable),
        .source_select(source_select),
        .pattern_select(2'd0),
        .solid_rgb(16'h0A5C),
        .scanout_start_valid(scanout_start_valid),
        .scanout_start_ready(scanout_start_ready),
        .fb_base(32'h0000_A000),
        .stride_bytes(32'd4),
        .fifo_flush(fifo_flush),
        .scanout_busy(scanout_busy),
        .scanout_done(scanout_done),
        .scanout_error(scanout_error),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_count(fifo_count),
        .fifo_overflow(fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .framebuffer_underrun(framebuffer_underrun),
        .framebuffer_coordinate_mismatch(framebuffer_coordinate_mismatch),
        .source_missing(source_missing),
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
        .mem_rsp_error(mem_rsp_error),
        .pixel_valid(pixel_valid),
        .active(active),
        .line_start(line_start),
        .frame_start(frame_start),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
        .rgb(rgb)
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sampled_pixel_valid <= 1'b0;
            sampled_active <= 1'b0;
            sampled_x <= '0;
            sampled_y <= '0;
            sampled_rgb <= 16'h0000;
            sampled_source_missing <= 1'b0;
            sampled_framebuffer_underrun <= 1'b0;
            sampled_framebuffer_coordinate_mismatch <= 1'b0;
        end else begin
            sampled_pixel_valid <= pixel_valid;
            sampled_active <= active;
            sampled_x <= x;
            sampled_y <= y;
            sampled_rgb <= rgb;
            sampled_source_missing <= source_missing;
            sampled_framebuffer_underrun <= framebuffer_underrun;
            sampled_framebuffer_coordinate_mismatch <= framebuffer_coordinate_mismatch;
        end
    end

    task automatic check(input logic condition, input string message);
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

    task automatic reset_dut;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            tick_enable = 1'b0;
            source_select = 1'b0;
            scanout_start_valid = 1'b0;
            fifo_flush = 1'b0;
            mem_req_ready = 1'b1;
            mem_rsp_valid = 1'b0;
            mem_rsp_rdata = '0;
            mem_rsp_id = '0;
            mem_rsp_error = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            #1;
        end
    endtask

    task automatic start_scanout_while_pattern_selected;
        begin
            scanout_start_valid = 1'b1;
            tick();
            scanout_start_valid = 1'b0;
            check(mem_req_valid, "scanout can run while pattern selected");
            check(mem_req_addr == 32'h0000_A000, "scanout request uses framebuffer base");
            tick();

            mem_rsp_rdata = 32'hBBBB_AAAA;
            mem_rsp_id = '0;
            mem_rsp_valid = 1'b1;
            tick();
            mem_rsp_valid = 1'b0;
            tick();

            check(fifo_full, "fifo retains framebuffer pixel while pattern selected");
            check(scanout_busy, "scanout remains busy while fifo is not consumed");
            check(!framebuffer_underrun, "pattern mode gates framebuffer underrun");
            check(!source_missing, "pattern mode does not report missing framebuffer source");
        end
    endtask

    task automatic check_pattern_output_before_switch;
        begin
            tick_enable = 1'b1;
            #1;
            check(pixel_valid, "pattern output valid before source switch");
            check(active, "pattern output active before source switch");
            check(x == 4'd0, "pattern output starts at x0");
            check(rgb == 16'h0A5C, "pattern output uses solid color before source switch");
            check(!framebuffer_underrun, "pattern output still gates framebuffer underrun");
            check(!source_missing, "pattern output does not report missing framebuffer source");
            check(fifo_full, "pattern active sample leaves stale framebuffer pixel buffered");
            check(fifo_count == 1'b1, "pattern active sample leaves fifo count unchanged");
            tick();
            check(sampled_pixel_valid, "clocked pattern sample was valid");
            check(sampled_active, "clocked pattern sample was active");
            check(sampled_x == 4'd0, "clocked pattern sample used x0");
            check(sampled_rgb == 16'h0A5C, "clocked pattern sample used solid color");
            check(!sampled_framebuffer_underrun, "clocked pattern sample had no framebuffer underrun");
            check(!sampled_source_missing, "clocked pattern sample had no source missing");
            check(!fifo_underflow, "clocked pattern sample does not pop empty fifo");
            check(fifo_full, "clocked pattern pixel does not consume framebuffer fifo");
            check(fifo_count == 1'b1, "clocked pattern pixel leaves fifo count unchanged");
            check(scanout_busy, "scanout remains backpressured by full fifo after pattern pixel");
            tick_enable = 1'b0;
        end
    endtask

    task automatic flush_and_switch_to_framebuffer;
        begin
            fifo_flush = 1'b1;
            tick();
            fifo_flush = 1'b0;
            #1;
            check(fifo_empty, "fifo flush clears stale pattern-mode framebuffer pixel");

            source_select = 1'b1;
            check(framebuffer_underrun == 1'b0, "idle timing has no underrun after switch");
            tick();
            check(fifo_full, "framebuffer switch refills fifo with held scanout pixel");
            check(fifo_count == 1'b1, "framebuffer switch captures one held pixel");
            check(scanout_done, "held scanout pixel completes scanout after switch");

            tick_enable = 1'b1;
            #1;
            check(pixel_valid, "framebuffer output valid after switch");
            check(active, "framebuffer output active after switch");
            check(x == 4'd1, "framebuffer output resumes at timing x1 after switch");
            check(rgb == 16'hBBBB, "framebuffer output uses held high-halfword pixel after switch");
            check(!source_missing, "framebuffer output has source after switch");
            check(!framebuffer_underrun, "framebuffer output has no underrun after switch");
            check(!framebuffer_coordinate_mismatch, "framebuffer output has no coordinate mismatch after switch");
            tick();
            check(sampled_pixel_valid, "clocked framebuffer sample was valid after switch");
            check(sampled_active, "clocked framebuffer sample was active after switch");
            check(sampled_x == 4'd1, "clocked framebuffer sample used x1 after switch");
            check(sampled_y == 4'd0, "clocked framebuffer sample used y0 after switch");
            check(sampled_rgb == 16'hBBBB, "clocked framebuffer sample used held high-halfword pixel");
            check(!sampled_source_missing, "clocked framebuffer sample had source after switch");
            check(!sampled_framebuffer_underrun, "clocked framebuffer sample had no underrun after switch");
            check(!sampled_framebuffer_coordinate_mismatch, "clocked framebuffer sample had no coordinate mismatch after switch");
            tick_enable = 1'b0;
            check(fifo_empty, "framebuffer output drains refilled fifo");
        end
    endtask

    initial begin
        errors = 0;
        reset_dut();
        start_scanout_while_pattern_selected();
        check_pattern_output_before_switch();
        flush_and_switch_to_framebuffer();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
