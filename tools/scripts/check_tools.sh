#!/usr/bin/env bash
set -euo pipefail

required_cmds=(
  verilator
  iverilog
  vvp
  yosys
  sby
  boolector
  z3
  gtkwave
  svlint
  fusesoc
  cocotb-config
  magic
  klayout
  netgen-lvs
  sta
)

optional_cmds=(
  vivado
  openroad
  yices-smt2
  verible-verilog-format
  verible-verilog-lint
)

missing=0

echo "Required native tools"
for cmd in "${required_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ok      %s -> %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "  missing %s\n" "$cmd"
    missing=1
  fi
done

echo
echo "Optional later-stage tools"
for cmd in "${optional_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ok      %s -> %s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "  later   %s\n" "$cmd"
  fi
done

echo
python3 - <<'PY'
from importlib.metadata import version

packages = [
    "edalize",
    "cocotb",
    "fusesoc",
    "numpy",
    "pillow",
    "pytest",
]

print("Required Python packages")
missing = False
for package in packages:
    try:
        print(f"  ok      {package} {version(package)}")
    except Exception:
        print(f"  missing {package}")
        missing = True

raise SystemExit(1 if missing else 0)
PY

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "One or more required native tools are missing."
  exit 1
fi

echo
echo "Native toolchain check passed."
