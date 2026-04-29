# Design Decisions

This file records decisions that affect architecture, verification, portability,
or bring-up.

## Decision Log

### Use BRAM or inferred framebuffer before DDR3

Status: accepted

Reason: a small 160x120 RGB565 framebuffer keeps early simulation and video
bring-up simple. DDR3 integration is valuable, but it should not block the first
visible GPU result.

### Keep vendor primitives out of the portable core

Status: accepted

Reason: isolating FPGA-specific resources behind wrappers keeps the core useful
for simulation, future boards, and possible ASIC experiments.
