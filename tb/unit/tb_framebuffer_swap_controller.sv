module tb_framebuffer_swap_controller;
    localparam int ADDR_W = 32;
    localparam logic [ADDR_W-1:0] FRONT0 = 32'h0000_1000;
    localparam logic [ADDR_W-1:0] BACK0 = 32'h0000_2000;

    logic clk;
    logic rst_n;
    logic swap_request;
    logic swap_ready;
    logic frame_boundary;
    logic [ADDR_W-1:0] front_base;
    logic [ADDR_W-1:0] back_base;
    logic swap_pending;
    logic swap_pulse;
    int errors;

    framebuffer_swap_controller #(
        .ADDR_W(ADDR_W),
        .FRONT_BASE_RESET(FRONT0),
        .BACK_BASE_RESET(BACK0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .swap_request(swap_request),
        .swap_ready(swap_ready),
        .frame_boundary(frame_boundary),
        .front_base(front_base),
        .back_base(back_base),
        .swap_pending(swap_pending),
        .swap_pulse(swap_pulse)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
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
            rst_n = 1'b0;
            swap_request = 1'b0;
            frame_boundary = 1'b0;
            repeat (2) tick();
            rst_n = 1'b1;
            tick();

            check(front_base == FRONT0, "reset loads front base");
            check(back_base == BACK0, "reset loads back base");
            check(swap_ready, "reset leaves swap ready");
            check(!swap_pending, "reset clears pending swap");
            check(!swap_pulse, "reset clears swap pulse");
        end
    endtask

    task automatic request_swap;
        begin
            check(swap_ready, "swap request accepted only when ready");
            swap_request = 1'b1;
            tick();
            swap_request = 1'b0;
        end
    endtask

    task automatic pulse_frame_boundary;
        begin
            frame_boundary = 1'b1;
            tick();
            frame_boundary = 1'b0;
        end
    endtask

    task automatic test_deferred_swap;
        begin
            reset_dut();
            request_swap();
            check(swap_pending, "swap remains pending before frame boundary");
            check(!swap_ready, "pending swap deasserts ready");
            check(front_base == FRONT0, "front base does not change before frame boundary");
            check(back_base == BACK0, "back base does not change before frame boundary");

            pulse_frame_boundary();
            check(swap_pulse, "frame boundary commits pending swap");
            check(!swap_pending, "committed swap clears pending");
            check(swap_ready, "committed swap restores ready");
            check(front_base == BACK0, "committed swap updates front base");
            check(back_base == FRONT0, "committed swap updates back base");

            tick();
            check(!swap_pulse, "swap pulse is one cycle");
        end
    endtask

    task automatic test_request_ignored_while_pending;
        begin
            reset_dut();
            request_swap();
            check(!swap_ready, "pending swap blocks second request");
            swap_request = 1'b1;
            tick();
            swap_request = 1'b0;
            check(swap_pending, "second request while pending does not clear first");
            check(front_base == FRONT0, "blocked second request does not change front base");
            check(back_base == BACK0, "blocked second request does not change back base");

            pulse_frame_boundary();
            check(front_base == BACK0, "original pending swap still commits");
            check(back_base == FRONT0, "original pending swap preserves back base");
        end
    endtask

    task automatic test_same_cycle_request_and_boundary;
        begin
            reset_dut();
            swap_request = 1'b1;
            frame_boundary = 1'b1;
            tick();
            swap_request = 1'b0;
            frame_boundary = 1'b0;

            check(swap_pulse, "same-cycle request and boundary commits immediately");
            check(!swap_pending, "same-cycle commit leaves no pending swap");
            check(swap_ready, "same-cycle commit remains ready");
            check(front_base == BACK0, "same-cycle commit updates front base");
            check(back_base == FRONT0, "same-cycle commit updates back base");
        end
    endtask

    task automatic test_reset_clears_pending;
        begin
            reset_dut();
            request_swap();
            check(swap_pending, "swap pending before reset");
            rst_n = 1'b0;
            tick();
            rst_n = 1'b1;
            tick();

            check(front_base == FRONT0, "reset restores front base after pending swap");
            check(back_base == BACK0, "reset restores back base after pending swap");
            check(!swap_pending, "reset clears pending swap");
            check(swap_ready, "reset restores ready after pending swap");
            check(!swap_pulse, "reset clears pulse after pending swap");
        end
    endtask

    initial begin
        errors = 0;

        test_deferred_swap();
        test_request_ignored_while_pending();
        test_same_cycle_request_and_boundary();
        test_reset_clears_pending();

        if (errors == 0) begin
            $display("PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
