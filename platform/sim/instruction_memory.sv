module instruction_memory #(
    parameter int WORD_W = 32,
    parameter int ADDR_W = 8,
    parameter int DEPTH = (1 << ADDR_W),
    localparam int ADDR_PORT_W = (ADDR_W < 1) ? 1 : ADDR_W
) (
    input  logic                   clk,
    input  logic                   write_en,
    input  logic [ADDR_PORT_W-1:0] write_addr,
    input  logic [WORD_W-1:0]      write_data,
    input  logic [ADDR_PORT_W-1:0] fetch_addr,
    output logic [WORD_W-1:0]      fetch_instruction,
    output logic                   fetch_error
);

    localparam logic [WORD_W-1:0] NOP_WORD = {WORD_W{1'b0}};
    localparam int MAX_DEPTH = (ADDR_W >= 30) ? 1073741823 : (32'd1 << ADDR_W);

    logic [WORD_W-1:0] memory [0:DEPTH-1];

    function automatic int addr_to_index(input logic [ADDR_PORT_W-1:0] addr);
        addr_to_index = int'(addr);
    endfunction

    initial begin : parameter_checks
        if (WORD_W < 1) begin
            $fatal(1, "instruction_memory WORD_W must be at least 1");
        end
        if (ADDR_W < 1) begin
            $fatal(1, "instruction_memory ADDR_W must be at least 1");
        end
        if (ADDR_W >= 30) begin
            $fatal(1, "instruction_memory ADDR_W must be less than 30");
        end
        if (DEPTH < 1) begin
            $fatal(1, "instruction_memory DEPTH must be at least 1");
        end
        if (DEPTH > MAX_DEPTH) begin
            $fatal(1, "instruction_memory DEPTH exceeds addressable range");
        end
    end

    initial begin : initialize_memory
        int idx;

        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            memory[idx] = NOP_WORD;
        end
    end

    always @(posedge clk) begin
        if (write_en) begin
            if ($isunknown(write_addr) || (addr_to_index(write_addr) >= DEPTH)) begin
                $error("instruction_memory write address out of range: 0x%0h", write_addr);
            end else begin
                memory[addr_to_index(write_addr)] <= write_data;
            end
        end
    end

    // Combinational fetch: instruction and fetch_error reflect fetch_addr in the same delta cycle.
    always_comb begin
        fetch_instruction = NOP_WORD;
        fetch_error = 1'b1;

        if (!$isunknown(fetch_addr) && (addr_to_index(fetch_addr) < DEPTH)) begin
            fetch_instruction = memory[addr_to_index(fetch_addr)];
            fetch_error = 1'b0;
        end
    end

endmodule
