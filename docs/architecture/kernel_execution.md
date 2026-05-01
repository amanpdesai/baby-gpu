# Kernel Execution

Kernel execution connects the host command stream to the programmable core. This
document defines the first execution flow and the decisions that must be made
before writing the scheduler and instruction pipeline RTL.

## Execution Flow

```text
host writes launch registers
host sends LAUNCH_KERNEL
command processor validates launch
scheduler assigns work-items to lanes
core fetches and executes instructions
load/store unit accesses global memory
kernel reaches END for all work-items
status reports idle or error
```

The command processor should not know how to shade a pixel or add vectors. It
only validates and launches work.

## Launch Registers

Launch state should live in the register file.

Required launch registers:

| Register | Meaning |
| --- | --- |
| `PROGRAM_BASE` | Instruction memory base address. |
| `GRID_X` | Work-items in X dimension. |
| `GRID_Y` | Work-items in Y dimension. |
| `GROUP_SIZE_X` | Workgroup width. |
| `GROUP_SIZE_Y` | Workgroup height. |
| `ARG_BASE` | Kernel argument block address in global memory. |
| `LAUNCH_FLAGS` | Reserved for masks, barriers, and debug behavior. |

`LAUNCH_KERNEL` consumes these registers. The scheduler latches them at launch
time so host writes during execution do not mutate an active kernel.

## Scheduler Algorithm

Initial scheduler:

```text
linear_id = 0
while linear_id < grid_x * grid_y:
  assign up to LANES work-items
  run SIMD group until all assigned lanes END
  linear_id += LANES
```

For each assigned lane:

```text
global_id_x = linear_id % grid_x
global_id_y = linear_id / grid_x
lane_id = hardware lane index
```

Tail handling:

```text
if fewer than LANES work-items remain:
  mark unused lanes inactive for this group
```

Initial scheduler does not need workgroups for execution, but launch registers
should include them so the programming model does not change later.

## Program Counter Rules

Each core has one shared PC.

Initial PC behavior:

- start at `program_base`
- increment by one instruction after normal instruction execution
- `BRA` updates PC only when all active lanes agree on the branch direction
- divergent `BRA` decisions set a core error and halt the current SIMD group
- `END` marks lanes done
- when all active lanes are done, scheduler loads the next SIMD group

Instruction memory addressing should be in instruction words internally. Host
registers may use byte addresses if that is more consistent with the rest of
the system. The conversion must be explicit.

## Lane Completion

Each lane has a done bit.

Rules:

- `END` sets done for active lanes
- done lanes do not write registers
- done lanes do not issue memory requests
- group completes when all assigned lanes are done
- unused tail lanes start inactive and done

If one lane reaches `END` earlier than another, the remaining lanes continue
only if the instruction stream is still convergent. This is another reason to
keep early kernels simple.

## Error Handling

Kernel execution errors:

| Error | Cause |
| --- | --- |
| illegal instruction | opcode or reserved fields invalid |
| divergent branch | active lanes disagree on branch direction |
| invalid memory alignment | load/store violates alignment rule |
| instruction fetch fault | PC outside loaded program range |
| launch while busy | host attempts concurrent launch |
| invalid launch | zero grid, unsupported group size, bad program base |

Error behavior:

- set sticky status bit
- stop issuing new instructions
- drain or suppress outstanding memory as defined by LSU state
- return core to idle/error state
- require host clear/reset before next launch

No error should leave the simulator hanging.

## First Kernels in Detail

### `vector_add`

Inputs:

```text
arg0 = base address A
arg1 = base address B
arg2 = base address C
arg3 = element count
```

For each work-item:

```text
i = linear_global_id
if i < element_count:
  C[i] = A[i] + B[i]
```

Hardware proven:

- special register reads
- argument loads
- address arithmetic
- 32-bit loads
- ALU add
- 32-bit stores
- tail lane masking

### `framebuffer_gradient`

Inputs:

```text
framebuffer_base
framebuffer_width
framebuffer_height
```

For each work-item:

```text
x = global_id_x
y = global_id_y
color = pack_rgb565(x, y, constant)
store16(framebuffer_base + (y * width + x) * 2, color)
```

Hardware proven:

- 2D IDs
- multiply/add address math
- halfword stores
- framebuffer golden comparison

### `fill_rect`

Inputs:

```text
rect_x
rect_y
rect_w
rect_h
color
```

For each framebuffer pixel:

```text
if x in rect and y in rect:
  store color
```

The initial branch rule cannot express this directly because different lanes may
disagree on the rectangle predicate. The near-term path is no-branch predicated
stores:

```text
inside = x >= rect_x && x < rect_x + rect_w &&
         y >= rect_y && y < rect_y + rect_h
PSTORE16 framebuffer_addr, color, inside
```

`PSTORE` and `PSTORE16` let false lanes skip the store without changing the
shared PC or requiring a divergence stack. Full divergent branch masks remain a
later scaling feature.

## Simulation Strategy

Every kernel test should have:

- encoded instruction memory
- command stream
- initialized global memory
- expected final memory
- timeout
- error-status check

For framebuffer kernels, tests should compare memory first. Image generation can
come after memory comparison is stable.

## Implementation Milestones

Build in this order:

1. instruction encoding document finalized
2. lane register file
3. SIMD ALU
4. special register read path
5. instruction fetch ROM/RAM model
6. decode and PC update
7. `END`, `MOVI`, `MOVSR`, `ADD`
8. scheduler for 1 core x 4 lanes
9. blocking LSU with `LOAD` and `STORE`
10. `vector_add` kernel test
11. `STORE16`
12. `framebuffer_gradient` kernel test
13. `CMP` plus branch behavior
14. `PSTORE` / `PSTORE16`
15. rectangle or bounded graphics kernel

This order gives a working programmable machine before adding complex graphics
or branch behavior.
