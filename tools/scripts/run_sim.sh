#!/usr/bin/env bash
set -euo pipefail

mapfile -t tb_files < <(find tb -type f -name 'tb_*.sv' | sort)

if [[ "${#tb_files[@]}" -eq 0 ]]; then
  echo "No simulation testbenches found yet."
  exit 0
fi

echo "Simulation runner exists; add concrete test targets as RTL lands."
printf "Found testbenches:\n"
printf "  %s\n" "${tb_files[@]}"
