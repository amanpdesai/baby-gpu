module tb_lane_register_file;
  logic clk;
  logic reset;
  logic [3:0] read_addr_a;
  logic [127:0] read_data_a;
  logic [3:0] read_addr_b;
  logic [127:0] read_data_b;
  logic [3:0] write_enable;
  logic [3:0] write_addr;
  logic [127:0] write_data;

  lane_register_file dut (
      .clk(clk),
      .reset(reset),
      .read_addr_a(read_addr_a),
      .read_data_a(read_data_a),
      .read_addr_b(read_addr_b),
      .read_data_b(read_data_b),
      .write_enable(write_enable),
      .write_addr(write_addr),
      .write_data(write_data)
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

  function automatic logic [31:0] lane_word(input logic [127:0] value, input int lane);
    begin
      lane_word = value[(lane*32)+:32];
    end
  endfunction

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    read_addr_a = 4'd0;
    read_addr_b = 4'd1;
    write_enable = 4'b0000;
    write_addr = 4'd0;
    write_data = '0;

    step();
    reset = 1'b0;
    step();

    check(read_data_a == 128'd0, "R0 reads as zero after reset");
    check(read_data_b == 128'd0, "R1 resets to zero across lanes");

    write_addr = 4'd1;
    write_enable = 4'b1111;
    write_data = {32'h4000_0004, 32'h3000_0003, 32'h2000_0002, 32'h1000_0001};
    step();
    write_enable = 4'b0000;
    read_addr_a = 4'd1;
    #1;
    check(lane_word(read_data_a, 0) == 32'h1000_0001, "lane 0 R1 write/read");
    check(lane_word(read_data_a, 1) == 32'h2000_0002, "lane 1 R1 write/read");
    check(lane_word(read_data_a, 2) == 32'h3000_0003, "lane 2 R1 write/read");
    check(lane_word(read_data_a, 3) == 32'h4000_0004, "lane 3 R1 write/read");

    write_addr = 4'd2;
    write_enable = 4'b0101;
    write_data = {32'hDDDD_DDDD, 32'hCCCC_CCCC, 32'hBBBB_BBBB, 32'hAAAA_AAAA};
    step();
    write_enable = 4'b0000;
    read_addr_b = 4'd2;
    #1;
    check(lane_word(read_data_b, 0) == 32'hAAAA_AAAA, "lane write enable updates lane 0");
    check(lane_word(read_data_b, 1) == 32'h0000_0000, "lane write enable suppresses lane 1");
    check(lane_word(read_data_b, 2) == 32'hCCCC_CCCC, "lane write enable updates lane 2");
    check(lane_word(read_data_b, 3) == 32'h0000_0000, "lane write enable suppresses lane 3");

    write_addr = 4'd0;
    write_enable = 4'b1111;
    write_data = {4{32'hFFFF_FFFF}};
    step();
    write_enable = 4'b0000;
    read_addr_a = 4'd0;
    #1;
    check(read_data_a == 128'd0, "writes to R0 are ignored");

    read_addr_a = 4'd1;
    read_addr_b = 4'd2;
    #1;
    check(lane_word(read_data_a, 3) == 32'h4000_0004, "read port A remains independent");
    check(lane_word(read_data_b, 2) == 32'hCCCC_CCCC, "read port B remains independent");

    $display("tb_lane_register_file PASS");
    $finish;
  end
endmodule
