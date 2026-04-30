# Timing Constraints

Timing constraints turn the RTL into a design that synthesis and STA tools can
analyze. They must be treated as design artifacts, not build-script leftovers.

## Initial Clock Model

Version 1 portable RTL has one clock:

```text
gpu_clk
```

Initial ASIC SDC skeleton:

```tcl
create_clock -name gpu_clk -period 10.000 [get_ports gpu_clk]
set_clock_uncertainty 0.100 [get_clocks gpu_clk]
```

The period is a placeholder until a target technology and performance goal are
selected.

## Constraint Types

| Constraint | Use |
| --- | --- |
| `create_clock` | Defines clock period and waveform. |
| `set_input_delay` | Models external input arrival time. |
| `set_output_delay` | Models downstream capture timing. |
| `set_clock_uncertainty` | Reserves margin for jitter and variation. |
| `set_false_path` | Excludes paths that cannot be active functionally. |
| `set_multicycle_path` | Allows paths to take multiple cycles when designed that way. |

## Constraint Discipline

False paths and multicycle paths are dangerous if used casually. Every exception
must be documented with:

- source path
- destination path
- functional reason
- verification evidence
- owner

## Multi-Clock Future

When future versions add `video_clk`, `memory_clk`, or `host_clk`, constraints
must identify:

- synchronous clocks
- asynchronous clocks
- generated clocks
- CDC synchronizer paths
- reset synchronizer paths

## Directory Plan

```text
asic/
  constraints/
    gpu_core.sdc
  reports/
  scripts/
```

## First Timing Milestone

The first timing milestone is not aggressive frequency. It is a clean single
clock design with:

- no unconstrained paths
- no unintended latches
- no combinational loops
- no unexplained false paths
- understandable critical paths
