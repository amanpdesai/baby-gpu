# Documentation Index

The documentation is grouped by how it is used during design work:

- `architecture/`: product direction, programming model, ISA, core design, and pipeline behavior.
- `implementation/`: repo structure, staged build plan, command/memory maps, timing, reset, and SRAM strategy.
- `verification/`: simulation, formal, coverage, DFT, signoff, and ASIC-style tapeout discipline.
- `platform/`: FPGA board assumptions, toolchain setup, bring-up, and ASIC portability notes.
- `process/`: coding conventions and main-thread/subagent workflow.

## Start Here

| Document | Purpose |
| --- | --- |
| [architecture/architecture.md](architecture/architecture.md) | Top-level programmable GPU direction and current architecture stance. |
| [architecture/programming_model.md](architecture/programming_model.md) | Kernel launch model, work-items, lanes, masks, and host contract. |
| [architecture/isa.md](architecture/isa.md) | ISA envelope, register model, initial instructions, and extension rules. |
| [architecture/core_architecture.md](architecture/core_architecture.md) | SIMD core, scheduler, lane state, execution pipeline, and scaling plan. |
| [architecture/memory_model.md](architecture/memory_model.md) | Global memory, framebuffer convention, scratchpad/cache plan, and ordering. |
| [architecture/kernel_execution.md](architecture/kernel_execution.md) | Launch flow, scheduler algorithm, kernel tests, and implementation order. |
| [implementation/roadmap.md](implementation/roadmap.md) | Phased implementation plan and current milestone sequencing. |

## Architecture

| Document | Purpose |
| --- | --- |
| [architecture/architecture.md](architecture/architecture.md) | System-level GPU architecture. |
| [architecture/programming_model.md](architecture/programming_model.md) | Programmer-visible execution model. |
| [architecture/isa.md](architecture/isa.md) | Instruction set and encoding policy. |
| [architecture/core_architecture.md](architecture/core_architecture.md) | Programmable core internals. |
| [architecture/kernel_execution.md](architecture/kernel_execution.md) | Kernel launch and scheduling behavior. |
| [architecture/memory_model.md](architecture/memory_model.md) | Memory hierarchy direction and rules. |
| [architecture/graphics_pipeline.md](architecture/graphics_pipeline.md) | Graphics pipeline behavior. |
| [architecture/video_pipeline.md](architecture/video_pipeline.md) | Video output pipeline behavior. |
| [architecture/version_1_scope.md](architecture/version_1_scope.md) | Version 1 boundaries. |
| [architecture/design_boundaries.md](architecture/design_boundaries.md) | Portable RTL versus platform-specific wrappers. |
| [architecture/design_decisions.md](architecture/design_decisions.md) | Decision log. |

## Draw Units

| Document | Purpose |
| --- | --- |
| [architecture/draw_units/clear_engine.md](architecture/draw_units/clear_engine.md) | Clear engine behavior. |
| [architecture/draw_units/rect_fill_engine.md](architecture/draw_units/rect_fill_engine.md) | Rectangle fill engine behavior. |
| [architecture/draw_units/line_engine.md](architecture/draw_units/line_engine.md) | Line engine behavior. |
| [architecture/draw_units/sprite_engine.md](architecture/draw_units/sprite_engine.md) | Sprite engine behavior. |
| [architecture/draw_units/tile_engine.md](architecture/draw_units/tile_engine.md) | Tile engine behavior. |
| [architecture/draw_units/triangle_rasterizer.md](architecture/draw_units/triangle_rasterizer.md) | Triangle rasterizer behavior. |

## Implementation

| Document | Purpose |
| --- | --- |
| [implementation/project_plan.md](implementation/project_plan.md) | Original project goals and plan. |
| [implementation/roadmap.md](implementation/roadmap.md) | Current staged implementation plan. |
| [implementation/repository_structure.md](implementation/repository_structure.md) | Source tree organization. |
| [implementation/command_format.md](implementation/command_format.md) | Host command layout. |
| [implementation/memory_map.md](implementation/memory_map.md) | Register and memory map. |
| [implementation/memory_system.md](implementation/memory_system.md) | Memory system implementation notes. |
| [implementation/clocking_reset.md](implementation/clocking_reset.md) | Clock and reset policy. |
| [implementation/sram_strategy.md](implementation/sram_strategy.md) | SRAM and memory wrapper strategy. |
| [implementation/timing_constraints.md](implementation/timing_constraints.md) | Timing constraint planning. |

## Verification and Signoff

| Document | Purpose |
| --- | --- |
| [verification/verification_plan.md](verification/verification_plan.md) | Simulation, formal, and regression plan. |
| [verification/formal_verification.md](verification/formal_verification.md) | Formal property strategy. |
| [verification/coverage_plan.md](verification/coverage_plan.md) | Functional and formal coverage plan. |
| [verification/signoff_strategy.md](verification/signoff_strategy.md) | Industry-style pre-tapeout discipline. |
| [verification/asic_signoff_flow.md](verification/asic_signoff_flow.md) | ASIC signoff flow outline. |
| [verification/dft_plan.md](verification/dft_plan.md) | DFT planning. |

## Platform

| Document | Purpose |
| --- | --- |
| [platform/target_platform.md](platform/target_platform.md) | RealDigital Urbana target assumptions. |
| [platform/toolchain.md](platform/toolchain.md) | Required tools and setup. |
| [platform/fpga_bringup.md](platform/fpga_bringup.md) | FPGA bring-up sequence. |
| [platform/asic_portability.md](platform/asic_portability.md) | ASIC portability constraints and risks. |

## Process

| Document | Purpose |
| --- | --- |
| [process/agent_workflow.md](process/agent_workflow.md) | Main-thread/subagent workflow, checks, and handoff format. |
| [process/coding_style.md](process/coding_style.md) | SystemVerilog coding rules. |
