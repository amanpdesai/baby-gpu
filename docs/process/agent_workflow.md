# Agent Workflow and Handoff

This document captures the working process for AI-assisted development on
UrbanaGPU. It exists so work can continue after context compaction, a new chat,
or a switch from single-agent work to multiple subagents.

The default rule is:

```text
main thread owns architecture, integration, final checks, commits, and pushes
subagents own bounded leaf tasks with disjoint files
```

Do not let parallel work replace design ownership. Use subagents only when the
task can be split without hidden interface conflicts.

## Current Project Direction

The active architecture is a unified programmable tiny GPU.

Primary docs:

- [architecture.md](../architecture/architecture.md)
- [programming_model.md](../architecture/programming_model.md)
- [isa.md](../architecture/isa.md)
- [core_architecture.md](../architecture/core_architecture.md)
- [memory_model.md](../architecture/memory_model.md)
- [kernel_execution.md](../architecture/kernel_execution.md)
- [roadmap.md](../implementation/roadmap.md)

Current implementation state:

- command FIFO exists
- command processor exists
- register file exists
- fixed-function clear/rectangle smoke engines exist
- framebuffer writer exists
- lane register file exists
- SIMD ALU exists
- special register mux exists
- instruction memory model exists
- instruction decoder exists
- scheduler exists for 1 core x 4 lanes
- blocking LSU exists
- programmable core runs simulation kernels
- `vector_add`, `STORE16`, framebuffer gradient, bounded fill, and offset fill
  integration tests exist
- command-level `gpu_core` and lower-level programmable-core integration tests
  use checked `.kgpu`/`.memh` assembler fixtures
- directed malformed illegal-instruction fixtures use checked `.word` raw
  encodings
- CMP, convergent BRA, and predicated stores exist
- open-source synthesis smoke exists
- formal proofs exist for FIFO, clear engine, SIMD ALU, framebuffer writer,
  work scheduler smoke and sticky-error contracts, lane register file smoke
  contracts, special register mux smoke, instruction decoder smoke contracts,
  instruction decoder unassigned-opcode side-effect suppression, instruction
  memory smoke and high-fetch-fault contracts, and LSU prep, invalid-op, and
  public status contracts
- bounded formal covers exist for special-register illegal IDs and instruction
  decoder CMP edge reachability
- simulation data memory has bounded formal smoke coverage plus reachability
  covers for byte masks, halfword masks, response backpressure, and readback
- open-source synthesis smoke covers leaf blocks plus the integrated SIMD and
  programmable core path

Next implementation target:

```text
verification hardening
Vivado synthesis smoke
FPGA-facing bring-up path
```

After that:

```text
lane-count scaling experiments
scratchpad experiment
memory request IDs before multi-core
```

## Main-Thread Commit Process

Use this process for every commit.

### 1. Start Clean

```bash
rtk git status --short --branch
```

Expected before starting a new slice:

```text
## main...origin/main
```

If the tree is dirty, understand and preserve the existing changes. Never
revert work casually.

### 2. Define a Small Slice

Good slice examples:

```text
formal proof for a leaf block
corner-case integration test
Vivado synthesis smoke target
LSU protocol property
docs alignment after an implemented feature
```

Avoid committing broad mixed work such as:

```text
decoder + scheduler + LSU + docs + platform wrapper
```

Keep commits reviewable.

### 3. Implement With Existing Style

RTL expectations:

- portable SystemVerilog
- `always_ff` for sequential logic
- `always_comb` for combinational logic
- valid/ready payload stability
- synchronous reset inside core RTL
- no vendor primitives in `rtl/`
- bounded parameters, but no speculative over-generalization
- no hidden single-core assumptions in interfaces that will need IDs later

Tests should be deterministic and include timeouts for integration tests that
can hang.

### 4. Run Required Checks

Every code commit must run:

```bash
rtk make sim
rtk make lint
rtk err make formal
rtk make synth-yosys
rtk git diff --check
```

Doc-only commits still run:

```bash
rtk git diff --check
```

When cheap, also run:

```bash
rtk make sim
rtk make lint
rtk err make formal
rtk make synth-yosys
```

### 5. Review Scope

Before staging:

```bash
rtk git diff --stat
rtk git status --short --branch
```

After staging:

```bash
rtk git diff --cached --stat
rtk git diff --cached --check
```

Make sure only intended files are staged.

### 6. Commit With Correct Identity

Verify identity if there has been any environment change:

```bash
rtk git config --get user.name
rtk git config --get user.email
```

Expected:

```text
Aman Desai
amanpdesai@gmail.com
```

Commit style:

```text
rtl: add instruction decoder
rtl: add special register mux
rtl: add basic SIMD core
docs: clarify ISA encoding
```

### 7. Push and Verify Sync

```bash
rtk git push origin main
rtk git status --short --branch
rtk git rev-list --left-right --count origin/main...main
```

Expected:

```text
## main...origin/main
0 0
```

Also verify no placeholder identity appears:

```bash
rtk git log --all --author=YOUR --format=%h%x09%an%x09%ae%x09%s
```

Expected: no output.

## When to Use Subagents

Use subagents when all of these are true:

- task is concrete and bounded
- write set is disjoint from other active work
- interface dependency is already documented or owned by main thread
- result can be tested independently
- main thread can review and integrate without redoing the work

Do not use subagents for:

- architecture decisions
- shared package/interface churn without coordination
- tightly coupled integration files
- urgent blocking work that the main thread needs immediately
- broad refactors touching many modules

## Recommended Parallel Pattern

For the current stage, use this pattern:

```text
main thread:
  owns architecture, branch state, final integration, full gates, commits

subagent A:
  implement or review a bounded formal proof

subagent B:
  implement or review an integration corner test

main thread:
  resolves review blockers
  reruns sim/lint/formal/synth
  commits and pushes
```

## Safe Subagent Work Packages

### Formal Proof Agent

Ownership:

```text
formal/harnesses/<block>_formal.sv
formal/scripts/<block>.sby
```

Scope:

- prove one narrow block contract
- keep solver runtime appropriate for the normal `make formal` gate
- avoid broad RTL rewrites unless the proof exposes a real bug
- document residual risks when a proof is intentionally smoke-level

Do not modify:

```text
unrelated RTL
integration tests
architecture docs
```

Required checks:

```bash
rtk make sim
rtk make lint
rtk err make formal
rtk make synth-yosys
rtk git diff --check
```

### Integration Test Agent

Ownership:

```text
tb/integration/<test>.sv
```

Scope:

- add a deterministic encoded-kernel test
- initialize memory fixtures explicitly
- check expected memory contents
- include timeout and sticky error checks
- prefer corner cases that can fail for wrong address math, masks, or predicate
  behavior

Do not modify:

```text
rtl/core/simd_core.sv
rtl/common/isa_pkg.sv
rtl/core/instruction_decoder.sv
```

Required checks:

```bash
rtk make sim
rtk make lint
rtk err make formal
rtk make synth-yosys
rtk git diff --check
```

### Main-Thread Integration

The main thread owns shared interfaces, ISA changes, scheduler/core/LSU
coordination, final review resolution, full checks, commits, and pushes.

## Subagent Prompt Template

Use this template when spawning a worker:

```text
You are working in /home/amandesai/baby-gpu.

You are not alone in the codebase. Do not revert edits made by others. Keep
your writes inside the ownership set below unless absolutely necessary.

Architecture context:
- unified programmable tiny GPU
- 1 core x 4 lanes first target
- 32-bit instructions and registers
- hardwired R0
- SIMD lockstep, no divergence yet
- framebuffer is global memory

Ownership:
<list files>

Task:
<specific implementation>

Constraints:
- follow docs/architecture/isa.md and docs/architecture/core_architecture.md
- use existing RTL style
- add unit tests
- no vendor primitives
- no broad refactors

Before final response run:
rtk make sim
rtk make lint
rtk make formal
rtk git diff --check

Final response must include:
- files changed
- behavior implemented
- checks run and results
- any residual risk
```

## Handoff Summary Format

At the end of a session, capture:

```text
Current branch:
Latest commit:
Working tree status:
Checks last run:
Architecture direction:
Implemented modules:
Next planned slice:
Known risks:
```

Example:

```text
Current branch: main
Latest commit: 8c40081 tools: target gpu core in vivado smoke
Working tree status: clean, synced with origin/main
Checks last run: make sim, make lint, make formal, make synth-yosys, git diff --check
Architecture direction: unified programmable tiny GPU, 1 core x 4 lanes
Implemented modules: FIFO, command processor, register file, fixed smoke
engines, framebuffer writer, instruction memory, instruction decoder, special
register mux, lane register file, SIMD ALU, scheduler, LSU, simulation memory,
programmable core
Next planned slice: continue verification hardening around command/kernel
lifecycle, then add FPGA-facing wrappers once the board part and IO plan are
known
Known risks: no caches, scratchpad, multi-core routing IDs, DDR/video platform
integration, or Vivado board timing closure yet
```

## PR Strategy

For this project stage, prefer direct commits to `main` after local checks unless
the user requests PRs.

If using PRs, group them by meaningful milestones:

```text
PR 1: decoder + special register mux
PR 2: basic SIMD core
PR 3: instruction memory + scheduler
PR 4: LSU + vector_add
```

Do not create one PR per tiny file. The overhead is not worth it unless there is
a human review process around each PR.

## Things Not to Parallelize Yet

Avoid parallel work on these until interfaces stabilize:

- `simd_core.sv`
- scheduler
- LSU response routing
- global memory interface shape
- ISA encoding changes
- register map changes

These affect too many modules and should stay main-thread owned.
