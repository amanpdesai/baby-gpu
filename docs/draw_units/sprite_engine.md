# Sprite Engine

The sprite engine is a later draw unit for copying image data into the
framebuffer.

## Initial Goal

Blit fixed-size RGB565 sprites from a small sprite memory into the framebuffer.

```mermaid
flowchart LR
  Cmd[Sprite command] --> Addr[Sprite address generator]
  Addr --> Fetch[Sprite pixel fetch]
  Fetch --> Key[Optional transparent color key]
  Key --> Pixel[Framebuffer pixel write]
```

## Initial Features

- fixed-size sprites
- RGB565 pixels
- optional transparent color key
- sprite memory stored in BRAM first
- bounds-safe framebuffer writes

## Suggested Command Operands

```text
dst_x
dst_y
sprite_index
width
height
flags
transparent_color
```

## Transparency

If color keying is enabled, any fetched pixel matching `transparent_color` is
discarded rather than written.

## Memory Considerations

The sprite engine introduces read traffic in addition to framebuffer writes.
This is the first draw unit that needs memory arbitration beyond a pure writer.

## Test Cases

| Test | Expected Result |
| --- | --- |
| Opaque sprite | All sprite pixels copied. |
| Transparent key | Keyed pixels skipped. |
| Right-edge clip | No writes beyond framebuffer width. |
| Bottom-edge clip | No writes beyond framebuffer height. |
| Memory stall | Fetch and write state remains coherent. |

## Later Features

- variable sprite size
- horizontal and vertical flipping
- palette-indexed sprites
- priority
- sprite attribute table
