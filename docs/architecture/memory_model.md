# Memory Model

The memory model must support compute kernels and framebuffer kernels without
splitting the design into separate architectures. The framebuffer is a global
memory allocation. A pixel write is a store.

Initial memory hierarchy:

```text
lane registers
  -> global memory interface
    -> simulation RAM / BRAM / external memory wrapper
```

Later hierarchy:

```text
lane registers
  -> per-core scratchpad
  -> per-core load/store queues
  -> optional caches
  -> global memory
```

## Address Space

Use byte addresses for all global memory operations.

Initial address width:

```text
32 bits
```

Address regions are a software convention at first:

| Region | Purpose |
| --- | --- |
| instruction memory | Kernel program storage. |
| global data | Kernel buffers and arguments. |
| framebuffer | RGB565 image read by video scanout. |
| MMIO registers | Host-visible control and status. |

Instruction memory and data memory should be physically separate in the first
RTL implementation. That avoids instruction fetch and data load arbitration
before kernels work. A unified memory system can come later.

## Data Types

Initial global memory operations:

| Operation | Size | Alignment | Purpose |
| --- | ---: | --- | --- |
| `LOAD` | 32 bits | 4-byte aligned | compute buffers, arguments |
| `STORE` | 32 bits | 4-byte aligned | compute results |
| `STORE16` | 16 bits | 2-byte aligned | RGB565 framebuffer pixels |

Misaligned 32-bit accesses are illegal initially. `STORE16` uses byte masks on
the memory bus.

## Framebuffer Convention

Framebuffer format:

```text
RGB565
```

Address calculation:

```text
pixel_addr = framebuffer_base + (y * framebuffer_stride_bytes) + (x * 2)
```

Initial stride:

```text
framebuffer_stride_bytes = framebuffer_width * 2
```

Future versions can add explicit stride registers for alignment, double
buffering, or scanout requirements.

The programmable kernel should compute this address using special registers and
integer instructions. Fixed-function helpers may use the same convention, but
the convention belongs to the memory model, not the helper.

## Global Memory Interface

The global memory interface should use valid/ready. Minimum fields:

```text
req_valid
req_ready
req_write
req_addr
req_wdata
req_wmask
rsp_valid
rsp_ready
rsp_rdata
```

Scalable fields are now part of the memory-system direction, even when an early
leaf block or platform memory ignores them:

```text
req_core_id
req_lane_id
req_id
rsp_core_id
rsp_lane_id
rsp_id
```

Initial identity rule:

```text
memory_request_id = source_id || local_request_id
```

`source_id` identifies the request origin at the arbiter boundary. For the
current single-core design, sources are expected to be things like
programmable-core LSU traffic, fixed-function framebuffer-writer traffic, and
future scanout or host DMA traffic. `local_request_id` is opaque to the arbiter
and is returned unchanged on the response path.

Response routing rule:

```text
rsp_id.source_id selects the response sink
rsp_id.local_request_id is returned to that sink unchanged
```

`gpu_core` exposes `mem_req_id` and `mem_rsp_id` at its top-level memory port.
Memory wrappers that can return IDs should copy the accepted request ID into the
matching response. In-order memories may still use the response tracker as
outstanding-capacity accounting, but response routing uses the external
`mem_rsp_id`.

The first arbiter is intentionally a small valid/ready mux with response
routing. It does not reorder, allocate IDs, track completion, or implement
fairness. Those are later memory-system blocks. Priority arbitration is
acceptable while all requesters are blocking or low-throughput. Round-robin or
weighted arbitration should be added before attaching high-rate scanout, DMA, or
multiple cores.

Multiple cores require response routing before they are added.

## Per-Core Scratchpad

A scratchpad is not a cache. It is explicitly addressed SRAM shared by lanes in
one core or workgroup.

Do not implement scratchpad in the first programmable milestone. Reserve the
concept because it is useful for:

- matrix multiply tiles
- shared image tiles
- reductions
- staging data from global memory

When added, scratchpad should have:

- deterministic latency
- explicit load/store instructions or address space bits
- no coherence with global memory except through explicit program behavior

## Caches

Do not start with caches.

Caches require:

- tags
- valid/dirty state
- refill logic
- eviction policy
- miss handling
- memory ordering decisions
- verification of stalls and replay

Recommended cache sequence:

1. no cache, blocking LSU
2. read-only constant cache or instruction cache
3. simple direct-mapped data cache
4. cache with multiple cores only after coherence policy is defined

For a small FPGA GPU, explicit scratchpad may be more useful than a data cache.

## Memory Ordering

Initial memory ordering is conservative:

- one outstanding memory request per core
- program order is preserved
- loads stall until response
- stores stall until accepted
- each accepted request returns exactly one response
- responses carry identity and are routed by ID
- software-visible ordering across different sources is not guaranteed unless a
  command-level barrier or future fence defines it
- no atomics
- no memory fences

This makes the first execution core easier to reason about.

Later features that affect ordering:

- multiple outstanding loads
- store buffers
- caches
- atomics
- barriers
- multiple cores

Do not add these without a written ordering rule and tests.

## Video Scanout Interaction

Video scanout reads framebuffer memory while kernels may write it.

Initial policy:

- simulation tests can avoid simultaneous scanout and writes
- FPGA bring-up can accept tearing
- scanout should have read priority once display output matters

Later policy:

- double buffering
- line buffers
- scanout read arbitration
- optional vblank synchronization

This is separate from kernel correctness. Kernel tests should compare memory
contents directly before relying on live display behavior.

## Memory Tests

Required tests:

- aligned 32-bit load/store
- RGB565 `STORE16` low and high halfword byte masks
- framebuffer address calculation
- LSU request stability under backpressure
- arbiter priority and response-ID routing
- vector add memory result
- framebuffer gradient golden image
- out-of-bounds or illegal access behavior once specified

No memory feature is complete until it has both unit and integration tests.
