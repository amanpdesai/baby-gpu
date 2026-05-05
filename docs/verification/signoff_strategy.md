# Verification and Signoff Strategy

UrbanaGPU should be developed like hardware that may eventually tape out, even
when the immediate target is RTL simulation and the Urbana FPGA board. The goal
is to push as far as practical with open-source tools, Vivado, and disciplined
verification.

This does not mean physical design blocks every RTL commit. It means every
module has a clear path from specification to simulation, formal proof,
synthesis, FPGA bring-up, and ASIC-style signoff checks.

## Verification Lanes

Each feature should move through these lanes:

```text
specification
  -> unit simulation
  -> integration simulation
  -> formal proof where applicable
  -> lint/static checks
  -> synthesis smoke
  -> FPGA validation when platform-facing
  -> ASIC-style hardening when stable
```

No single lane replaces the others. Formal proofs do not replace golden
simulation. FPGA display output does not replace deterministic simulation.
Synthesis does not prove behavior.

## Definition of Done by Maturity

### Experimental RTL

Acceptable for early exploration:

- documented interface
- unit simulation
- lint clean
- no obvious synthesis-hostile constructs

### Core RTL

Required for reusable core modules:

- documented behavior and reset semantics
- unit simulation
- integration simulation if connected to flow
- valid/ready payload stability checked by test or proof
- formal safety proof when the state space is suitable
- lint clean
- synthesis smoke through open-source tools

Examples:

- FIFO
- instruction decoder
- lane register file
- SIMD ALU
- special register mux
- scheduler
- LSU
- memory arbiter

### Tapeout-Candidate RTL

Required before any ASIC experiment:

- all core RTL criteria
- formal proof suite for protocol/control blocks
- regression simulation for kernels
- synthesis clean with no unjustified warnings
- timing constraints exist
- no unconstrained clocks or major paths
- CDC/RDC story documented
- memory wrappers separated from core logic
- reset behavior verified
- gate-level or equivalence plan documented

## Required Checks per Commit

For code commits:

```bash
rtk make sim
rtk make lint
rtk make formal
rtk git diff --check
```

For architecture-only docs:

```bash
rtk git diff --check
```

Prefer also running:

```bash
rtk make sim
rtk make lint
rtk make formal
```

## Formal Verification Policy

Formal is mandatory for reusable control/protocol blocks unless there is a clear
reason it is not suitable.

Initial proof priorities:

| Block | Proof class |
| --- | --- |
| `command_fifo` | no overflow/underflow, order preservation |
| valid/ready clients | payload stability under stall |
| `instruction_decoder` | legal decode, illegal opcode detection |
| `lane_register_file` | R0 immutable, writes affect only enabled lanes |
| `special_registers` | legal selection, illegal ID detection |
| scheduler | ID bounds, tail-lane masks, completion |
| LSU | request stability, alignment errors, no lost responses |
| memory arbiter | one-hot grants, no dropped accepted request |

Formal proof style:

- assumptions describe only the environment
- assertions describe design obligations
- covers show useful states are reachable
- liveness requires explicit fairness assumptions
- no assumption should hide a design bug

## Simulation Policy

Simulation remains the top-level functional truth.

Required simulation classes:

- unit tests for leaf modules
- integration tests for connected datapaths
- command-stream tests for host control
- kernel tests with initialized memory and expected output
- framebuffer tests comparing generated memory or images
- timeout checks for any test that can hang
- sticky error checks

First programmable kernel regression targets:

```text
vector_add
framebuffer_gradient
bounded fill or predicated store test
```

## Synthesis Policy

Open-source synthesis should be used early for structural feedback. Vivado
synthesis should be used before FPGA-facing milestones.

Open-source path:

```text
Yosys read/check/synth
OpenSTA timing experiments when constraints exist
```

FPGA path:

```text
Vivado synth_design
Vivado opt/place/route for platform tops
timing summary
utilization report
bitstream generation
```

ASIC-style path:

```text
Yosys synthesis
OpenSTA
OpenROAD/OpenLane experiments
Magic/KLayout/Netgen when a PDK flow is selected
```

No warning should be ignored without a written reason.

## FPGA Validation Policy

FPGA bring-up should be staged:

1. board skeleton builds
2. clock/reset/LED heartbeat
3. video test pattern
4. framebuffer scanout from BRAM
5. fixed smoke command path
6. programmable kernel writes framebuffer
7. host command input
8. larger memory wrapper

For every FPGA demo, keep a simulation equivalent. If hardware shows a picture
but the simulation has no golden check, the feature is not verified.

## ASIC-Style Signoff Policy

ASIC-style checks are staged and open-source driven where possible.

Target checks:

- RTL lint
- formal proof suite
- synthesis
- equivalence strategy
- static timing
- CDC/RDC once multiple clocks/resets exist
- DFT plan
- SRAM wrapper plan
- floorplan experiment
- DRC/LVS when a PDK flow exists
- antenna/IR/EM as stretch signoff topics

The first hardening target should be a small core subset, not the whole Urbana
platform.

Candidate first hardening subset:

```text
instruction decoder
lane register file
SIMD ALU
special register mux
scheduler
blocking LSU
small memory wrapper
```

## Tool Targets to Add

Current targets:

```text
make sim
make lint
make formal
make synth-yosys
make check-tools
make tool-versions
```

Planned targets:

```text
make synth-vivado
make sta
make formal-core
make regress
make fpga-smoke
make signoff-smoke
```

These targets should fail loudly on real errors and keep generated artifacts out
of Git.

`make synth-yosys` is currently a smoke target for Yosys-compatible RTL blocks:
leaf modules plus the integrated `gpu_core` and `programmable_core` paths. It
intentionally fails on Yosys warnings.

## Non-Negotiables

- Do not merge core RTL without simulation.
- Do not treat visual FPGA output as sufficient verification.
- Do not add protocol-heavy blocks without formal plans.
- Do not add caches before memory ordering is documented.
- Do not add multiple cores before response IDs and arbitration are specified.
- Do not proceed toward ASIC experiments with unconstrained or unlinted RTL.
- Do not rely on proprietary tools only; keep an open-source path alive.

## Practical Standard

The project should use industry-style discipline scaled to a solo/open-source
environment:

```text
spec -> RTL -> unit sim -> integration sim -> formal -> lint -> synth -> timing -> FPGA -> ASIC experiment
```

The bar is not "perfect signoff tomorrow." The bar is that every feature moves
in the direction of a signoff-capable design instead of becoming a demo-only RTL
fragment.
