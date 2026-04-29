# Graphics Pipeline

The graphics pipeline converts commands into clipped pixel writes.

## Pipeline Stages

```mermaid
flowchart LR
  Cmd[Command Processor] --> Dispatch[Draw Dispatch]
  Dispatch --> Draw[Draw Unit]
  Draw --> Clip[Bounds and Clip]
  Clip --> Pix[Pixel Pipeline]
  Pix --> Addr[Framebuffer Writer]
  Addr --> Mem[Memory Arbiter]
```

## Version 1 Units

Version 1 implements:

- clear engine
- rectangle fill engine

Future units:

- line engine
- sprite engine
- tile engine
- triangle rasterizer

## Draw Unit Protocol

Draw units should use a common control shape:

```text
start
config payload
busy
done
error
pixel_valid
pixel_ready
pixel_x
pixel_y
pixel_color
```

The command processor asserts `start` for one accepted operation. The draw unit
owns sequencing until it asserts `done`.

## Pixel Pipeline Contract

The pixel pipeline accepts candidate pixels and decides whether to forward them
to memory.

It is responsible for:

- framebuffer bounds checking
- future clip rectangle handling
- future color format conversion
- optional statistics and debug counters

It is not responsible for:

- command decoding
- shape iteration
- memory arbitration
- platform memory timing

## Backpressure

All pixel-producing draw units must respect `pixel_ready`. If the memory path
stalls, the draw unit must hold its current pixel stable until accepted.

## Clipping Strategy

Version 1 clipping is conservative:

- out-of-bounds pixels are discarded
- rectangles partially outside the framebuffer are clipped
- rectangles fully outside the framebuffer complete as no-ops
- zero-width or zero-height rectangles complete as no-ops

## Throughput Expectations

The first implementation can emit one pixel per accepted cycle. If memory stalls
or scanout has priority, drawing may take longer. Correct completion and stable
video matter more than peak fill rate.
