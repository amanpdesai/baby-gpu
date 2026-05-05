module lane_register_file_formal (
    input logic clk
);
    localparam int LANES = 2;
    localparam int REGS = 2;
    localparam int DATA_W = 4;
    localparam int REG_ADDR_W = $clog2(REGS);

    (* anyseq *) logic reset;
    (* anyseq *) logic [REG_ADDR_W-1:0] read_addr_a;
    (* anyseq *) logic [REG_ADDR_W-1:0] read_addr_b;
    (* anyseq *) logic [REG_ADDR_W-1:0] read_addr_c;
    (* anyseq *) logic [LANES-1:0] write_enable;
    (* anyseq *) logic [REG_ADDR_W-1:0] write_addr;
    (* anyseq *) logic [(LANES*DATA_W)-1:0] write_data;

    logic [(LANES*DATA_W)-1:0] read_data_a;
    logic [(LANES*DATA_W)-1:0] read_data_b;
    logic [(LANES*DATA_W)-1:0] read_data_c;
    logic [DATA_W-1:0] model [LANES][REGS];
    logic past_valid;

    lane_register_file #(
        .LANES(LANES),
        .REGS(REGS),
        .DATA_W(DATA_W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .read_addr_a(read_addr_a),
        .read_data_a(read_data_a),
        .read_addr_b(read_addr_b),
        .read_data_b(read_data_b),
        .read_addr_c(read_addr_c),
        .read_data_c(read_data_c),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .write_data(write_data)
    );

    initial begin
        assume(reset);
        past_valid = 1'b0;
    end

    integer lane_idx;
    integer reg_idx;

    always_ff @(posedge clk) begin
        past_valid <= 1'b1;

        if (!past_valid) begin
            assume(reset);
        end

        if (reset) begin
            for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
                for (reg_idx = 0; reg_idx < REGS; reg_idx = reg_idx + 1) begin
                    model[lane_idx][reg_idx] <= '0;
                end
            end
        end else begin
            for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
                model[lane_idx][0] <= '0;
                if (write_enable[lane_idx] && (write_addr != '0)) begin
                    model[lane_idx][write_addr] <= write_data[(lane_idx*DATA_W)+:DATA_W];
                end
            end
        end

        if (past_valid && $past(reset)) begin
            assert(read_data_a == '0);
            assert(read_data_b == '0);
            assert(read_data_c == '0);
        end
    end

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : lane_checks
            always_ff @(posedge clk) begin
                if (past_valid) begin
                    assert(model[lane][0] == '0);
                    assert(read_data_a[(lane*DATA_W)+:DATA_W] ==
                           ((read_addr_a == '0) ? '0 : model[lane][read_addr_a]));
                    assert(read_data_b[(lane*DATA_W)+:DATA_W] ==
                           ((read_addr_b == '0) ? '0 : model[lane][read_addr_b]));
                    assert(read_data_c[(lane*DATA_W)+:DATA_W] ==
                           ((read_addr_c == '0) ? '0 : model[lane][read_addr_c]));

                    cover(!reset && (read_addr_a == REG_ADDR_W'(1)) &&
                          (model[lane][1] != '0) &&
                          (read_data_a[(lane*DATA_W)+:DATA_W] == model[lane][1]));
                    cover(!reset && $past(!reset && write_enable[lane] && (write_addr == '0) &&
                                          (write_data[(lane*DATA_W)+:DATA_W] != '0)) &&
                          (model[lane][0] == '0) && (read_addr_a == '0) &&
                          (read_data_a[(lane*DATA_W)+:DATA_W] == '0));
                end
            end
        end
    endgenerate
endmodule
