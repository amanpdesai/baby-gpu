`ifndef KERNEL_PROGRAM_LOADER_SVH
`define KERNEL_PROGRAM_LOADER_SVH

`define KGPU_LOAD_PROGRAM(WORDS) \
  begin \
    for (int kgpu_program_idx = 0; kgpu_program_idx < $size(WORDS); kgpu_program_idx++) begin \
      write_imem(IMEM_ADDR_W'(kgpu_program_idx), WORDS[kgpu_program_idx]); \
    end \
  end

`endif
