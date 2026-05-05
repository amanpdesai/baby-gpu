# Regression and Debug Workflow

Regression debug should make failures cheap to isolate before the design grows
into multi-core, scratchpad, cache, video, and FPGA platform work.

## Simulation Selection

Run the full deterministic RTL simulation suite:

```bash
rtk make sim
```

List available simulation testbenches:

```bash
rtk make list-sim-tests
```

Run one testbench by module name:

```bash
SIM_TEST=tb_gpu_core_command_vector_add rtk make sim
```

Run a shell-glob-selected subset:

```bash
SIM_GLOB='*load_store*' rtk make sim
```

`SIM_TEST` and `SIM_GLOB` are mutually exclusive. Both filters match either the
testbench module name or its repository path.

## Artifact Location

Simulation build products default to:

```text
sim_build/
```

Use `SIM_OUT_DIR` to keep a debug run separate from the default build products:

```bash
SIM_TEST=tb_simd_alu SIM_OUT_DIR=sim_debug rtk make sim
```

Generated simulator artifacts are not source files and should not be committed.

## Waveform Traces

Use `SIM_TRACE=1` for an opt-in VCD trace on the selected tests:

```bash
SIM_TEST=tb_gpu_core_command_vector_add SIM_TRACE=1 rtk make sim
```

The runner creates a trace wrapper around the selected testbench and writes:

```text
sim_build/<testbench>.vcd
```

Prefer tracing a single testbench. Full-suite tracing is supported but creates
large files and slows the loop.

## Regression Gate

`make regress` is the local pre-push integration gate:

```bash
rtk make regress
```

It runs:

```text
check-kernel-fixtures
test-tools
sim
lint
formal
synth-yosys
```

Use the explicit commands when a failure needs isolation:

```bash
rtk test make check-kernel-fixtures
rtk test make test-tools
rtk test make sim
rtk make lint
rtk err make formal
rtk make synth-yosys
```

## Coverage Accounting

`tests/scenario_coverage.json` is the source of truth for regression scenario
accounting. `make test-tools` checks that:

- scenario IDs are unique
- each scenario references at least one simulation test
- referenced tests, kernels, and formal jobs exist
- each listed `.kgpu` fixture has a checked `.memh`
- testbench-used kernel fixtures are claimed by scenarios
- active top-level formal jobs are claimed or explicitly waived
- active simulation testbenches are claimed or explicitly waived

The intent is to prevent silent orphan tests and silent verification gaps.
