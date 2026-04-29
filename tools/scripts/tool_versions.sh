#!/usr/bin/env bash
set -euo pipefail

run_version() {
  local name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1; then
    printf "\n== %s ==\n" "$name"
    "$@" || true
  else
    printf "\n== %s ==\nmissing\n" "$name"
  fi
}

run_version verilator verilator --version
run_version iverilog iverilog -V
run_version yosys yosys -V
run_version sby sby --version
run_version boolector boolector --version
run_version z3 z3 --version
run_version svlint svlint --version
run_version fusesoc fusesoc --version
run_version klayout klayout -v
run_version netgen-lvs netgen-lvs -batch help
run_version sta sta -version

if command -v magic >/dev/null 2>&1; then
  printf "\n== magic ==\n"
  printf "version\nquit -noprompt\n" | magic -dnull -noconsole || true
fi

printf "\n== python packages ==\n"
python3 - <<'PY'
from importlib.metadata import version

for package in ["edalize", "cocotb", "fusesoc", "numpy", "pillow", "pytest"]:
    try:
        print(f"{package} {version(package)}")
    except Exception as exc:
        print(f"{package} missing: {exc}")
PY
