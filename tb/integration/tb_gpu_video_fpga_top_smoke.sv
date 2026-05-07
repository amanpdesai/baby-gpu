module tb_gpu_video_fpga_top_smoke;
    logic clk;
    logic rst_n;
    logic [3:0] sw;
    logic [1:0] btn;
    logic hsync;
    logic vsync;
    logic [4:0] vga_r;
    logic [5:0] vga_g;
    logic [4:0] vga_b;
    logic active;
    logic frame_start;
    logic gpu_busy;
    logic [7:0] gpu_error_status;
    int active_seen;
    int frame_start_seen;
    int errors;

    gpu_video_fpga_top #(
        .H_ACTIVE(4),
        .H_FRONT(1),
        .H_SYNC(1),
        .H_BACK(1),
        .V_ACTIVE(3),
        .V_FRONT(1),
        .V_SYNC(1),
        .V_BACK(1),
        .COORD_W(4),
        .CHECKER_SHIFT(1),
        .DEPTH_WORDS(64)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sw(sw),
        .btn(btn),
        .hsync(hsync),
        .vsync(vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .active(active),
        .frame_start(frame_start),
        .gpu_busy(gpu_busy),
        .gpu_error_status(gpu_error_status)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    initial begin
        errors = 0;
        active_seen = 0;
        frame_start_seen = 0;
        rst_n = 1'b0;
        sw = 4'b0000;
        btn = 2'b00;

        repeat (3) tick();
        rst_n = 1'b1;

        repeat (80) begin
            tick();
            if (active) begin
                active_seen++;
                check(vga_r == 5'h00, "solid green pattern drives zero red");
                check(vga_g == 6'h3f, "solid green pattern drives max green");
                check(vga_b == 5'h00, "solid green pattern drives zero blue");
            end
            if (frame_start) begin
                frame_start_seen++;
            end
            check(gpu_error_status == 8'h00, "stubbed FPGA top reports no GPU error");
        end

        check(active_seen >= 12, "FPGA top emits active video pixels");
        check(frame_start_seen >= 1, "FPGA top emits frame start");

        if (errors == 0) begin
            $display("tb_gpu_video_fpga_top_smoke PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
