# Documentation Index

This directory expands the main project plan into implementation-ready design
documents. Each document is scoped so it can be reviewed independently before
RTL is written.

## System-Level Documents

| Topic | Document | Purpose |
| --- | --- | --- |
| Project plan | [project_plan.md](project_plan.md) | Canonical plan with links to expanded subpoint docs. |
| Architecture | [architecture.md](architecture.md) | Defines the portable GPU core and data flow. |
| Target platform | [target_platform.md](target_platform.md) | Captures Urbana assumptions and board-facing risks. |
| Repository structure | [repository_structure.md](repository_structure.md) | Explains where source, tests, tools, and notes live. |
| Design boundaries | [design_boundaries.md](design_boundaries.md) | Separates portable RTL from FPGA-specific wrappers. |
| Coding style | [coding_style.md](coding_style.md) | Defines RTL rules used across the project. |
| Clocking and reset | [clocking_reset.md](clocking_reset.md) | Defines the initial single-clock strategy and later CDC plan. |
| Memory system | [memory_system.md](memory_system.md) | Defines abstract memory access, framebuffer layout, and arbitration. |
| Video pipeline | [video_pipeline.md](video_pipeline.md) | Defines scanout, scaling, test patterns, and display bring-up. |
| Command format | [command_format.md](command_format.md) | Defines command words, packet layout, dispatch, and errors. |
| Memory map | [memory_map.md](memory_map.md) | Defines the host-visible register model. |
| Graphics pipeline | [graphics_pipeline.md](graphics_pipeline.md) | Explains draw-unit sequencing and pixel write flow. |
| Verification | [verification_plan.md](verification_plan.md) | Defines unit, integration, image, and FPGA validation. |
| FPGA bring-up | [fpga_bringup.md](fpga_bringup.md) | Defines the staged Urbana hardware bring-up plan. |
| ASIC portability | [asic_portability.md](asic_portability.md) | Captures rules that keep the core replaceable and portable. |
| Roadmap | [roadmap.md](roadmap.md) | Tracks staged implementation order beyond Version 1. |
| Version 1 | [version_1_scope.md](version_1_scope.md) | Defines the exact done criteria for UrbanaGPU-1. |

## Draw Unit Documents

| Unit | Document |
| --- | --- |
| Clear engine | [draw_units/clear_engine.md](draw_units/clear_engine.md) |
| Rectangle fill engine | [draw_units/rect_fill_engine.md](draw_units/rect_fill_engine.md) |
| Line engine | [draw_units/line_engine.md](draw_units/line_engine.md) |
| Sprite engine | [draw_units/sprite_engine.md](draw_units/sprite_engine.md) |
| Tile engine | [draw_units/tile_engine.md](draw_units/tile_engine.md) |
| Triangle rasterizer | [draw_units/triangle_rasterizer.md](draw_units/triangle_rasterizer.md) |

## Recommended Reading Order

1. [project_plan.md](project_plan.md)
2. [architecture.md](architecture.md)
3. [design_boundaries.md](design_boundaries.md)
4. [memory_system.md](memory_system.md)
5. [command_format.md](command_format.md)
6. [graphics_pipeline.md](graphics_pipeline.md)
7. [verification_plan.md](verification_plan.md)
8. [fpga_bringup.md](fpga_bringup.md)
