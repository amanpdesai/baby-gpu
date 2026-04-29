.PHONY: check-tools tool-versions lint formal sim clean

check-tools:
	tools/scripts/check_tools.sh

tool-versions:
	tools/scripts/tool_versions.sh

lint:
	tools/scripts/lint.sh

formal:
	formal/scripts/run_sby.sh

sim:
	tools/scripts/run_sim.sh

clean:
	find . -type d -name obj_dir -prune -exec rm -rf {} +
	find . -type d -name sim_build -prune -exec rm -rf {} +
	find . -type f \( -name '*.vcd' -o -name '*.fst' -o -name '*.vvp' \) -delete
