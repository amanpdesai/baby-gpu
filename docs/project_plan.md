# Custom FPGA GPU RTL Project Plan

This is the canonical project plan for UrbanaGPU-1. The linked documents expand
each section into implementation-ready detail.

## Project Goal

Build a small custom GPU-like graphics accelerator in portable SystemVerilog
RTL. The first target platform is the RealDigital Urbana FPGA board, while the
long-term architecture keeps the GPU core portable enough for future boards or
ASIC-oriented experiments.

Expanded docs:

- [Architecture](architecture.md)
- [Version 1 scope](version_1_scope.md)
- [Roadmap](roadmap.md)

## Core Design Philosophy

The FPGA board is a development platform, not the architecture. The core must
stay free of board-specific primitives and communicate through explicit
interfaces.

Expanded docs:

- [Design boundaries](design_boundaries.md)
- [ASIC portability](asic_portability.md)
- [Coding style](coding_style.md)

## Target Platform

Initial platform:

- RealDigital Urbana FPGA board
- AMD/Xilinx Spartan-7 FPGA
- 128 MB DDR3 memory
- video output
- USB/UART programming and communication
- buttons, switches, LEDs, and general I/O

Expanded doc:

- [Target platform](target_platform.md)

## Repository Structure

The repository separates documents, portable RTL, platform wrappers,
testbenches, generated test data, FPGA build scripts, and notes.

Expanded doc:

- [Repository structure](repository_structure.md)

## Major Design Boundaries

Portable RTL lives under `rtl/`. Platform-specific wrappers live under
`platform/`. The core can be simulated without Urbana files.

Expanded docs:

- [Design boundaries](design_boundaries.md)
- [Memory system](memory_system.md)
- [Video pipeline](video_pipeline.md)

## Clocking Strategy

Version 1 uses one clock domain:

```text
gpu_clk
reset_sync
```

Expanded doc:

- [Clocking and reset](clocking_reset.md)

## Memory Strategy

Start with a small RGB565 framebuffer in inferred memory or BRAM. Add DDR3 only
after simulation and BRAM scanout are working.

Expanded doc:

- [Memory system](memory_system.md)

## Video Strategy

The first hardware video targets are test patterns, then framebuffer scanout,
then GPU-updated framebuffer output.

Expanded doc:

- [Video pipeline](video_pipeline.md)

## Command Processor

Version 1 accepts compact 32-bit command packets:

- `NOP`
- `CLEAR`
- `FILL_RECT`
- `WAIT_IDLE`
- `SET_REGISTER`

Expanded doc:

- [Command format](command_format.md)

## Register Map

The register model exposes identity, status, control, framebuffer configuration,
command FIFO writes, and interrupt state.

Expanded doc:

- [Memory map](memory_map.md)

## Graphics Pipeline Milestones

Draw units are documented individually:

- [Clear engine](draw_units/clear_engine.md)
- [Rectangle fill engine](draw_units/rect_fill_engine.md)
- [Line engine](draw_units/line_engine.md)
- [Sprite engine](draw_units/sprite_engine.md)
- [Tile engine](draw_units/tile_engine.md)
- [Triangle rasterizer](draw_units/triangle_rasterizer.md)

Pipeline-level behavior is covered in:

- [Graphics pipeline](graphics_pipeline.md)

## Verification Plan

Every major module should have a unit testbench. Full-core simulations should
compare generated framebuffer output against golden frames.

Expanded doc:

- [Verification plan](verification_plan.md)

## FPGA Bring-Up Plan

Bring up the board in stages:

1. board skeleton
2. clock/reset
3. LEDs
4. video test patterns
5. framebuffer scanout
6. GPU core integration
7. host command input
8. DDR3

Expanded doc:

- [FPGA bring-up](fpga_bringup.md)

## ASIC-Portability Rules

The project avoids obvious ASIC-hostile patterns by isolating memories, PLLs,
I/O, and board-specific logic behind wrappers.

Expanded doc:

- [ASIC portability](asic_portability.md)

## Guiding Principle

Do not build a modern GPU first. Build a small, understandable, correct graphics
machine. Make it visible. Make it testable. Make it portable. Then make it
faster and more capable.
