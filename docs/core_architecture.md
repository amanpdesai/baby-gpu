# Core Architecture

The core architecture target is a small SIMD processor that can run kernels over
global memory. It should be built as a real GPU-like execution core, not as a
CPU with a framebuffer peripheral and not as a pile of fixed graphics engines.

Initial hardware target:

```text
1 programmable core
4 SIMD lanes
1 shared program counter
private register file per lane
global memory load/store path
```

The design must keep the path open to:

```text
more lanes per core
multiple cores
per-core scratchpad memory
read-only caches
data caches
SIMT masks and divergence support
```

## Core Block Diagram

```text
kernel launch
  -> scheduler
    -> instruction fetch
      -> decode/control
        -> lane register files
        -> SIMD ALU
        -> load/store unit
          -> memory arbiter
            -> global memory / framebuffer
```

The video scanout path is a memory client. It is not part of the execution
core.

## Major Blocks

| Block | Responsibility |
| --- | --- |
| Scheduler | Assign work-items to lanes and track kernel completion. |
| Program counter | Shared PC for the SIMD group. |
| Instruction fetch | Read instruction memory. |
| Decode/control | Decode opcode, generate lane controls, handle errors. |
| Lane register file | Private architectural registers per lane. |
| SIMD ALU | Execute arithmetic and compare instructions across lanes. |
| Predicate/mask unit | Track active lanes; initially simple and convergent. |
| Load/store unit | Generate per-lane memory requests. |
| Memory coalescer | Later optimization for adjacent lane memory accesses. |
| Completion unit | Detect all lanes complete and drain memory. |

## Lane Model

Each lane executes the same instruction as other lanes but over different
register values.

Lane state:

- active bit
- done bit
- lane register file
- assigned global IDs
- pending memory response state

Initial active mask behavior:

```text
active lanes execute every instruction
inactive lanes suppress register and memory writes
all lanes start active if assigned a valid work-item
lanes become inactive/done at END
```

Initial implementation may avoid partial masks except for tail work-items. For
example, a grid of 10 items on 4 lanes produces groups of 4, 4, and 2 active
lanes.

## Scheduler

The scheduler maps launch dimensions onto SIMD groups.

Inputs:

- `program_base`
- `grid_x`
- `grid_y`
- `group_size_x`
- `group_size_y`
- `arg_base`

Outputs per lane:

- valid work-item assignment
- `global_id_x`
- `global_id_y`
- `local_id_x`
- `local_id_y`
- `group_id_x`
- `group_id_y`
- `linear_global_id`

Initial scheduler restrictions:

- one active kernel
- one core
- no work stealing
- no preemption
- no barriers
- no scratchpad allocation

The scheduler should still use counters and interfaces that can be replicated
for multiple cores later.

## Instruction Pipeline

The initial pipeline can be simple and mostly sequential:

```text
FETCH -> DECODE -> EXECUTE -> MEMORY/WRITEBACK
```

It does not need high throughput initially. Correctness and visibility matter
more than IPC.

Minimum requirements:

- instruction payload is stable during stalls
- lane write enables are explicit
- memory operations hold request payload while `valid && !ready`
- illegal state recovers to idle/error, not X-dependent behavior
- `END` drains or suppresses further writes for that lane

## Lockstep Execution and Divergence

Lockstep means all active lanes share one PC. This is the simplest GPU-like
model worth building.

Branch cases:

| Case | Initial behavior |
| --- | --- |
| all active lanes branch | update PC |
| no active lanes branch | fall through |
| mixed decision | set divergence error and halt kernel |

This is restrictive but honest. It lets us build real branches without solving
reconvergence immediately.

Future mask support can add:

- per-lane predicate registers
- active mask stack
- reconvergence PC
- masked writeback
- structured branch restrictions

The ISA and status registers should reserve fields for this, but RTL should not
pretend to support it until verified.

## Load/Store Unit

The load/store unit accepts per-lane memory operations and presents them to the
global memory system.

Initial simple LSU behavior:

- issue one lane memory operation at a time
- stall the core until operation completes
- no coalescing
- no cache
- byte mask support for `STORE16`

Later scalable LSU behavior:

- combine adjacent lane stores
- support multiple outstanding requests
- feed a per-core memory queue
- arbitrate against scanout and other cores

The first LSU should be correct under backpressure. Coalescing can come later.

## Per-Core State

The core should have explicit state for:

- idle/running/error
- active kernel launch parameters
- current SIMD group index
- active lane mask
- done lane mask
- PC
- outstanding memory request flag
- sticky error bits

Avoid implicit state in combinational loops or testbench assumptions.

## Scaling Plan

Scaling dimensions:

| Dimension | Initial | Later |
| --- | ---: | ---: |
| cores | 1 | 2, 4, more |
| lanes per core | 4 | 8, 16 |
| register count | 16 | 32 if needed |
| outstanding memory ops | 1 | several |
| scratchpad | none | per core |
| cache | none | read-only, then data |

Interfaces must not assume only one producer forever. Memory requests should
carry enough identity later to route responses:

```text
core_id
lane_id
request_id
write/read
addr
wdata
wmask
```

Initial RTL can tie off IDs, but interface planning should reserve them.

## Interaction With Existing Fixed-Function Blocks

Current `clear_engine` and `rect_fill_engine` are useful bring-up blocks. They
prove command FIFO, register file, framebuffer addressing, write masks, and
simulation infrastructure.

Long term:

- keep them as optional built-in micro-operations, or
- replace their public behavior with internal programmable kernels

They should not drive the architecture. New functionality should prefer the
programmable core unless a fixed block is explicitly justified by performance or
I/O timing.

## Verification Strategy

Core verification must happen in layers:

1. lane ALU unit tests
2. lane register file tests
3. instruction decode tests
4. scheduler ID generation tests
5. LSU backpressure tests
6. single-instruction kernel tests
7. `vector_add` integration test
8. `framebuffer_gradient` integration test
9. `fill_rect` integration test

Every architectural claim needs a test. If there is no test path, the feature
is not real.
