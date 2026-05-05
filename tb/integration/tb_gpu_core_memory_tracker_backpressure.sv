module tb_gpu_core_memory_tracker_backpressure;
    import isa_pkg::*;

    logic clk;
    logic reset;
    logic enable;
    logic clear_errors;
    logic cmd_valid;
    logic cmd_ready;
    logic [31:0] cmd_data;
    logic imem_write_en;
    logic [7:0] imem_write_addr;
    logic [ISA_WORD_W-1:0] imem_write_data;
    logic busy;
    logic [7:0] error_status;
    logic mem_req_valid;
    logic mem_req_ready;
    logic mem_req_write;
    logic [31:0] mem_req_addr;
    logic [31:0] mem_req_wdata;
    logic [3:0] mem_req_wmask;
    logic mem_rsp_valid;
    logic mem_rsp_ready;
    logic [31:0] mem_rsp_rdata;
    int accepted_requests;
    int accepted_responses;

    `include "tb/common/gpu_core_command_driver.svh"

    gpu_core #(
        .FB_WIDTH(10),
        .FB_HEIGHT(1),
        .FIFO_DEPTH(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .clear_errors(clear_errors),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_data(cmd_data),
        .imem_write_en(imem_write_en),
        .imem_write_addr(imem_write_addr),
        .imem_write_data(imem_write_data),
        .busy(busy),
        .error_status(error_status),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wmask(mem_req_wmask),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_rdata(mem_rsp_rdata)
    );

    always #5 clk = ~clk;

    task automatic step_counting_memory;
        begin
            if (mem_req_valid && mem_req_ready) begin
                accepted_requests++;
            end
            if (mem_rsp_valid && mem_rsp_ready) begin
                accepted_responses++;
            end
            step();
        end
    endtask

    initial begin
        init_command_driver();
        mem_req_ready = 1'b1;
        mem_rsp_valid = 1'b0;
        mem_rsp_rdata = '0;
        accepted_requests = 0;
        accepted_responses = 0;

        step();
        reset = 1'b0;
        step();

        send_word(32'h0102_0000);
        send_word(32'h0000_55AA);

        while (accepted_requests < 4) begin
            step_counting_memory();
        end

        repeat (6) begin
            step_counting_memory();
            check(accepted_requests == 4, "tracker full blocks additional clear writes");
        end

        mem_rsp_valid = 1'b1;
        step_counting_memory();
        mem_rsp_valid = 1'b0;
        check(accepted_responses == 1, "held write response drains through tracker");
        while (accepted_requests < 5) begin
            step_counting_memory();
        end
        check(accepted_requests == 5, "tracker pop allows next clear write");

        $display("tb_gpu_core_memory_tracker_backpressure PASS");
        $finish;
    end
endmodule
