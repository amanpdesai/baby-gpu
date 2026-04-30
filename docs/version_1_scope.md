# Initial Scope

This document is retained for historical continuity, but the project should not
be interpreted as separate fixed-function and programmable versions. The active
architecture is the unified programmable GPU described in
[architecture.md](architecture.md).

## Initial Hardware Scope

The initial scope is:

- command FIFO
- register file
- command processor
- fixed-function smoke engines for clear and rectangle fill
- programmable kernel launch registers
- one programmable SIMD core
- four lanes
- blocking global memory load/store path
- simulation RAM
- framebuffer region in global memory
- video scanout after memory correctness is proven

## Required First Kernels

```text
vector_add
framebuffer_gradient
solid_fill or bounded fill
```

The project is not complete at "clear a framebuffer with a fixed engine." That
is only a bring-up checkpoint.

## Out of Initial Scope

- caches
- multiple cores
- full divergent branch reconvergence
- floating point
- atomics
- DDR3 framebuffer
- texture filtering
- programmable shaders in the commercial GPU sense
- compiler optimization
- full ASIC signoff

These are not rejected. They are staged after the base programmable core works.

## Initial Exit Criteria

The first architecture milestone is done when:

- `vector_add` passes RTL simulation
- `framebuffer_gradient` passes RTL simulation
- at least one graphics-style bounded write kernel passes or is explicitly
  deferred pending predication
- global memory and framebuffer writes use the same memory path
- the fixed-function engines are not required for programmable kernel tests
- lint passes
- relevant unit tests pass
- documentation matches the implemented programming model
