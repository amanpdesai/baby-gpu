# Verification Plan

Verification starts before FPGA bring-up. Every major module should have a
simulation path and a small set of targeted tests.

## Verification Pyramid

```mermaid
flowchart TB
  Formal[Small Formal Checks] --> Unit[Unit Testbenches]
  Unit --> Integration[Core Integration Tests]
  Integration --> Golden[Framebuffer Golden Tests]
  Golden --> FPGA[FPGA Bring-Up Tests]
```

## Unit Tests

| Module | Required Tests |
| --- | --- |
| FIFO | reset, fill, empty, full, simultaneous push/pop, overflow protection. |
| Command processor | valid packets, unknown opcode, wrong length, WAIT_IDLE. |
| Register file | reset values, read/write behavior, reserved bits, sticky errors. |
| Clear engine | full frame, small frame, backpressure, reset during operation. |
| Rect engine | inside bounds, partial clipping, full clipping, zero dimensions. |
| Framebuffer writer | address calculation, byte masks, write handshake stability. |
| Memory arbiter | simultaneous clients, priority behavior, no dropped requests. |
| Video scanout | coordinate generation, scale mapping, frame boundary pulses. |

## Integration Tests

Integration tests run the full portable core with:

- simulation command source
- simulation memory
- simulation video sink

Minimum command streams:

1. clear black
2. clear solid color
3. one centered rectangle
4. overlapping rectangles
5. clipped rectangles on each edge
6. WAIT_IDLE after each draw
7. malformed command error path

## Golden Frame Tests

Golden tests compare generated framebuffer contents against expected images.

```mermaid
flowchart LR
  Cmd[Command Stream] --> Sim[RTL Simulation]
  Sim --> Frame[Generated Frame]
  Ref[Reference Generator] --> Golden[Expected Frame]
  Frame --> Compare[Image Compare]
  Golden --> Compare
```

Expected data lives under:

```text
tests/command_streams/
tests/expected_frames/
tests/generated_frames/
```

## Assertions

Add simple assertions for protocol mistakes:

- request payload stable while `valid && !ready`
- no FIFO pop when empty
- no FIFO push when full unless simultaneous pop allows it
- draw unit `done` only follows an accepted `start`
- memory write mask is nonzero for writes

## FPGA Validation

FPGA tests should be observable with minimal tooling:

- LED heartbeat
- LED error indicator
- video test pattern
- static framebuffer
- clear command result
- rectangle command result
- UART command smoke test

## Exit Criteria for Version 1

Version 1 verification is acceptable when:

- clear and rectangle unit tests pass
- core integration command streams pass
- generated frames match golden frames
- basic lint flow has no intentional latch warnings
- Urbana board displays the expected framebuffer result
