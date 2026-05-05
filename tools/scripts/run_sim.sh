#!/usr/bin/env bash
set -euo pipefail

sim_out_dir="${SIM_OUT_DIR:-sim_build}"
sim_test="${SIM_TEST:-}"
sim_glob="${SIM_GLOB:-}"
sim_trace="${SIM_TRACE:-0}"
sim_list="${SIM_LIST:-0}"

if [[ -n "$sim_test" && -n "$sim_glob" ]]; then
  echo "SIM_TEST and SIM_GLOB are mutually exclusive" >&2
  exit 2
fi

mapfile -t tb_files < <(
  find tb -type f -name 'tb_*.sv' |
    while IFS= read -r tb_file; do
      printf '%s\t%s\n' "$(basename "$tb_file" .sv)" "$tb_file"
    done |
    sort |
    cut -f2-
)
mapfile -t tb_common_files < <(find tb/common -type f -name '*.sv' | sort)
mapfile -t rtl_files < <(find rtl platform/sim -type f -name '*.sv' | sort)

if [[ "${#tb_files[@]}" -eq 0 ]]; then
  echo "No simulation testbenches found yet."
  exit 0
fi

selected_tb_files=()
for tb_file in "${tb_files[@]}"; do
  tb_name="$(basename "$tb_file" .sv)"

  if [[ -n "$sim_test" && "$tb_name" != "$sim_test" && "$tb_file" != "$sim_test" ]]; then
    continue
  fi

  if [[ -n "$sim_glob" && "$tb_name" != $sim_glob && "$tb_file" != $sim_glob ]]; then
    continue
  fi

  selected_tb_files+=("$tb_file")
done

if [[ "${#selected_tb_files[@]}" -eq 0 ]]; then
  echo "No simulation testbenches matched the requested selection." >&2
  exit 2
fi

if [[ "$sim_list" == "1" ]]; then
  for tb_file in "${selected_tb_files[@]}"; do
    basename "$tb_file" .sv
  done
  exit 0
fi

mkdir -p "$sim_out_dir"

for tb_file in "${selected_tb_files[@]}"; do
  tb_name="$(basename "$tb_file" .sv)"
  out_file="${sim_out_dir}/${tb_name}.vvp"
  echo "SIM ${tb_name}"

  if [[ "$sim_trace" == "1" ]]; then
    trace_wrapper="${sim_out_dir}/${tb_name}_trace_wrapper.sv"
    trace_file="${sim_out_dir}/${tb_name}.vcd"
    cat >"$trace_wrapper" <<SV
module sim_trace_top;
  ${tb_name} dut();

  initial begin
    if (\$test\$plusargs("trace")) begin
      \$dumpfile("${trace_file}");
      \$dumpvars(0, sim_trace_top);
    end
  end
endmodule
SV
    iverilog -g2012 -Wall -s sim_trace_top -o "$out_file" "${rtl_files[@]}" "${tb_common_files[@]}" "$tb_file" "$trace_wrapper"
    vvp "$out_file" +trace
  else
    iverilog -g2012 -Wall -o "$out_file" "${rtl_files[@]}" "${tb_common_files[@]}" "$tb_file"
    vvp "$out_file"
  fi
done
