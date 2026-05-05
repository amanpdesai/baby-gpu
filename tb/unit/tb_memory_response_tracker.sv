module tb_memory_response_tracker;
    localparam int ID_W = 3;
    localparam int DEPTH = 2;
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

    always #5 clk = ~clk;

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check(input logic condition, input string message);
        begin
            if (!condition) begin
                $fatal(1, "%s", message);
            end
        end
    endtask

    task automatic reset_dut;
        begin
            clk = 1'b0;
            reset = 1'b1;
            clear_errors = 1'b0;
            req_fire = 1'b0;
            req_id = '0;
            rsp_fire = 1'b0;
            step();
            reset = 1'b0;
            step();
        end
    endtask

    task automatic push_id(input logic [ID_W-1:0] id);
        begin
            req_id = id;
            req_fire = 1'b1;
            step();
            req_fire = 1'b0;
            req_id = '0;
            step();
        end
    endtask

    task automatic pop_id;
        begin
            rsp_fire = 1'b1;
            step();
            rsp_fire = 1'b0;
            step();
        end
    endtask

    task automatic test_fifo_order;
        begin
            reset_dut();
            check(empty, "tracker starts empty");
            push_id(3'b101);
            check(!empty, "first push makes tracker nonempty");
            check(rsp_id == 3'b101, "first response ID is visible at head");
            push_id(3'b011);
            check(full, "second push fills tracker");
            check(outstanding_count == 2, "two outstanding IDs tracked");
            check(rsp_id == 3'b101, "head remains oldest ID");
            pop_id();
            check(rsp_id == 3'b011, "pop exposes next ID");
            pop_id();
            check(empty, "second pop empties tracker");
            check(!error, "ordered push/pop does not set error");
        end
    endtask

    task automatic test_response_underflow_error;
        begin
            reset_dut();
            pop_id();
            check(underflow_error, "empty response sets underflow error");
            check(error, "underflow contributes to aggregate error");
            clear_errors = 1'b1;
            step();
            clear_errors = 1'b0;
            check(!error, "clear_errors clears underflow");
        end
    endtask

    task automatic test_request_overflow_error;
        begin
            reset_dut();
            push_id(3'b001);
            push_id(3'b010);
            push_id(3'b011);
            check(overflow_error, "push when full sets overflow error");
            check(rsp_id == 3'b001, "overflow does not corrupt head ID");
            pop_id();
            check(rsp_id == 3'b010, "overflow does not enqueue rejected ID");
        end
    endtask

    task automatic test_simultaneous_push_pop_when_full;
        begin
            reset_dut();
            push_id(3'b100);
            push_id(3'b101);
            req_id = 3'b110;
            req_fire = 1'b1;
            rsp_fire = 1'b1;
            step();
            req_fire = 1'b0;
            rsp_fire = 1'b0;
            step();
            check(!overflow_error, "simultaneous pop allows push when full");
            check(full, "simultaneous push/pop keeps tracker full");
            check(rsp_id == 3'b101, "oldest remaining ID is preserved after simultaneous cycle");
            pop_id();
            check(rsp_id == 3'b110, "new ID is queued after simultaneous cycle");
        end
    endtask

    initial begin
        test_fifo_order();
        test_response_underflow_error();
        test_request_overflow_error();
        test_simultaneous_push_pop_when_full();
        $display("tb_memory_response_tracker PASS");
        $finish;
    end
endmodule
