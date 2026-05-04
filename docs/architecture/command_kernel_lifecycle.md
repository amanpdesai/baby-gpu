# Command and Kernel Lifecycle

This document defines the current host-visible command and kernel lifecycle.
It describes implemented RTL behavior and the contract tests should preserve.

## Scope

The lifecycle covers the host command stream, launch register snapshotting,
programmable kernel execution, wait-for-idle behavior, sticky error reporting,
and soft-reset recovery.

It does not define a compiler ABI, a C runtime, cache behavior, full formal
verification status, or FPGA bring-up status.

## Host-Visible States

### Idle

The GPU is idle when:

- the command processor is in its idle state
- the command FIFO is empty
- fixed-function compatibility engines are idle
- no programmable launch is pending
- the scheduler, SIMD core, and LSU are idle
- no accepted memory operation is still blocking completion

In this state the host-visible `busy` output is low. Sticky error bits may still
be set after a previous fault; idle does not imply error-free.

### Command Pending

A command is pending when at least one command word is queued or the command
processor is decoding a multiword packet.

Host-visible effects:

- `busy` is high while pending command work exists
- launch registers may be written through `SET_REGISTER`
- malformed command packets set sticky command error bits
- commands that dispatch work are rejected if another dispatch path is busy

The command processor validates packet structure before dispatch. It does not
execute kernel instructions.

### Launch Accepted

`LAUNCH_KERNEL` is accepted when all current launch checks pass:

- command word count is exactly one
- command header flags are zero
- no fixed-function or programmable dispatch is busy
- `GRID_X` and `GRID_Y` are nonzero
- `GROUP_SIZE_X` is 4
- `GROUP_SIZE_Y` is 1
- `LAUNCH_FLAGS` is zero

On acceptance, the command processor latches the launch registers and emits a
one-cycle launch request. Host writes to launch registers after this point do
not change the active kernel.

### Kernel Running

A kernel is running after the programmable core accepts the launch and before
all active work-items reach `END` or a fault stops execution.

Current execution properties:

- one core
- four SIMD lanes
- shared program counter
- work-items are assigned in groups of up to four lanes
- tail lanes are inactive when the remaining work-item count is less than four
- global memory operations are blocking
- request backpressure and delayed responses can stall progress

During this state `busy` is high through the command processor's launch-busy
path. The host should not expect a later launch to be accepted until this path
returns idle.

### Wait-Idle Blocked

`WAIT_IDLE` is a command-stream barrier. If any dispatch path is active when the
command is decoded, the command processor remains in `WAIT_IDLE`.

While blocked:

- `busy` remains high
- new command words may still enter the top-level FIFO if FIFO space exists
- queued words are not retired by the command processor until the barrier clears
- completion waits for clear, rectangle, programmable launch, scheduler, core,
  and memory-facing work to become idle

`WAIT_IDLE` must not complete only because the command processor has no more
packet words to decode.

### Kernel Done

A kernel is done when every active lane in the current and final SIMD group has
reached `END`, no LSU operation is still waiting for an accepted request or
response, and the scheduler has no more groups to issue.

After kernel done:

- the programmable launch-busy path returns idle
- a blocked `WAIT_IDLE` can retire
- `busy` can deassert once the command FIFO is empty and no other command work
  remains
- sticky errors remain unchanged unless explicitly cleared or reset

### Sticky Fault

Faults are reported through sticky error status. A fault is sticky because the
host must be able to observe it after the faulting operation stops making
forward progress.

Current sticky fault sources include:

- unknown command opcode
- bad command word count
- nonzero reserved command fields
- invalid launch configuration
- launch attempted while a dispatch path is busy
- programmable illegal instruction or reserved instruction field
- divergent branch fault
- memory fault, including odd-address `STORE16`
- fixed-function compatibility engine error

The top-level error status ORs command-processor errors with fixed-function and
programmable error bits. Current command-driven `STORE16` fault coverage checks
that an odd-address halfword store becomes host-visible and does not issue the
faulting memory write.

### Soft-Reset Recovery

Writing `CONTROL.SOFT_RESET` asserts a one-cycle internal reset pulse. Current
coverage uses this path after a programmable `STORE16` fault and then launches a
valid kernel to prove recovery.

Soft-reset recovery expectations:

- active command and programmable execution state are reset
- host-visible programmable fault status clears
- launch registers can be programmed again
- a following valid command-driven kernel can complete without sticky errors

Soft reset is a recovery mechanism for the current core. It is not a substitute
for specifying replay, preemption, context save/restore, or cache flush
semantics.

## Current Coverage

Implemented coverage for this lifecycle is intentionally narrow:

- command-driven `vector_add` through `gpu_core`
- command-driven 2D framebuffer-gradient kernel through `gpu_core`
- command-driven nonzero `PROGRAM_BASE` launch through `gpu_core`
- command-driven memory request backpressure and delayed response smoke in the
  `vector_add` path
- command-driven launch-while-busy dispatch rejection
- `WAIT_IDLE` barrier behavior while a command-launched kernel is stalled on
  memory
- command-driven invalid-launch rejection through real `gpu_core` launch
  registers for zero grid, unsupported group size, and nonzero flags
- command-driven soft reset while a kernel is stalled on memory, followed by
  successful relaunch
- command-driven odd-address `STORE16` fault visibility
- command-driven soft-reset recovery after the `STORE16` fault

This coverage demonstrates the current command/kernel lifecycle in simulation.
It does not claim full verification of all command interleavings, compiler
behavior, cache behavior, or FPGA hardware bring-up.
