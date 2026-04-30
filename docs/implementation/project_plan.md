# Custom FPGA GPU RTL Project Plan

UrbanaGPU-1 is a small custom GPU project in portable SystemVerilog RTL. The
project began with fixed-function graphics bring-up, but the intended end goal
is now a unified programmable tiny GPU that can run compute and graphics-style
kernels.

The project should not fork into separate "fixed graphics" and "programmable
GPU" designs. Fixed-function clear and rectangle blocks are bring-up tools and
possible future compatibility helpers. The architecture direction is
programmable SIMD execution.

Primary architecture references:

- [Architecture](../architecture/architecture.md)
- [Programming model](../architecture/programming_model.md)
- [ISA](../architecture/isa.md)
- [Core architecture](../architecture/core_architecture.md)
- [Memory model](../architecture/memory_model.md)
- [Kernel execution](../architecture/kernel_execution.md)
- [Roadmap](roadmap.md)

## Goal

Build a portable GPU-like accelerator that can:

- accept command streams from a host or testbench
- configure and launch programmable kernels
- execute kernels on a small SIMD core
- read and write global memory
- treat the framebuffer as global memory
- display framebuffer contents on the Urbana FPGA board
- remain portable to simulation, FPGA, and ASIC experiments

## Initial Programmable Target

```text
1 core
4 SIMD lanes
32-bit registers
2D kernel launch
separate instruction memory and global memory
blocking load/store unit
convergent branches only
```

This is the first target shape, not a hard architectural limit.

## First Kernel Tests

The first programmable milestone should prove several behaviors, not just one
demo.

| Kernel | Purpose |
| --- | --- |
| `vector_add` | Compute loads, ALU, stores, and tail lanes. |
| `framebuffer_gradient` | 2D IDs, RGB565 stores, framebuffer memory. |
| `solid_fill` or bounded fill | Simple graphics behavior and predicates. |

All kernels must run in RTL simulation before FPGA bring-up is considered
meaningful.

## Current Foundation RTL

The current RTL foundation includes:

- command FIFO
- command processor
- register file
- framebuffer writer
- clear engine
- rectangle fill engine
- top-level smoke integration

This is valuable infrastructure. It should be used to keep tests running while
the programmable core is added. It should not expand into a large fixed-function
graphics engine before the programmable path exists.

## Implementation Priorities

Near-term work:

1. finalize initial ISA encoding
2. add lane register file
3. add SIMD ALU
4. add instruction memory model
5. add instruction decoder
6. add scheduler for `1 core x 4 lanes`
7. add blocking load/store unit
8. pass `vector_add` in simulation
9. add `STORE16`
10. pass `framebuffer_gradient` in simulation

Later work:

- predicate support
- bounded fill kernel
- video scanout from global memory
- per-core scratchpad
- multi-core memory IDs
- more lanes
- caches
- divergence masks
- FPGA display bring-up
- ASIC memory wrappers and synthesis experiments

## Design Boundaries

Portable RTL lives under `rtl/`.

Platform-specific code lives under:

```text
platform/urbana/
platform/sim/
platform/asic/
```

The programmable core must not instantiate Xilinx primitives directly. Memory
wrappers and video output wrappers are platform responsibilities.

## Verification Policy

Simulation is the primary correctness tool.

Required for each new architectural block:

- unit test
- integration test when connected to command/kernel flow
- timeout on hangs
- sticky error checks
- deterministic expected memory output when applicable

Formal verification should be added for FIFOs, valid/ready payload stability,
scheduler bounds, and load/store request behavior.

## Critical Project Discipline

Do not add features because they are GPU-like. Add features because they are
needed by the next kernel test or because they preserve a documented scaling
path.

Do not add caches before the blocking memory model is correct.

Do not add multi-core execution before memory request/response identity exists.

Do not add full divergence support before convergent branches and simple kernels
work.

Do not make framebuffer writes a special execution path. The framebuffer is
global memory.
