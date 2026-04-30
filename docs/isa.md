# Instruction Set Architecture

The UrbanaGPU ISA is a small fixed-width instruction set for a lockstep SIMD
core. The design is inspired by simple educational GPU projects, but the ISA is
owned by this project and should be shaped around the kernels and hardware we
intend to build.

The ISA should be defined as an envelope first, then implemented incrementally.
That means the field layout, register model, reserved opcode space, and illegal
instruction behavior are specified before every instruction exists in RTL.

## ISA Principles

- fixed-width instructions
- load/store architecture
- simple integer datapath first
- explicit `END` instruction
- per-lane general-purpose registers
- read-only special registers for IDs and launch state
- no implicit memory side effects except loads and stores
- reserved opcode space for growth

Initial instruction width:

```text
32 bits
```

Initial scalar data width:

```text
32-bit registers
32-bit global loads/stores
16-bit stores added for RGB565 framebuffer writes
```

## Register Model

Each lane has a private register file:

```text
R0..R15
```

Initial recommendation:

| Register | Use |
| --- | --- |
| `R0` | Hardwired zero or conventional zero source. |
| `R1..R11` | General purpose. |
| `R12` | Kernel argument base or scratch convention. |
| `R13` | Temporary address convention. |
| `R14` | Temporary data convention. |
| `R15` | Optional link/status convention, not a hardware stack. |

Whether `R0` is hardwired zero should be decided before RTL implementation of
the lane register file. Hardwiring zero simplifies programs and decode but
removes one general-purpose register.

Special registers are read through an instruction such as `MOVSR` or through
reserved register indices, depending on final encoding.

Required special values:

| Name | Meaning |
| --- | --- |
| `lane_id` | Hardware lane index within the SIMD group. |
| `global_id_x` | Work-item X coordinate. |
| `global_id_y` | Work-item Y coordinate. |
| `linear_global_id` | Flattened work-item index. |
| `group_id_x` | Workgroup X coordinate. |
| `group_id_y` | Workgroup Y coordinate. |
| `local_id_x` | Work-item X coordinate within workgroup. |
| `local_id_y` | Work-item Y coordinate within workgroup. |
| `arg_base` | Kernel argument block base address. |
| `framebuffer_base` | Framebuffer global memory base. |
| `framebuffer_width` | Framebuffer width in pixels. |
| `framebuffer_height` | Framebuffer height in pixels. |

## Instruction Envelope

The exact bit encoding can change before RTL decode lands, but the first-pass
format should fit these shapes:

```text
R-type: opcode rd ra rb flags
I-type: opcode rd ra imm
M-type: opcode rd/base address offset flags
B-type: opcode predicate offset flags
S-type: opcode special rd
```

Design constraints:

- opcode field must leave room for at least 32 instructions
- register fields must address at least 16 lane registers
- immediate fields must support small constants and branch offsets
- memory offsets must be signed or clearly documented as unsigned
- all unused fields must be reserved and checked in strict mode later

## Initial Instruction Set

The first implemented ISA should be small:

| Instruction | Purpose | Required for |
| --- | --- | --- |
| `NOP` | No operation. | pipeline bring-up |
| `END` | Mark lane/work-item complete. | every kernel |
| `MOVI` or `CONST` | Load immediate into register. | constants, addresses |
| `MOVSR` | Read special register. | global IDs |
| `ADD` | Integer addition. | address math, vector add |
| `MUL` | Integer multiply. | row stride, vector add variants |
| `CMP` | Compare two values and set predicate. | bounds checks |
| `BRA` | Convergent branch. | loops, if-like control |
| `LOAD` | 32-bit global load. | vector add |
| `STORE` | 32-bit global store. | vector add |
| `STORE16` | 16-bit global store. | RGB565 framebuffer |

This set can implement:

- vector add
- framebuffer gradient
- solid fill
- basic rectangle fill

## Later Instruction Candidates

Do not implement these until tests need them:

| Instruction | Reason to add |
| --- | --- |
| `SUB` | Address differences, loop counters. |
| `AND`, `OR`, `XOR` | bit packing, masks. |
| `SHL`, `SHR` | byte addressing and color packing. |
| `MAD` | common graphics and ML pattern. |
| `MIN`, `MAX` | clipping and bounds. |
| `LOAD16`, `LOAD8` | compact data formats. |
| `BARRIER` | scratchpad/shared memory coordination. |
| `ATOM` | later parallel reductions or synchronization. |

## Branching and Predication

Initial branch policy:

```text
all active lanes must agree on branch direction
```

If lanes disagree, hardware sets a divergence error and halts the kernel. This
is strict, but it is easy to verify.

The ISA should reserve bits for future per-lane predicates:

```text
active_mask
predicate register or condition field
reconvergence metadata
```

Those bits can be ignored or required zero initially.

## Memory Operations

Global memory operations use byte addresses.

Initial requirements:

- `LOAD` reads one 32-bit word
- `STORE` writes one 32-bit word
- `STORE16` writes one 16-bit halfword with byte mask
- misaligned 32-bit loads/stores are illegal initially
- out-of-range access behavior is implementation-defined initially, but tests
  should keep accesses in range

Framebuffer writes are just global stores. RGB565 pixels use `STORE16`.

## Illegal Instruction Handling

Illegal instruction behavior must be deterministic:

- set sticky illegal-instruction error bit
- stop issuing further instructions for the active kernel
- leave memory interface idle after outstanding accepted requests drain
- report failure through status registers

The design should never spin forever on an illegal instruction.

## Versioning Without Multiple Architectures

The project should not maintain separate "Version 1 fixed-function" and
"Version 2 programmable" architectures. Instead, the ISA has an extension path.

Base ISA:

```text
integer ALU
loads/stores
special registers
convergent branches
END
```

Extensions:

```text
halfword/byte memory
predication
scratchpad
atomics
SIMT masks
graphics helpers
```

Every new instruction must come with:

- encoding definition
- illegal/reserved field behavior
- at least one unit test
- at least one integration or kernel test
- documentation update

## Initial Encoding Decisions

These decisions are locked for the first decoder implementation. Later changes
must be treated as ISA changes, not incidental RTL edits.

### Register Zero

`R0` is hardwired zero.

Rules:

- reads from `R0` return `0`
- writes to `R0` are ignored
- `R1..R15` are writable per-lane registers

This costs one register but simplifies programs, decode, and tests.

### Common Header

All instructions are 32 bits.

```text
31        26 25     22 21     18 17     14 13                 0
+------------+---------+---------+---------+--------------------+
| opcode[5:0] | rd[3:0] | ra[3:0] | rb[3:0] | format-specific    |
+------------+---------+---------+---------+--------------------+
```

Opcode width is 6 bits, allowing 64 primary opcodes. Register fields address
the 16 architectural lane registers.

### R-Type

```text
31        26 25     22 21     18 17     14 13       8 7       0
+------------+---------+---------+---------+----------+---------+
| opcode     | rd      | ra      | rb      | reserved | flags   |
+------------+---------+---------+---------+----------+---------+
```

Used by:

```text
ADD
MUL
SUB later
AND/OR/XOR later
CMP later
```

Reserved bits must be zero initially.

### I-Type

```text
31        26 25     22 21     18 17                         0
+------------+---------+---------+----------------------------+
| opcode     | rd      | ra      | imm18                      |
+------------+---------+---------+----------------------------+
```

Used by:

```text
MOVI
ADDI later
address offset helpers later
```

Immediate interpretation is instruction-specific. `MOVI` zero-extends `imm18`
into the destination register for the first implementation. Sign extension can
be added with a separate instruction or flag later.

### S-Type

```text
31        26 25     22 21     16 15                         0
+------------+---------+---------+----------------------------+
| opcode     | rd      | sr[5:0] | reserved                   |
+------------+---------+---------+----------------------------+
```

Used by:

```text
MOVSR
```

Special registers are read with `MOVSR`; they are not mapped into the `R0..R15`
register namespace.

Initial special register IDs:

| ID | Name |
| ---: | --- |
| `0x00` | `lane_id` |
| `0x01` | `global_id_x` |
| `0x02` | `global_id_y` |
| `0x03` | `linear_global_id` |
| `0x04` | `group_id_x` |
| `0x05` | `group_id_y` |
| `0x06` | `local_id_x` |
| `0x07` | `local_id_y` |
| `0x08` | `arg_base` |
| `0x09` | `framebuffer_base` |
| `0x0A` | `framebuffer_width` |
| `0x0B` | `framebuffer_height` |

### M-Type

```text
31        26 25     22 21     18 17                         0
+------------+---------+---------+----------------------------+
| opcode     | rd/rs   | ra      | offset18                   |
+------------+---------+---------+----------------------------+
```

Used by:

```text
LOAD
STORE
STORE16
```

Address calculation:

```text
addr = R[ra] + zero_extend(offset18)
```

Initial memory offsets are unsigned. Signed offsets should be added explicitly
later if needed.

### B-Type

```text
31        26 25     22 21                         0
+------------+---------+----------------------------+
| opcode     | pred    | offset22                   |
+------------+---------+----------------------------+
```

Branch offsets are signed instruction-word offsets relative to the next PC:

```text
target_pc = pc + 1 + sign_extend(offset22)
```

Branches are convergent-only at first. If active lanes disagree, hardware sets
the divergence error and halts the kernel.

## Initial Opcode Map

| Opcode | Mnemonic | Format | Implement now |
| ---: | --- | --- | --- |
| `0x00` | `NOP` | R | yes |
| `0x01` | `END` | R | yes |
| `0x02` | `MOVI` | I | yes |
| `0x03` | `MOVSR` | S | yes |
| `0x04` | `ADD` | R | yes |
| `0x05` | `MUL` | R | yes |
| `0x06` | `LOAD` | M | next |
| `0x07` | `STORE` | M | next |
| `0x08` | `STORE16` | M | after `STORE` |
| `0x09` | `CMP` | R | later |
| `0x0A` | `BRA` | B | later |
| `0x0B` | `SUB` | R | later |
| `0x0C` | `AND` | R | later |
| `0x0D` | `OR` | R | later |
| `0x0E` | `XOR` | R | later |
| `0x0F` | `SHL` | R | later |
| `0x10` | `SHR` | R | later |

All unlisted opcodes are illegal.

## Remaining ISA Decisions

Still open before branch and memory RTL:

- exact predicate representation for `CMP` and `BRA`
- whether to add signed immediates as flags or separate opcodes
- whether to add `ADDI` before `LOAD`/`STORE`
- whether `STORE16` should trap on odd addresses or support both halfword lanes
- exact illegal-instruction status bit mapping in the programmable core
