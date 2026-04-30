#!/usr/bin/env bash
set -euo pipefail

mapfile -t rtl_files < <(find rtl platform/sim platform/asic -type f -name '*.sv' | sort)

if [[ "${#rtl_files[@]}" -eq 0 ]]; then
  echo "No SystemVerilog files found yet."
  exit 0
fi

verilator --lint-only --sv --Wno-MULTITOP "${rtl_files[@]}"
svlint "${rtl_files[@]}"
