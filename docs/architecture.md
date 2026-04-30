# Architecture

UrbanaGPU-1 is a unified tiny GPU architecture. The end goal is a programmable
SIMD accelerator that can run compute kernels and graphics-style kernels over a
shared global memory model.

The existing fixed-function `CLEAR` and `FILL_RECT` blocks are useful bring-up
hardware, but they are not the final architectural center. The architecture is
centered on programmable kernel execution:

```text
host
  -> command FIFO
  -> command processor
  -> register file
  -> kernel launch
  -> scheduler
  -> programmable SIMD core
  -> global memory / framebuffer
  -> video scanout
```

## Primary Architectural Documents

| Document | Purpose |
| --- | --- |
| [programming_model.md](programming_model.md) | Kernel model, launch shape, lanes, work-items, and host contract. |
| [isa.md](isa.md) | Instruction set envelope, register model, memory instructions, and extension rules. |
| [core_architecture.md](core_architecture.md) | SIMD core structure, scheduler, lanes, pipeline, and scaling plan. |
| [memory_model.md](memory_model.md) | Global memory, framebuffer convention, scratchpad/caches, and ordering. |
| [kernel_execution.md](kernel_execution.md) | Launch flow, scheduler algorithm, kernel tests, and implementation order. |

These documents take precedence when older fixed-function documents appear to
conflict.

## Initial Target Shape

The first programmable core target is:

```text
1 core
4 SIMD lanes
32-bit scalar registers
2D kernel launch
separate instruction memory and global data memory
blocking global load/store path
convergent branches only
```

This is deliberately small, but it is not throwaway. The interface choices
should leave room for:

```text
more lanes per core
multiple cores
per-core scratchpad
instruction/cache experiments
data cache experiments
SIMT masks and divergent branch support
DDR3/global-memory wrappers
ASIC SRAM wrappers
```

## Bring-Up Path

The first useful programmable kernels are:

```text
vector_add
framebuffer_gradient
solid_fill or fill_rect
```

Together they prove:

- special registers and global IDs
- integer ALU operations
- global loads
- global stores
- RGB565 framebuffer stores
- command-driven kernel launch
- simulated memory comparison

## Existing RTL Mapping

Current fixed-function-oriented RTL maps into the programmable architecture as
infrastructure:

| Current RTL | Long-term role |
| --- | --- |
| `command_fifo.sv` | Keep as host command ingress. |
| `command_processor.sv` | Evolve to validate launch commands and register writes. |
| `register_file.sv` | Keep and extend with launch registers. |
| `framebuffer_writer.sv` | Reuse concepts in `STORE16`/memory write path. |
| `clear_engine.sv` | Compatibility helper or internal built-in kernel behavior. |
| `rect_fill_engine.sv` | Compatibility helper or later kernel behavior. |
| `gpu_core.sv` | Refactor into top-level integration around scheduler/core. |

The fixed-function engines should not accumulate new graphics features unless
they are explicitly justified as hardware accelerators. New general behavior
should go through the programmable core.

## Critical Design Rules

### Framebuffer Is Memory

Framebuffer pixels are stored in global memory. Graphics kernels write pixels
using ordinary memory stores. Video scanout reads that memory.

### Simulation First

Every new architectural feature must have an RTL simulation path. Display output
on FPGA is not a substitute for deterministic memory comparison.

### No Premature Caches

Start with blocking global memory. Add scratchpad before data cache. Add caches
only when the memory ordering and verification plan are explicit.

### Lockstep First

Start with SIMD lockstep. Reserve mask/divergence concepts in the ISA, but do
not implement full reconvergence until simple kernels run reliably.

### Scaling Requires Stable Interfaces

Parameters are useful, but scalable design comes from stable contracts:

- valid/ready payload stability
- explicit IDs for future memory responses
- clear scheduler/core boundaries
- no hidden single-core assumptions in memory wrappers
- no framebuffer-only shortcuts in the execution core

## Immediate Implementation Direction

Stop adding new fixed-function draw units. The next RTL work should be:

1. finalize the initial ISA encoding
2. add a lane register file
3. add a SIMD ALU
4. add instruction fetch/decode for a tiny instruction subset
5. add scheduler support for `1 core x 4 lanes`
6. run `vector_add` in RTL simulation
7. add `STORE16`
8. run `framebuffer_gradient` in RTL simulation

Only after that should the design revisit more advanced graphics, caches,
divergence, or multi-core execution.
