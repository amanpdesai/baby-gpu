#!/usr/bin/env bash
set -euo pipefail

mapfile -t tb_files < <(find tb -type f -name 'tb_*.sv' | sort)
mapfile -t tb_common_files < <(find tb/common -type f -name '*.sv' | sort)
mapfile -t rtl_files < <(find rtl platform/sim -type f -name '*.sv' | sort)

if [[ "${#tb_files[@]}" -eq 0 ]]; then
  echo "No simulation testbenches found yet."
  exit 0
fi

mkdir -p sim_build

for tb_file in "${tb_files[@]}"; do
  tb_name="$(basename "$tb_file" .sv)"
  out_file="sim_build/${tb_name}.vvp"
  echo "SIM ${tb_name}"
  iverilog -g2012 -Wall -o "$out_file" "${rtl_files[@]}" "${tb_common_files[@]}" "$tb_file"
  vvp "$out_file"
done
