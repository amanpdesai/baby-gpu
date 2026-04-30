import isa_pkg::*;

module tb_instruction_memory;
    localparam int ADDR_W = 3;
    localparam int DEPTH = 5;

    logic clk;
    logic write_en;
    logic [ADDR_W-1:0] write_addr;
    logic [ISA_WORD_W-1:0] write_data;
    logic [ADDR_W-1:0] fetch_addr;
    logic [ISA_WORD_W-1:0] fetch_instruction;
    logic fetch_error;

    instruction_memory #(
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
                $fatal(1, "FAIL: %s", message);
            end
        end
    endtask

    task automatic write_word(
        input logic [ADDR_W-1:0] addr,
        input logic [ISA_WORD_W-1:0] data
    );
        begin
            write_addr = addr;
            write_data = data;
            write_en = 1'b1;
            step();
            write_en = 1'b0;
        end
    endtask

    task automatic expect_fetch(
        input logic [ADDR_W-1:0] addr,
        input logic [ISA_WORD_W-1:0] expected,
        input string message
    );
        begin
            fetch_addr = addr;
            #1;
            check(fetch_instruction === expected, message);
            check(!fetch_error, {message, " fetch_error"});
        end
    endtask

    task automatic expect_fetch_error(
        input logic [ADDR_W-1:0] addr,
        input string message
    );
        begin
            fetch_addr = addr;
            #1;
            check(fetch_instruction === isa_pkg::isa_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0),
                  {message, " returns NOP"});
            check(fetch_error, {message, " asserts fetch_error"});
        end
    endtask

    initial begin
        logic [ISA_WORD_W-1:0] program_word [0:3];

        clk = 1'b0;
        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;
        fetch_addr = '0;

        program_word[0] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd1, 4'd0, 18'd7);
        program_word[1] = isa_pkg::isa_i_type(ISA_OP_MOVI, 4'd2, 4'd0, 18'd11);
        program_word[2] = isa_pkg::isa_r_type(ISA_OP_ADD, 4'd3, 4'd1, 4'd2);
        program_word[3] = isa_pkg::isa_r_type(ISA_OP_END, 4'd0, 4'd0, 4'd0);

        expect_fetch(3'd0, isa_pkg::isa_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0),
                     "unwritten word reads as NOP");

        write_word(3'd0, program_word[0]);
        write_word(3'd1, program_word[1]);
        write_word(3'd2, program_word[2]);
        write_word(3'd3, program_word[3]);

        expect_fetch(3'd0, program_word[0], "program word 0 readback");
        expect_fetch(3'd1, program_word[1], "program word 1 readback");
        expect_fetch(3'd2, program_word[2], "program word 2 readback");
        expect_fetch(3'd3, program_word[3], "program word 3 readback");
        expect_fetch(3'd4, isa_pkg::isa_r_type(ISA_OP_NOP, 4'd0, 4'd0, 4'd0),
                     "last valid unwritten word reads as NOP");
        expect_fetch_error(3'd5, "out-of-range fetch");
        expect_fetch_error(3'b1x0, "unknown fetch address");

        $display("PASS: tb_instruction_memory");
        $finish;
    end
endmodule
