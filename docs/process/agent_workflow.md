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
- ISA encoding has an initial locked envelope

Next implementation target:

```text
instruction decoder
special register mux
basic SIMD core skeleton
```

After that:

```text
instruction memory model
scheduler
blocking load/store unit
vector_add kernel simulation
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
instruction decoder + unit test
special register mux + unit test
basic SIMD core + unit test
LSU request path + unit test
vector_add integration test
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
rtk make formal
rtk git diff --check
```

`make formal` may currently report that no SymbiYosys jobs exist. That is an
acceptable pass until formal jobs are added.

Doc-only commits still run:

```bash
rtk git diff --check
```

When cheap, also run:

```bash
rtk make sim
rtk make lint
rtk make formal
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

For the next stage, use this pattern:

```text
main thread:
  creates shared interface/package if needed
  owns final integration and commit

subagent A:
  instruction decoder

subagent B:
  special register mux

main thread:
  reviews A/B
  integrates basic SIMD core
  runs full checks
  commits and pushes
```

## Safe Subagent Work Packages

### Instruction Decoder Agent

Ownership:

```text
rtl/core/instruction_decoder.sv
tb/unit/tb_instruction_decoder.sv
```

Scope:

- decode `NOP`
- decode `END`
- decode `MOVI`
- decode `MOVSR`
- decode `ADD`
- decode `MUL`
- emit illegal flag for unknown opcodes
- extract `rd`, `ra`, `rb`, `imm18`, and special-register ID
- map ALU instructions to existing `simd_alu` operation values

Do not modify:

```text
rtl/core/simd_core.sv
rtl/core/lane_register_file.sv
rtl/core/simd_alu.sv
docs/architecture/isa.md
```

If the decoder needs constants, ask main thread to add a shared package first.

Required checks:

```bash
rtk make sim
rtk make lint
rtk make formal
rtk git diff --check
```

### Special Register Agent

Ownership:

```text
rtl/core/special_registers.sv
tb/unit/tb_special_registers.sv
```

Scope:

- output per-lane selected special-register values
- support `lane_id`
- support `global_id_x`
- support `global_id_y`
- support `linear_global_id`
- support `group_id_x`
- support `group_id_y`
- support `local_id_x`
- support `local_id_y`
- support `arg_base`
- support `framebuffer_base`
- support `framebuffer_width`
- support `framebuffer_height`
- emit illegal flag for unknown special-register IDs

Do not modify:

```text
rtl/core/simd_core.sv
rtl/core/lane_register_file.sv
rtl/core/simd_alu.sv
docs/architecture/isa.md
```

Required checks:

```bash
rtk make sim
rtk make lint
rtk make formal
rtk git diff --check
```

### Main-Thread Integration

After decoder and special-register mux land, main thread owns:

```text
rtl/core/simd_core.sv
tb/unit/tb_simd_core_basic.sv
```

First basic programs:

```text
MOVI R1, 5
MOVI R2, 7
ADD  R3, R1, R2
END
```

Expected:

```text
all lanes R3 = 12
core done
no error
```

Second program:

```text
MOVSR R1, lane_id
ADD   R2, R1, R1
END
```

Expected:

```text
lane0 R2 = 0
lane1 R2 = 2
lane2 R2 = 4
lane3 R2 = 6
```

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
Latest commit: 6080e90 rtl: add SIMD lane datapath blocks
Working tree status: clean, synced with origin/main
Checks last run: make sim, make lint, make formal, git diff --check
Architecture direction: unified programmable tiny GPU, 1 core x 4 lanes
Implemented modules: FIFO, command processor, register file, fixed smoke
engines, framebuffer writer, lane register file, SIMD ALU
Next planned slice: instruction decoder + special register mux
Known risks: no instruction fetch/scheduler/LSU yet; fixed-function engines are
bring-up infrastructure only
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
