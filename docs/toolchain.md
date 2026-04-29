# Native Toolchain

The development VM uses native tools installed directly into the OS. Docker is
not part of this project flow.

## Installed Baseline

| Area | Tool | Expected Command |
| --- | --- | --- |
| RTL simulation and lint | Verilator | `verilator` |
| Simple Verilog simulation | Icarus Verilog | `iverilog`, `vvp` |
| Synthesis and formal frontend | Yosys | `yosys` |
| Formal runner | SymbiYosys | `sby` |
| SMT solver | Boolector | `boolector` |
| SMT solver | Z3 | `z3` |
| Waveform viewer | GTKWave | `gtkwave` |
| SystemVerilog lint | svlint | `svlint` |
| Build orchestration | FuseSoC | `fusesoc` |
| Build backend library | Edalize | Python package `edalize` |
| Python tests | pytest | `pytest` |
| Image tests | Pillow and NumPy | Python packages `PIL`, `numpy` |
| Layout editing and DRC experiments | Magic | `magic` |
| Layout viewing and DRC experiments | KLayout | `klayout` |
| LVS | Netgen LVS | `netgen-lvs` |
| Static timing analysis | OpenSTA | `sta` |

## Not Installed Yet

| Tool | Why Not Installed Yet |
| --- | --- |
| Vivado | Requires AMD/Xilinx installer, account/license workflow, and large install. Needed for Urbana bitstreams. |
| OpenROAD | Not available from Ubuntu 24.04 apt repositories. Build from source or install native binaries when physical design starts. |
| Yices | Not packaged in the default Ubuntu repo. Boolector and Z3 are enough for the initial formal lane. |
| Verible | Not packaged in the default Ubuntu repo. `svlint` and Verilator cover the initial lint path. |

## Project Commands

```text
make check-tools
make tool-versions
make lint
make formal
make sim
```

`make check-tools` should pass before writing RTL. `make lint`, `make formal`,
and `make sim` are allowed to report that no RTL or no formal jobs exist yet.

## Installation Policy

- Install native VM tools through apt, source builds, Cargo, or pip.
- Do not use Docker for simulation, formal, FPGA, or ASIC flows.
- Prefer globally available executables under `/usr/bin` or `/usr/local/bin`.
- Keep generated build outputs out of Git.

## Ubuntu Package Notes

On Ubuntu, `netgen` is a 3D mesh-generation tool. The LVS tool is
`netgen-lvs`. Scripts should call `netgen-lvs` explicitly.

OpenSTA installs the executable as `sta`, not `opensta`.
