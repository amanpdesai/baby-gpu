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

## Response Identity Contract

This contract is required before adding scratchpads, caches, DMA engines, or
multiple programmable cores.

- A request source owns only its local request ID field. It must not depend on
  another source's local ID encoding.
- The arbiter owns only the source ID field. It prepends the selected source ID
  to the local request ID and must not rewrite the local ID bits.
- A memory wrapper that supports IDs must return the accepted request ID on the
  corresponding response. If the wrapper is strictly in order, a bounded
  response tracker may regenerate the oldest outstanding ID.
- The response path is selected only by `rsp_id.source_id`. The local ID bits are
  delivered unchanged to the selected client.
- Invalid response source IDs must be drained without asserting any client
  response, client error, or backpressured sink path.
- Backpressure is source-local on the response path. A valid response for one
  source may be held by that source's `rsp_ready` without pretending another
  client accepted it.
- Reset or command-level soft reset may invalidate client-side work, but the
  external memory interface must still be able to drain stale responses without
  corrupting the next command or kernel launch.

Initial limits:

```text
gpu_core sources: framebuffer writer, programmable LSU
gpu_core source ID width: 1 bit
gpu_core local response ID width: 1 bit
memory response ordering: external responses may arrive by ID; in-order
                          wrappers may use a response tracker
LSU outstanding depth: blocking, one lane request at a time
```

Scaling requirements before multi-core:

- Define a global source map that distinguishes core-local LSU traffic, video
  scanout, host DMA, cache refills, and future copy engines.
- Decide whether `core_id` is part of the arbiter source field or a separate
  field preserved across a higher-level memory fabric.
- Size `local_request_id` for the deepest outstanding queue behind each source,
  including future nonblocking LSU, cache miss, and prefetch queues.
- Add integration tests where older responses for one source remain pending
  while a younger response for another source completes.
- Add formal properties proving response routing, invalid-source containment,
  selected-source backpressure, and ID FIFO ordering at every new fabric
  boundary.

The first arbiter is intentionally a small valid/ready mux with response
routing. It does not reorder, allocate IDs, track completion, or implement
fairness. Those are later memory-system blocks. Priority arbitration is
acceptable while all requesters are blocking or low-throughput. The
round-robin arbiter leaf is available for scale-up and preserves the same
`source_id || local_request_id` response-routing contract. Use it before adding
multiple peer cores, high-rate DMA, or cache refills unless a written priority
policy intentionally favors one client.

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
- top-level `gpu_core` response-ID routing when a programmable LSU response
  returns before older fixed-function writer responses
- vector add memory result
- framebuffer gradient golden image
- out-of-bounds or illegal access behavior once specified

No memory feature is complete until it has both unit and integration tests.
