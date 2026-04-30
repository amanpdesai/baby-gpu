# Memory Map

All register addresses are byte offsets. Registers are 32 bits unless noted.

This map covers the host-visible control plane. Kernel instruction memory and
global data memory are separate architectural spaces described in
[memory_model.md](memory_model.md).

## Base Registers

| Address | Name | Reset | Description |
| --- | --- | ---: | --- |
| `0x0000` | `GPU_ID` | `0x42504755` | ASCII-ish project ID. |
| `0x0004` | `GPU_VERSION` | `0x00010000` | Architecture/control-plane version. |
| `0x0008` | `STATUS` | `0x00000000` | Busy and sticky error status. |
| `0x000C` | `CONTROL` | `0x00000000` | Enable, reset, and control bits. |
| `0x0010` | `FRAMEBUFFER_BASE` | `0x00000000` | Global memory base of framebuffer. |
| `0x0014` | `FRAMEBUFFER_WIDTH` | `160` | Framebuffer width in pixels. |
| `0x0018` | `FRAMEBUFFER_HEIGHT` | `120` | Framebuffer height in pixels. |
| `0x001C` | `FRAMEBUFFER_FORMAT` | `1` | Framebuffer format enum. |
| `0x0020` | `FRAMEBUFFER_STRIDE` | `width * 2` | Optional future explicit stride. |
| `0x0024` | `INTERRUPT_STATUS` | `0x00000000` | Sticky interrupt status. |
| `0x0028` | `INTERRUPT_ENABLE` | `0x00000000` | Interrupt enable mask. |
| `0x002C` | `BUSY` | `0x00000000` | Busy readback. |

## Launch Registers

These registers configure the next programmable kernel launch. The scheduler
latches them when `LAUNCH_KERNEL` is accepted.

| Address | Name | Reset | Description |
| --- | --- | ---: | --- |
| `0x0040` | `PROGRAM_BASE` | `0x00000000` | Instruction memory base. |
| `0x0044` | `GRID_X` | `0x00000000` | Work-items in X. |
| `0x0048` | `GRID_Y` | `0x00000000` | Work-items in Y. |
| `0x004C` | `GROUP_SIZE_X` | `0x00000004` | Workgroup width. |
| `0x0050` | `GROUP_SIZE_Y` | `0x00000001` | Workgroup height. |
| `0x0054` | `ARG_BASE` | `0x00000000` | Kernel argument block base in global memory. |
| `0x0058` | `LAUNCH_FLAGS` | `0x00000000` | Reserved launch behavior flags. |

Initial hardware supports one core and four lanes. Default group size should
therefore be `4 x 1`.

## Debug and Future Registers

Reserved range:

```text
0x0080 - 0x00FF debug/performance counters
0x0100 - 0x01FF implementation-specific platform registers
```

Do not expose platform-only behavior through core registers unless the
programming model needs it.

## `CONTROL` Bits

| Bit | Name | Description |
| ---: | --- | --- |
| 0 | `ENABLE` | Enables command and kernel execution. |
| 1 | `SOFT_RESET` | One-cycle internal reset pulse when written as 1. |
| 2 | `CLEAR_ERRORS` | One-cycle clear of sticky errors when written as 1. |
| 3 | `INTERRUPT_ENABLE_GLOBAL` | Allows enabled interrupts to propagate. |
| 4 | `TEST_PATTERN_ENABLE` | Selects platform/core test pattern output if implemented. |
| 31:5 | reserved | Reads zero or stored zero; writes ignored. |

Pulse bits are not sticky. Readback should omit `SOFT_RESET` and
`CLEAR_ERRORS`.

## `STATUS` Bits

| Bit | Name | Description |
| ---: | --- | --- |
| 0 | `BUSY` | Command, scheduler, core, or memory work active. |
| 1 | `ERR_UNKNOWN_OPCODE` | Command or ISA opcode invalid. |
| 2 | `ERR_BAD_PACKET` | Command packet length or reserved fields invalid. |
| 3 | `ERR_LAUNCH_INVALID` | Launch registers invalid. |
| 4 | `ERR_LAUNCH_BUSY` | Launch attempted while work active. |
| 5 | `ERR_ILLEGAL_INSTRUCTION` | ISA instruction invalid. |
| 6 | `ERR_DIVERGENCE` | Branch diverged before mask support. |
| 7 | `ERR_MEMORY` | Alignment, range, or memory protocol error. |
| 8 | `ERR_COMPAT_ENGINE` | Fixed-function compatibility engine error. |
| 31:9 | reserved | Future errors/counters. |

Exact bit assignments may evolve before software depends on them, but the status
model must remain sticky and deterministic.

## Framebuffer Formats

| Value | Name | Description |
| ---: | --- | --- |
| 0 | `INVALID` | Not a valid rendering mode. |
| 1 | `RGB565` | 16-bit color, first supported format. |
| 2 | `INDEX8` | Future 8-bit palette-indexed mode. |

Only `RGB565` is required initially.

## Access Rules

- Reserved bits read as zero unless explicitly documented.
- Writes to reserved bits are ignored unless strict validation is enabled.
- Zero framebuffer width/height writes are ignored or rejected.
- Launch registers are latched on `LAUNCH_KERNEL`.
- Host writes during an active kernel do not mutate the active launch.
- `COMMAND_FIFO_WRITE`, if memory-mapped later, must apply backpressure or set
  overflow status.
