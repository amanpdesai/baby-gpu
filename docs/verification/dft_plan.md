# DFT Plan

Design-for-test should be considered before any ASIC hardening experiment. It
does not need to affect Version 1 FPGA bring-up, but the top-level ASIC wrapper
should reserve a clean strategy.

## Goals

- make sequential state scannable in an ASIC implementation
- provide test-mode control over clocks and resets
- keep test logic outside the portable graphics behavior where possible
- avoid adding FPGA-only complexity to the core

## Initial DFT Interface

Potential ASIC wrapper signals:

```text
test_mode
scan_enable
scan_in
scan_out
test_reset_n
test_clock_enable
```

These belong in ASIC wrappers, not in every draw unit unless a real DFT flow
requires it.

## Scan Strategy

```mermaid
flowchart LR
  Pads[Test Pads] --> DFT[ASIC DFT Wrapper]
  DFT --> Core[GPU Core]
  Core --> Scan[Scan Chains]
  Scan --> Pads
```

## Memory Test Strategy

Framebuffer memory should be outside the portable core and behind SRAM wrappers.
That makes memory test a wrapper problem:

- SRAM BIST can live beside SRAM macros
- scan can bypass or isolate memory interfaces
- simulation memory does not need test circuitry

## DFT Decisions to Make Later

| Decision | Needed When |
| --- | --- |
| Number of scan chains | Before ASIC synthesis with DFT insertion. |
| Test clocking model | Before top-level timing constraints. |
| Memory BIST approach | Before SRAM macro integration. |
| Reset behavior in test mode | Before scan insertion. |
| Whether to expose JTAG | Before pad-ring planning. |

## Documentation Requirements

Every test-only path should have:

- purpose
- owning wrapper
- timing assumption
- FPGA behavior, if any
- ASIC behavior
