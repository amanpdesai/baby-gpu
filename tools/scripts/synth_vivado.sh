#!/usr/bin/env bash
set -euo pipefail

if ! command -v vivado >/dev/null 2>&1; then
  echo "Vivado is not installed or not on PATH."
  echo "Install AMD/Xilinx Vivado and rerun with VIVADO_PART set for the FPGA target."
  exit 127
fi

if [[ -z "${VIVADO_PART:-}" ]]; then
  echo "VIVADO_PART is required for Vivado synthesis smoke."
  echo "Example: VIVADO_PART=<xilinx-part-name> make synth-vivado"
  exit 2
fi

top="${VIVADO_TOP:-gpu_core}"
out_dir="${VIVADO_OUT_DIR:-synth_build/vivado}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
tcl_script="${repo_root}/tools/vivado/synth_smoke.tcl"

sources=(
  "${repo_root}/rtl/common/gpu_pkg.sv"
  "${repo_root}/rtl/common/isa_pkg.sv"
  "${repo_root}/platform/sim/instruction_memory.sv"
  "${repo_root}/rtl/core/command_fifo.sv"
  "${repo_root}/rtl/core/command_processor.sv"
  "${repo_root}/rtl/core/framebuffer_writer.sv"
  "${repo_root}/rtl/core/gpu_core.sv"
  "${repo_root}/rtl/core/instruction_decoder.sv"
  "${repo_root}/rtl/core/lane_register_file.sv"
  "${repo_root}/rtl/core/load_store_unit.sv"
  "${repo_root}/rtl/core/programmable_core.sv"
  "${repo_root}/rtl/core/register_file.sv"
  "${repo_root}/rtl/core/simd_alu.sv"
  "${repo_root}/rtl/core/simd_core.sv"
  "${repo_root}/rtl/core/special_registers.sv"
  "${repo_root}/rtl/core/work_scheduler.sv"
  "${repo_root}/rtl/draw_units/clear_engine.sv"
  "${repo_root}/rtl/draw_units/rect_fill_engine.sv"
)

mkdir -p "${repo_root}/${out_dir}"

echo "VIVADO SYNTH ${top}"
vivado -mode batch -nojournal -nolog \
  -source "${tcl_script}" \
  -tclargs "${top}" "${VIVADO_PART}" "${repo_root}/${out_dir}" "${sources[@]}"

echo "Vivado synthesis smoke passed for ${top} (${VIVADO_PART})."
