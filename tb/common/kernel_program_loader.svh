`ifndef KERNEL_PROGRAM_LOADER_SVH
`define KERNEL_PROGRAM_LOADER_SVH

`define KGPU_LOAD_PROGRAM_AT(BASE, WORDS) \
  begin \
    for (int kgpu_program_idx = 0; kgpu_program_idx < $size(WORDS); kgpu_program_idx++) begin \
      write_imem(IMEM_ADDR_W'((BASE) + kgpu_program_idx), WORDS[kgpu_program_idx]); \
    end \
  end

`define KGPU_LOAD_PROGRAM(WORDS) \
  `KGPU_LOAD_PROGRAM_AT(0, WORDS)

`endif
