task automatic init_memory(input logic [31:0] fill);
begin
  for (int mem_idx = 0; mem_idx < MEM_WORDS; mem_idx = mem_idx + 1) begin
    memory[mem_idx] = fill;
  end
end
endtask

function automatic logic [31:0] read_memory_word(input logic [31:0] addr);
begin
  read_memory_word = memory[addr[31:2]];
end
endfunction

task automatic write_memory_masked(input logic [31:0] addr,
                                   input logic [31:0] data,
                                   input logic [3:0] mask);
begin
  if (mask[0]) begin
    memory[addr[31:2]][7:0] <= data[7:0];
  end
  if (mask[1]) begin
    memory[addr[31:2]][15:8] <= data[15:8];
  end
  if (mask[2]) begin
    memory[addr[31:2]][23:16] <= data[23:16];
  end
  if (mask[3]) begin
    memory[addr[31:2]][31:24] <= data[31:24];
  end
end
endtask
