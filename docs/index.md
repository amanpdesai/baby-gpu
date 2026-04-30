# Documentation Index

## Architecture Direction

| Document | Description |
| --- | --- |
| [architecture.md](architecture.md) | Top-level programmable GPU architecture and current direction. |
| [programming_model.md](programming_model.md) | Kernel launch model, work-items, lanes, host contract. |
| [isa.md](isa.md) | ISA envelope, register model, initial instruction set, extension rules. |
| [core_architecture.md](core_architecture.md) | SIMD core, scheduler, lane state, execution pipeline, scaling plan. |
| [memory_model.md](memory_model.md) | Global memory, framebuffer convention, scratchpad/cache plan. |
| [kernel_execution.md](kernel_execution.md) | Launch flow, scheduler algorithm, kernel tests, implementation order. |
| [roadmap.md](roadmap.md) | Implementation phases for the unified programmable architecture. |
| [agent_workflow.md](agent_workflow.md) | Main-thread and subagent workflow, checks, and handoff format. |
| [signoff_strategy.md](signoff_strategy.md) | Simulation, formal, FPGA, and ASIC-style verification discipline. |

## Existing Foundation Documents

| Document | Description |
| --- | --- |
| [project_plan.md](project_plan.md) | Original project goals and bring-up plan. |
| [repository_structure.md](repository_structure.md) | Source tree organization. |
| [design_boundaries.md](design_boundaries.md) | Portable RTL versus platform wrappers. |
| [design_decisions.md](design_decisions.md) | Decision log. |
| [coding_style.md](coding_style.md) | SystemVerilog coding rules. |
| [clocking_reset.md](clocking_reset.md) | Clock and reset policy. |
| [target_platform.md](target_platform.md) | RealDigital Urbana platform assumptions. |
| [toolchain.md](toolchain.md) | Native toolchain expectations. |

## Current Fixed-Function Bring-Up Docs

These documents describe useful infrastructure and smoke-test blocks. They do
not override the programmable architecture direction.

| Document | Description |
| --- | --- |
| [command_format.md](command_format.md) | Existing command packet format. |
| [memory_map.md](memory_map.md) | Host-visible registers. |
| [graphics_pipeline.md](graphics_pipeline.md) | Current fixed-function draw-unit pipeline. |
| [memory_system.md](memory_system.md) | Initial framebuffer and memory interface notes. |
| [video_pipeline.md](video_pipeline.md) | Scanout and scaling plan. |

## Verification and Implementation Support

| Document | Description |
| --- | --- |
| [verification_plan.md](verification_plan.md) | Simulation, golden tests, and verification stack. |
| [formal_verification.md](formal_verification.md) | Formal proof strategy. |
| [coverage_plan.md](coverage_plan.md) | Coverage expectations. |
| [timing_constraints.md](timing_constraints.md) | Timing constraint planning. |
| [asic_portability.md](asic_portability.md) | ASIC portability concerns. |
| [asic_signoff_flow.md](asic_signoff_flow.md) | ASIC signoff planning. |
| [dft_plan.md](dft_plan.md) | DFT planning. |
| [sram_strategy.md](sram_strategy.md) | SRAM and memory wrapper strategy. |

## Priority Reading Order

Read these first before adding new RTL:

1. [architecture.md](architecture.md)
2. [programming_model.md](programming_model.md)
3. [isa.md](isa.md)
4. [core_architecture.md](core_architecture.md)
5. [memory_model.md](memory_model.md)
6. [kernel_execution.md](kernel_execution.md)
7. [roadmap.md](roadmap.md)
