.PHONY: check-tools tool-versions assemble-kernels check-kernel-fixtures test-tools lint formal sim list-sim-tests synth-yosys synth-vivado regress clean

REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

check-tools:
	tools/scripts/check_tools.sh

tool-versions:
	tools/scripts/tool_versions.sh

assemble-kernels:
	python3 $(REPO_ROOT)tools/scripts/assemble_kernels.py --write

check-kernel-fixtures:
	python3 $(REPO_ROOT)tools/scripts/assemble_kernels.py --check

test-tools:
	python3 $(REPO_ROOT)tools/scripts/assemble_kernels.py --check
	pytest $(REPO_ROOT)tests

lint:
	tools/scripts/lint.sh

formal:
	formal/scripts/run_sby.sh

sim:
	tools/scripts/run_sim.sh

list-sim-tests:
	SIM_LIST=1 tools/scripts/run_sim.sh

synth-yosys:
	tools/scripts/synth_yosys.sh

synth-vivado:
	tools/scripts/synth_vivado.sh

regress:
	$(MAKE) check-kernel-fixtures
	$(MAKE) test-tools
	$(MAKE) sim
	$(MAKE) lint
	$(MAKE) formal
	$(MAKE) synth-yosys

clean:
	find . -type d -name obj_dir -prune -exec rm -rf {} +
	find . -type d -name sim_build -prune -exec rm -rf {} +
	find . -type d -name synth_build -prune -exec rm -rf {} +
	find . -type f \( -name '*.vcd' -o -name '*.fst' -o -name '*.vvp' \) -delete
