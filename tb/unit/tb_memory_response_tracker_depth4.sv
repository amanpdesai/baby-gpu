module tb_memory_response_tracker_depth4;
    localparam int ID_W = 4;
    localparam int DEPTH = 4;
    localparam int COUNT_W = $clog2(DEPTH + 1);

    logic clk;
    logic reset;
    logic clear_errors;
    logic req_fire;
    logic [ID_W-1:0] req_id;
    logic rsp_fire;
    logic [ID_W-1:0] rsp_id;
    logic empty;
    logic full;
    logic [COUNT_W-1:0] outstanding_count;
    logic overflow_error;
    logic underflow_error;
    logic error;
    int errors;

    memory_response_tracker #(
        .ID_W(ID_W),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .clear_errors(clear_errors),
        .req_fire(req_fire),
        .req_id(req_id),
        .rsp_fire(rsp_fire),
        .rsp_id(rsp_id),
        .empty(empty),
        .full(full),
        .outstanding_count(outstanding_count),
        .overflow_error(overflow_error),
        .underflow_error(underflow_error),
        .error(error)
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

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic drive_cycle(
        input bit do_req,
        input logic [ID_W-1:0] id,
        input bit do_rsp
    );
        begin
            req_fire = do_req;
            req_id = id;
            rsp_fire = do_rsp;
            step();
            req_fire = 1'b0;
            req_id = '0;
            rsp_fire = 1'b0;
            #1;
        end
    endtask

    task automatic reset_dut;
        begin
            clear_errors = 1'b0;
            req_fire = 1'b0;
            req_id = '0;
            rsp_fire = 1'b0;
            reset = 1'b1;
            repeat (2) step();
            reset = 1'b0;
            step();

            check(empty, "reset leaves tracker empty");
            check(!full, "reset clears full");
            check(outstanding_count == '0, "reset clears outstanding count");
            check(rsp_id == '0, "reset exposes zero response ID");
            check(!error, "reset clears errors");
        end
    endtask

    task automatic push_expect(
        input logic [ID_W-1:0] id,
        input logic [ID_W-1:0] expected_head,
        input logic [COUNT_W-1:0] expected_count,
        input bit expected_full,
        input string label
    );
        begin
            drive_cycle(1'b1, id, 1'b0);
            check(rsp_id == expected_head, {label, " preserves oldest visible ID"});
            check(outstanding_count == expected_count, {label, " updates count"});
            check(full == expected_full, {label, " updates full flag"});
            check(!empty, {label, " leaves tracker nonempty"});
            check(!error, {label, " does not set error"});
        end
    endtask

    task automatic pop_expect(
        input logic [ID_W-1:0] expected_next,
        input logic [COUNT_W-1:0] expected_count,
        input bit expected_empty,
        input string label
    );
        begin
            drive_cycle(1'b0, '0, 1'b1);
            check(rsp_id == expected_next, {label, " exposes next response ID"});
            check(outstanding_count == expected_count, {label, " updates count"});
            check(empty == expected_empty, {label, " updates empty flag"});
            check(!full, {label, " clears full when appropriate"});
            check(!error, {label, " does not set error"});
        end
    endtask

    task automatic test_depth_four_wraparound;
        begin
            reset_dut();

            push_expect(4'ha, 4'ha, COUNT_W'(1), 1'b0, "push A");
            push_expect(4'hb, 4'ha, COUNT_W'(2), 1'b0, "push B");
            push_expect(4'hc, 4'ha, COUNT_W'(3), 1'b0, "push C");
            push_expect(4'hd, 4'ha, COUNT_W'(4), 1'b1, "push D fills");

            drive_cycle(1'b1, 4'he, 1'b0);
            check(overflow_error, "push while full sets overflow");
            check(error, "overflow contributes to aggregate error");
            check(full, "overflow leaves tracker full");
            check(outstanding_count == COUNT_W'(4), "overflow preserves count");
            check(rsp_id == 4'ha, "overflow does not corrupt head ID");

            clear_errors = 1'b1;
            step();
            clear_errors = 1'b0;
            check(!error, "clear_errors clears overflow");
            check(full, "clear_errors preserves full state");
            check(rsp_id == 4'ha, "clear_errors preserves queued head");

            drive_cycle(1'b1, 4'he, 1'b1);
            check(full, "simultaneous pop/push keeps full tracker full");
            check(outstanding_count == COUNT_W'(4), "simultaneous pop/push keeps count");
            check(rsp_id == 4'hb, "simultaneous pop/push exposes second queued ID");
            check(!error, "simultaneous pop/push while full does not overflow");

            pop_expect(4'hc, COUNT_W'(3), 1'b0, "pop B");
            pop_expect(4'hd, COUNT_W'(2), 1'b0, "pop C");
            pop_expect(4'he, COUNT_W'(1), 1'b0, "pop D");
            pop_expect(4'h0, COUNT_W'(0), 1'b1, "pop E");

            drive_cycle(1'b0, '0, 1'b1);
            check(underflow_error, "pop while empty sets underflow");
            check(error, "underflow contributes to aggregate error");
            check(empty, "underflow leaves tracker empty");
            check(rsp_id == '0, "underflow keeps empty response ID zero");
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b0;
        clear_errors = 1'b0;
        req_fire = 1'b0;
        req_id = '0;
        rsp_fire = 1'b0;

        test_depth_four_wraparound();

        if (errors == 0) begin
            $display("tb_memory_response_tracker_depth4 PASS");
            $finish;
        end

        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
endmodule
