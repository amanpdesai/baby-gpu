# Command Format

The command stream is the host-facing control path. Commands configure
registers, launch kernels, wait for completion, and support a few compatibility
operations.

The command processor should stay small. It should validate packet structure and
trigger higher-level blocks. It should not implement kernel behavior directly.

## Header Word

Every command starts with a 32-bit header:

```text
31        24 23        16 15                         0
+------------+------------+---------------------------+
| opcode     | word_count | flags                     |
+------------+------------+---------------------------+
```

`word_count` includes the header word.

Reserved flag bits must be written as zero until documented. Strict validation
can reject nonzero reserved bits later.

## Command Set

| Opcode | Name | Words | Purpose |
| --- | --- | ---: | --- |
| `0x00` | `NOP` | 1 | No operation. |
| `0x01` | `CLEAR` | 2 | Compatibility clear command. |
| `0x02` | `FILL_RECT` | 5 | Compatibility rectangle command. |
| `0x03` | `WAIT_IDLE` | 1 | Wait until command/kernel/memory work is idle. |
| `0x10` | `SET_REGISTER` | 3 | Write one register by byte address. |
| `0x20` | `LAUNCH_KERNEL` | 1 | Launch programmable kernel using launch registers. |

`CLEAR` and `FILL_RECT` exist for smoke tests and host convenience. Long term
they should dispatch built-in kernels or microcode, not bypass the programmable
architecture with an unrelated path.

## `SET_REGISTER`

```text
word 0: header opcode=SET_REGISTER, word_count=3
word 1: register byte address
word 2: register write data
```

This command is the primary way to configure:

- control bits
- framebuffer configuration
- kernel launch registers
- interrupt/debug registers

## `LAUNCH_KERNEL`

```text
word 0: header opcode=LAUNCH_KERNEL, word_count=1
```

`LAUNCH_KERNEL` consumes launch state from the register file:

```text
PROGRAM_BASE
GRID_X
GRID_Y
GROUP_SIZE_X
GROUP_SIZE_Y
ARG_BASE
LAUNCH_FLAGS
```

The command processor must reject or report:

- launch while busy
- zero grid dimensions
- unsupported group size
- unsupported launch flags

Current RTL status:

- `LAUNCH_KERNEL` is decoded by the command processor.
- header flags must be zero.
- `GRID_X` and `GRID_Y` must be nonzero.
- the first supported group size is `GROUP_SIZE_X=4`, `GROUP_SIZE_Y=1`.
- `LAUNCH_FLAGS` must be zero.
- valid launches emit a one-cycle launch request and latch launch register
  values.
- `gpu_core` wires host launch registers into the command processor.
- `gpu_core` drives the programmable core from the latched launch request and
  routes programmable LSU traffic through the top-level memory interface.

Program-base validation is deferred until the integrated instruction-memory
contract is explicit. Current RTL uses the low instruction-address bits of
`PROGRAM_BASE` as a fetch offset but does not reject zero, unaligned, or
out-of-range values.

## `WAIT_IDLE`

`WAIT_IDLE` completes when:

- command FIFO has no command currently being decoded
- scheduler is idle
- SIMD core is idle
- all accepted memory requests from the active command/kernel are complete or
  architecturally accepted
- fixed-function compatibility engines are idle

`WAIT_IDLE` must not complete just because the command processor is idle.

## Compatibility `CLEAR`

```text
word 0: header opcode=CLEAR, word_count=2
word 1: color[15:0]
```

Current behavior can use the fixed clear engine. Long-term behavior should be
equivalent to launching an internal solid-fill kernel over the framebuffer.

## Compatibility `FILL_RECT`

```text
word 0: header opcode=FILL_RECT, word_count=5
word 1: x[15:0], y[15:0]
word 2: width[15:0], height[15:0]
word 3: color[15:0]
word 4: reserved
```

The reserved word must be zero. Current behavior can use the rectangle engine.
Long-term behavior should be equivalent to an internal bounded-fill kernel once
predication or divergence handling is specified.

## Error Handling

The command processor sets sticky error bits for:

- unknown opcode
- incorrect `word_count`
- unsupported flags
- launch while busy
- invalid launch configuration
- strict validation failure on reserved fields

Errors should never hang hardware. The command processor should return to a
safe idle/error state and wait for software to clear errors or reset.
