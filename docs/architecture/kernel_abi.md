# Kernel ABI

This document defines the current command-driven kernel ABI visible to host
software and tests.

The ABI is intentionally small. It is a register and encoded-instruction
contract, not a C ABI and not a stable compiler target.

## Launch Registers

`LAUNCH_KERNEL` consumes the launch register values listed below. The command
processor latches them when a launch is accepted.

| Register | Current meaning |
| --- | --- |
| `PROGRAM_BASE` | Instruction-word offset added to the core PC. |
| `GRID_X` | Number of work-items in X. Must be nonzero. |
| `GRID_Y` | Number of work-items in Y. Must be nonzero. |
| `GROUP_SIZE_X` | Must be 4. |
| `GROUP_SIZE_Y` | Must be 1. |
| `ARG_BASE` | Base address of the kernel argument block in global data memory. |
| `LAUNCH_FLAGS` | Must be zero. |

## `PROGRAM_BASE`

`PROGRAM_BASE` currently uses instruction-word offset semantics.

The top-level fetch address is:

```text
fetch_addr = programmable_pc + PROGRAM_BASE[PC_W-1:0]
```

Implications:

- `PROGRAM_BASE` is not a byte pointer in the current RTL
- `PROGRAM_BASE = 0` starts at instruction word 0
- `PROGRAM_BASE = 1` starts at instruction word 1
- only the low instruction-address bits used by the configured instruction
  memory are consumed
- current launch validation does not reject zero, unaligned, or out-of-range
  `PROGRAM_BASE` values

This matches the simulation instruction memory interface, where host testbench
writes use word addresses.

## Grid and Group Shape

Current hardware supports one fixed group shape:

```text
GROUP_SIZE_X = 4
GROUP_SIZE_Y = 1
```

`GRID_X` and `GRID_Y` define the total work-item rectangle. They are not
required to be multiples of four. The scheduler masks inactive tail lanes in the
last SIMD group.

For each work-item:

```text
linear_id = y * GRID_X + x
```

The programmable special-register path exposes IDs to the kernel. Current
coverage exercises one-dimensional `vector_add` and two-dimensional framebuffer
style kernels through this model.

## Argument Block

`ARG_BASE` is a global data memory address. Kernels load arguments from memory
relative to this address.

The current command-driven `vector_add` smoke uses an argument block containing
buffer base addresses and element count. The ABI does not define C structs,
pointer provenance, alignment attributes, or host-side compiler layout rules.
Tests and assembly fixtures own the exact argument layout they use.

## Launch Flags

`LAUNCH_FLAGS` must be zero. Nonzero flags make the launch invalid.

No mask, barrier, debug, preemption, cache, or tracing flag is currently
defined.

## Launch Acceptance

The launch command is accepted only when:

- `LAUNCH_KERNEL` has word count 1
- launch command flags are zero
- no existing clear, rectangle, or programmable dispatch is busy
- `GRID_X != 0`
- `GRID_Y != 0`
- `GROUP_SIZE_X == 4`
- `GROUP_SIZE_Y == 1`
- `LAUNCH_FLAGS == 0`

On acceptance, the launch register snapshot is stable for the lifetime of the
active kernel. Later host writes update the register file but not the running
kernel.

## Current Kernel Coverage

Current ABI coverage includes:

- command-driven `vector_add`
- command-driven 2D framebuffer-gradient kernel using `GRID_X`, `GRID_Y`,
  `GLOBAL_ID_X`, `GLOBAL_ID_Y`, framebuffer base, and framebuffer width
- nonzero command-driven `PROGRAM_BASE` as an instruction-word offset
- launch snapshot stability for `PROGRAM_BASE` while the host rewrites launch
  registers during an active stalled kernel
- launch snapshot stability for `ARG_BASE` while the host rewrites launch
  registers during an active stalled kernel
- launch snapshot stability for `GRID_X` and `GRID_Y` while the host rewrites
  launch registers during an active stalled kernel
- memory request stall and delayed response smoke in command-driven
  `vector_add`
- `STORE16` odd-address fault visibility through host-visible error status
- soft-reset recovery after the `STORE16` fault followed by a valid store

This is enough to pin the current command-driven ABI. It is not a claim of full
compiler support, formal proof coverage for every block, cache correctness, or
FPGA bring-up.
