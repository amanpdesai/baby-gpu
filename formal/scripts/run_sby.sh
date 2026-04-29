#!/usr/bin/env bash
set -euo pipefail

mapfile -t sby_files < <(find formal -type f -name '*.sby' | sort)

if [[ "${#sby_files[@]}" -eq 0 ]]; then
  echo "No SymbiYosys jobs found yet."
  exit 0
fi

for job in "${sby_files[@]}"; do
  echo "Running $job"
  sby -f "$job"
done
