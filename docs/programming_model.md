# Programming Model

UrbanaGPU-1 is a unified tiny GPU. The long-term target is not a collection of
fixed graphics blocks. The target is a programmable accelerator that can run
small compute kernels and graphics-style kernels against a shared memory model.

The first programmable architecture must remain small enough to implement and
verify, but the model must not paint the design into a corner. The core
assumption is:

```text
host -> command stream -> kernel launch -> scheduler -> SIMD core -> global memory
```

The framebuffer is a region of global memory. Graphics is therefore a use case
of the compute model rather than a separate universe. A framebuffer kernel
writes pixels. A video scanout path reads the same memory.

## Design Goals

The programming model has four goals:

- be simple enough to run in RTL simulation early
- support both compute and graphics examples
- expose GPU concepts such as lanes, work-items, workgroups, and global IDs
- scale later to more lanes, more cores, scratchpad memory, and caches

This is not trying to emulate CUDA, Vulkan, OpenCL, or a commercial GPU ISA.
Those systems carry a large software and hardware contract. UrbanaGPU should
borrow the useful shape, not the full complexity.

## Initial Kernel Set

The first programmable tests should include multiple kernels. A single
"hello world" is too narrow and can hide bad architectural choices.

Required bring-up kernels:

| Kernel | Purpose | Hardware proven |
| --- | --- | --- |
| `vector_add` | Compute over buffers | global loads, ALU, global stores |
| `framebuffer_gradient` | Write visible image | 2D IDs, framebuffer addressing |
| `solid_fill` or `fill_rect` | Simple graphics conditional | bounds checks, predicates |

These kernels should run in simulation first. FPGA display output comes after
the simulated memory results are correct.

## Kernel Launch Shape

A kernel launch describes a rectangular grid of work-items. The initial model
supports 2D dispatch because framebuffer work needs `x` and `y` coordinates.
1D compute kernels are represented as `grid_y = 1`.

Launch fields:

| Field | Meaning |
| --- | --- |
| `program_base` | Instruction memory address of the kernel. |
| `grid_x` | Number of work-items in X. |
| `grid_y` | Number of work-items in Y. |
| `group_size_x` | Number of work-items per group in X. |
| `group_size_y` | Number of work-items per group in Y. |
| `arg_base` | Global memory address for kernel arguments. |
| `flags` | Reserved for future masks, barriers, and memory modes. |

Initial restrictions:

- one active kernel launch at a time
- one SIMD core
- four lanes per core
- no preemption
- no nested launches
- no dynamic memory allocation
- no exceptions beyond sticky error bits

These restrictions keep the first scheduler finite and testable.

## Work-Items, Groups, and Lanes

Terminology:

| Term | Meaning |
| --- | --- |
| Work-item | One logical invocation of a kernel. |
| Lane | One hardware datapath executing one work-item in a SIMD bundle. |
| SIMD group | The set of lanes sharing one program counter. |
| Workgroup | A rectangular tile of work-items that may later share scratchpad memory. |
| Core | A scheduler, instruction pipeline, lane register files, and memory interface. |

Initial mapping:

```text
1 core
4 lanes per core
1 shared PC per core
each lane owns a private register file
```

The scheduler assigns consecutive work-items to the four lanes. For a 2D grid,
the scheduler computes:

```text
global_id_x
global_id_y
linear_global_id = global_id_y * grid_x + global_id_x
lane_id
```

These values are visible to the kernel through special registers.

## Execution Model

Initial execution is SIMD lockstep:

```text
one instruction fetch
one decode
one shared PC
N lanes execute the same instruction over N independent register files
```

This is intentionally simpler than full SIMT. It still exercises the central
GPU idea: many work-items run the same program over different data.

Initial branch policy:

- branch instructions are allowed
- a branch is legal only when all active lanes agree on the control decision
- divergent branches set a sticky error bit and halt the current kernel

The architecture reserves room for lane masks, but full divergence support is
not part of the first implementation. This avoids building reconvergence stacks
before the basic kernel pipeline works.

## Kernel Completion

A kernel completes when:

- all assigned work-items have reached `END`
- all outstanding memory requests have completed or been accepted according to
  the memory protocol
- the scheduler has no active group
- the command processor has no pending launch state

Completion must be observable through status registers and simulation tests.

## Host Interface

The host controls the GPU through a command FIFO and register file.

The long-term command set should include:

| Command | Purpose |
| --- | --- |
| `NOP` | No operation. |
| `SET_REGISTER` | Write a control or launch register. |
| `LAUNCH_KERNEL` | Start a programmable kernel. |
| `WAIT_IDLE` | Wait until all active work completes. |
| `CLEAR` | Compatibility command, later implemented by an internal kernel. |
| `FILL_RECT` | Compatibility command, later implemented by an internal kernel. |

`CLEAR` and `FILL_RECT` are useful for early bring-up, but they should not
define the final architecture. They should eventually become convenience
commands that write launch registers and dispatch built-in programs.

## Initial Software Contract

Early software does not need a compiler. It needs deterministic test assets:

- hand-encoded instruction arrays
- small assembler script once encodings stabilize
- command streams for launch setup
- golden memory/framebuffer outputs

The minimum useful software flow:

```text
kernel assembly
  -> encoded instruction memory image
  -> command stream
  -> RTL simulation
  -> memory/framebuffer comparison
```

## Non-Goals for the First Programmable Milestone

The first programmable milestone does not include:

- caches
- virtual memory
- interrupts beyond sticky status
- multiple active kernels
- out-of-order memory
- divergent branch reconvergence
- floating point
- texture filtering
- atomics
- hardware-managed call stacks
- compiler-level optimization

These features are compatible with the direction, but they must not appear
until the base execution and memory model are proven.

## Critical Risks

### Scope Drift

A programmable GPU can turn into an unbounded CPU project. Every feature must
be justified by a kernel test. If a feature is not needed for `vector_add`,
`framebuffer_gradient`, or `fill_rect`, it should wait.

### Unclear Memory Semantics

The framebuffer must not be special inside the execution core. If pixel writes
use one path and compute writes use another path, the design will split into two
architectures. Treat framebuffer writes as ordinary global stores.

### Divergence Too Early

Full SIMT divergence is a real GPU feature, but it is easy to spend weeks on
mask stacks and reconvergence before executing one useful kernel. Reserve the
fields now. Implement it later.

### Over-Parameterization

Parameters are useful only when the interface contract remains stable. The
first target is `1 core x 4 lanes`. Widths and counts should be parameters, but
the RTL should not try to support every possible shape before there are tests.
