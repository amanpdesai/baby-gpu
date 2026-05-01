module instruction_memory_formal (
    input logic clk
);
    localparam int WORD_W = 32;
    localparam int ADDR_W = 2;
    localparam int DEPTH = 2;

    logic write_en;
    logic [ADDR_W-1:0] write_addr;
    logic [WORD_W-1:0] write_data;
    logic [ADDR_W-1:0] fetch_addr;
    logic [WORD_W-1:0] fetch_instruction;
    logic fetch_error;
    logic [3:0] cycle_q;
    logic past_valid;

    instruction_memory #(
        .WORD_W(WORD_W),
        .ADDR_W(ADDR_W),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .write_en(write_en),
        .write_addr(write_addr),
        .write_data(write_data),
        .fetch_addr(fetch_addr),
        .fetch_instruction(fetch_instruction),
        .fetch_error(fetch_error)
    );

    initial begin
        cycle_q = '0;
        past_valid = 1'b0;
    end

    always_comb begin
        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;
        fetch_addr = '0;

        unique case (cycle_q)
            4'd1: begin
                write_en = 1'b1;
                write_addr = 2'd0;
                write_data = 32'h1234_5678;
                fetch_addr = 2'd0;
            end
            4'd2: begin
                fetch_addr = 2'd0;
            end
            4'd3: begin
                write_en = 1'b1;
                write_addr = 2'd1;
                write_data = 32'hA5A5_5A5A;
                fetch_addr = 2'd1;
            end
            4'd4: begin
                fetch_addr = 2'd1;
            end
            4'd5: begin
                fetch_addr = 2'd2;
            end
            4'd6: begin
                write_en = 1'b1;
                write_addr = 2'd3;
                write_data = 32'hFFFF_0000;
                fetch_addr = 2'd2;
            end
            4'd7: begin
                fetch_addr = 2'd0;
            end
            default: begin
                fetch_addr = '0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;
        cycle_q <= cycle_q + 4'd1;

        if (past_valid && cycle_q == 4'd0) begin
            assert(fetch_instruction == '0);
            assert(!fetch_error);
        end

        if (past_valid && cycle_q == 4'd2) begin
            assert(fetch_instruction == 32'h1234_5678);
            assert(!fetch_error);
        end

        if (past_valid && cycle_q == 4'd4) begin
            assert(fetch_instruction == 32'hA5A5_5A5A);
            assert(!fetch_error);
        end

        if (past_valid && (cycle_q == 4'd5 || cycle_q == 4'd6)) begin
            assert(fetch_instruction == '0);
            assert(fetch_error);
        end

        if (past_valid && cycle_q == 4'd7) begin
            assert(fetch_instruction == 32'h1234_5678);
            assert(!fetch_error);
        end
    end
endmodule
