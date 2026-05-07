# RealDigital Urbana Platform

This directory is for RealDigital Urbana board-specific integration. Generic
FPGA-facing wrappers stay in `platform/fpga/`; Urbana files here own board
clocking, reset, constraints, and later board IO.

## Board Target

Current target assumption:

```text
part: xc7s50csga324-1
family: Spartan-7
clock: 100 MHz board oscillator on CLK_100MHZ
```

The part and clock name come from the RealDigital Urbana board documentation and
constraints. Verify the installed board revision before committing a final XDC
or claiming hardware bring-up.

## VM Bring-Up Commands

The VM can validate the Vivado source manifest without Vivado installed:

```text
make synth-vivado-urbana-dry-run
```

After Vivado is installed and its environment is sourced:

```text
source /tools/Xilinx/Vivado/<version>/settings64.sh
make synth-vivado-urbana
```

`synth-vivado-urbana` currently targets `gpu_video_fpga_top`, which is a generic
FPGA-facing smoke scaffold. It is not an Urbana board top and does not use board
constraints yet.

Override defaults when needed:

```text
URBANA_PART=<part> URBANA_TOP=<top> make synth-vivado-urbana-dry-run
URBANA_PART=<part> URBANA_TOP=<top> make synth-vivado-urbana
```

## First Real Hardware Milestones

1. Add minimal Urbana `urbana_top.sv` with clock, reset, and LED heartbeat.
2. Add a reviewed Urbana XDC for the board revision.
3. Run Vivado synthesis, implementation, timing, and bitstream generation.
4. Program the board over USB-JTAG from the host with physical board access.
5. Record observations in the bring-up log before claiming FPGA validation.

Do not connect the GPU memory path to DDR3 before a BRAM-backed smoke design is
stable on the board.
