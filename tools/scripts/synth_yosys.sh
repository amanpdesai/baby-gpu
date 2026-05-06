#!/usr/bin/env bash
set -euo pipefail

timeout_s="${YOSYS_TIMEOUT_S:-60}"
out_dir="synth_build/yosys"

mkdir -p "$out_dir"

run_synth() {
  local top="$1"
  shift

  local log_file="${out_dir}/${top}.log"
  local sources=("$@")
  local read_args=()

  for source in "${sources[@]}"; do
    read_args+=("$source")
  done

  echo "SYNTH ${top}"
  if ! timeout "${timeout_s}s" yosys -p "
    read_verilog -sv ${read_args[*]}
    hierarchy -top ${top}
    synth -run coarse
    check -assert
    stat
  " >"$log_file" 2>&1; then
    echo "Yosys synthesis failed for ${top}. See ${log_file}."
    tail -n 80 "$log_file" || true
    exit 1
  fi

  if grep -q "Warning:" "$log_file"; then
    echo "Yosys emitted warnings for ${top}. See ${log_file}."
    grep "Warning:" "$log_file" || true
    exit 1
  fi
}

run_synth command_fifo \
  rtl/core/command_fifo.sv

run_synth command_processor \
  rtl/core/command_processor.sv

run_synth framebuffer_writer \
  rtl/core/framebuffer_writer.sv

run_synth framebuffer_scanout \
  rtl/core/framebuffer_scanout.sv

run_synth video_timing \
  rtl/core/video_timing.sv

run_synth video_test_pattern \
  rtl/core/video_test_pattern.sv

run_synth video_stream_mux \
  rtl/core/video_stream_mux.sv

run_synth video_framebuffer_source \
  rtl/core/video_framebuffer_source.sv

run_synth instruction_decoder \
  rtl/common/isa_pkg.sv \
  rtl/core/instruction_decoder.sv

run_synth gpu_core \
  rtl/common/gpu_pkg.sv \
  rtl/common/isa_pkg.sv \
  platform/sim/instruction_memory.sv \
  rtl/core/command_fifo.sv \
  rtl/core/command_processor.sv \
  rtl/core/framebuffer_scanout.sv \
  rtl/core/framebuffer_writer.sv \
  rtl/core/gpu_core.sv \
  rtl/core/instruction_decoder.sv \
  rtl/core/lane_register_file.sv \
  rtl/core/load_store_unit.sv \
  rtl/core/memory_arbiter.sv \
  rtl/core/memory_arbiter_rr.sv \
  rtl/core/memory_response_tracker.sv \
  rtl/core/programmable_core.sv \
  rtl/core/register_file.sv \
  rtl/core/simd_alu.sv \
  rtl/core/simd_core.sv \
  rtl/core/special_registers.sv \
  rtl/core/video_timing.sv \
  rtl/core/work_scheduler.sv \
  rtl/draw_units/clear_engine.sv \
  rtl/draw_units/rect_fill_engine.sv

run_synth lane_register_file \
  rtl/core/lane_register_file.sv

run_synth load_store_unit \
  rtl/core/load_store_unit.sv

run_synth memory_arbiter \
  rtl/core/memory_arbiter.sv

run_synth memory_arbiter_rr \
  rtl/core/memory_arbiter_rr.sv

run_synth memory_response_tracker \
  rtl/core/memory_response_tracker.sv

run_synth programmable_core \
  rtl/common/isa_pkg.sv \
  rtl/core/work_scheduler.sv \
  rtl/core/instruction_decoder.sv \
  rtl/core/special_registers.sv \
  rtl/core/lane_register_file.sv \
  rtl/core/simd_alu.sv \
  rtl/core/load_store_unit.sv \
  rtl/core/simd_core.sv \
  rtl/core/programmable_core.sv

run_synth register_file \
  rtl/core/register_file.sv

run_synth simd_alu \
  rtl/core/simd_alu.sv

run_synth simd_core \
  rtl/common/isa_pkg.sv \
  rtl/core/instruction_decoder.sv \
  rtl/core/special_registers.sv \
  rtl/core/lane_register_file.sv \
  rtl/core/simd_alu.sv \
  rtl/core/load_store_unit.sv \
  rtl/core/simd_core.sv

run_synth special_registers \
  rtl/common/isa_pkg.sv \
  rtl/core/special_registers.sv

run_synth work_scheduler \
  rtl/core/work_scheduler.sv

run_synth clear_engine \
  rtl/draw_units/clear_engine.sv

run_synth rect_fill_engine \
  rtl/draw_units/rect_fill_engine.sv

echo "Yosys synthesis smoke passed."
