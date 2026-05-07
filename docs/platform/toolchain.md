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
make synth-yosys
make test-tools
make assemble-kernels
make check-kernel-fixtures
```

`make check-tools` should pass before writing RTL. `make lint`, `make formal`,
and `make sim` are allowed to report that no RTL or no formal jobs exist yet.
`make test-tools` runs host-side tooling tests, including the assembler tests.
`make assemble-kernels` regenerates checked-in kernel `.memh` fixtures from
`.kgpu` source. `make check-kernel-fixtures` verifies those committed images are
not stale.

`make synth-yosys` includes leaf RTL, the default integrated `gpu_core`, the
default `programmable_core`, and explicit `programmable_core` synthesis smoke at
`LANES=2` and `LANES=8`. The widened/narrowed lane variants are scale-readiness
checks only; they do not imply a supported product configuration until timing,
area, memory bandwidth, and software launch policy are validated.

Vivado is optional until FPGA-facing milestones. When Vivado is installed, run
the synthesis smoke with the exact board part:

```text
VIVADO_PART=<xilinx-part-name> make synth-vivado
```

For the RealDigital Urbana board, the checked target convenience commands use
the Spartan-7 part assumption `xc7s50csga324-1` and the generic FPGA video smoke
top:

```text
make synth-vivado-urbana-dry-run
make synth-vivado-urbana
```

`synth-vivado-urbana-dry-run` works on a VM without Vivado. It validates the
source manifest, Tcl path, top name, and Urbana part default. `synth-vivado-urbana`
requires `vivado` on `PATH`, usually after sourcing:

```text
source /tools/Xilinx/Vivado/<version>/settings64.sh
```

Without Vivado installed, use `VIVADO_DRY_RUN=1` with the same target to check
the Tcl script path and source list. `make test-tools` covers this dry-run path.

The default Vivado smoke top is the integrated `gpu_core`, using the same RTL
source closure as the open-source integrated synthesis smoke. Set `VIVADO_TOP`
when intentionally checking another top, such as the generic video/GPU scaffold:

```text
VIVADO_DRY_RUN=1 VIVADO_PART=<xilinx-part-name> VIVADO_TOP=gpu_video_fpga_top make synth-vivado
```

The target intentionally requires `VIVADO_PART` instead of guessing the board
part, so smoke checks do not create false platform claims.

## Installation Policy

- Install native VM tools through apt, source builds, Cargo, or pip.
- Do not use Docker for simulation, formal, FPGA, or ASIC flows.
- Prefer globally available executables under `/usr/bin` or `/usr/local/bin`.
- Keep generated build outputs out of Git.

## Ubuntu Package Notes

On Ubuntu, `netgen` is a 3D mesh-generation tool. The LVS tool is
`netgen-lvs`. Scripts should call `netgen-lvs` explicitly.

OpenSTA installs the executable as `sta`, not `opensta`.

## Assembler

The first host-side kernel tool is:

```text
tools/assembler/kgpu_asm.py
```

It emits one 32-bit hexadecimal instruction word per line for the implemented
ISA. See [assembler.md](assembler.md) for syntax and limitations. This is a
bring-up tool for simulation assets, not a C compiler or stable C ABI.
