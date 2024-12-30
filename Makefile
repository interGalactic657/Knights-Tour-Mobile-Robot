#--------------------------------------------------------
# Makefile for Synthesis, Simulation, Logs, and File Collection
# This Makefile handles multiple targets:
# - `synthesis` for synthesizing design to Synopsys 32-nm Cell Library
# - `run` for running simulations
# - `log` for viewing log files
# - `collect` for collecting design and test files
# - `clean` for cleaning up the directories
#--------------------------------------------------------

# Handle different goals (run, log, collect, synthesis) by parsing arguments passed to make.
ifeq ($(firstword $(MAKECMDGOALS)), run)
  runargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Create dummy targets for each argument to prevent make from interpreting them as file targets.
  $(eval $(runargs):;@true)
else ifeq ($(firstword $(MAKECMDGOALS)), log)
  logargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
 # Create dummy targets for each argument to prevent make from interpreting them as file targets.
  $(eval $(logargs):;@true)
else ifeq ($(firstword $(MAKECMDGOALS)), collect)
  collectargs := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
  # Create dummy targets for each argument to prevent make from interpreting them as file targets.
  $(eval $(collectargs):;@true)
endif

# Define test number mappings to subdirectories.
simple_tests := 0 1
move_tests := 2 3 4 5 6 7 8 9 10 11 12 13 14
logic_tests := 15 16 17 18 19 20 21 22 23 24 25 26 27 28

# Declare the `run`, `log`, `synthesis`, `collect`, and `clean` targets as phony to avoid conflicts.
.PHONY: synthesis run log collect clean

#--------------------------------------------------------
# Synthesis target - Runs the Design Compiler script for synthesis.
# Usage: make synthesis
synthesis:
	@echo "Synthesizing KnightsTour to Synopsys 32-nm Cell Library..."
	@mkdir -p ./synthesis
	@mkdir -p ./output/logs/compilation
	@mkdir -p ./output/logs/transcript/reports/
	@cd ./synthesis && echo "source ../scripts/KnightsTour.dc; exit;" | dc_shell -no_gui > ../output/logs/compilation/synth_compilation.log 2>&1
	@echo "Synthesis complete. Run 'make log c s' for details."

#--------------------------------------------------------
# Default run target - Executes tests based on the provided mode and arguments.
# Usage: make run <mode> <test_number> or <test_range>
run:
	@if [ "$(words $(runargs))" -eq 0 ]; then \
		# No arguments: Default behavior. \
		cd scripts && python3 run_tests.py -m 0; \
	elif [ "$(words $(runargs))" -ge 1 ]; then \
		case "$(word 1,$(runargs))" in \
		v) \
			# If 'v' is specified, view waveforms in GUI mode. \
			if [ "$(words $(runargs))" -eq 3 ]; then \
				cd scripts && python3 run_tests.py -r $(word 2,$(runargs)) $(word 3,$(runargs)) -m 3; \
			elif [ "$(words $(runargs))" -eq 2 ]; then \
				cd scripts && python3 run_tests.py -n $(word 2,$(runargs)) -m 3; \
			else \
				cd scripts && python3 run_tests.py -m 3; \
			fi ;; \
		g) \
			# If 'g' is specified, run tests in GUI mode. \
			if [ "$(words $(runargs))" -eq 3 ]; then \
				cd scripts && python3 run_tests.py -r $(word 2,$(runargs)) $(word 3,$(runargs)) -m 2; \
			elif [ "$(words $(runargs))" -eq 2 ]; then \
				cd scripts && python3 run_tests.py -n $(word 2,$(runargs)) -m 2; \
			else \
				cd scripts && python3 run_tests.py -m 2; \
			fi ;; \
		s) \
			# If 's' is specified, run tests and save waveforms. \
			if [ "$(words $(runargs))" -eq 3 ]; then \
				cd scripts && python3 run_tests.py -r $(word 2,$(runargs)) $(word 3,$(runargs)) -m 1; \
			elif [ "$(words $(runargs))" -eq 2 ]; then \
				cd scripts && python3 run_tests.py -n $(word 2,$(runargs)) -m 1; \
			else \
				cd scripts && python3 run_tests.py -m 1; \
			fi ;; \
		[0-9]*) \
			# Default mode (command-line mode) with test number or range. \
			if [ "$(words $(runargs))" -eq 2 ]; then \
				cd scripts && python3 run_tests.py -r $(word 1,$(runargs)) $(word 2,$(runargs)) -m 0; \
			elif [ "$(words $(runargs))" -eq 1 ]; then \
				cd scripts && python3 run_tests.py -n $(word 1,$(runargs)) -m 0; \
			else \
				echo "Error: Invalid argument combination."; \
				exit 1; \
			fi ;; \
		*) \
			# Invalid argument error. \
			echo "Error: Invalid mode or arguments. Supported modes are:"; \
			echo "  v - View waveforms in GUI mode"; \
			echo "  g - Run tests in GUI mode"; \
			echo "  s - Run tests and save waveforms"; \
			echo "  <test_number>/<test_range> - Run specific tests"; \
			exit 1 ;; \
		esac; \
	else \
		# Invalid usage: Display error and usage information. \
		echo "Error: Invalid arguments. Usage:"; \
		echo "  make run v|g|s <test_number>/<test_range>"; \
		echo "  make run <test_number>/<test_range>"; \
		exit 1; \
	fi;

#--------------------------------------------------------
# log target - Displays specific logs based on the argument passed.
# Usage: make log <log_type> and/or <report_type>/<test_number>
log:
	@if [ "$(words $(logargs))" -ge 1 ]; then \
		case "$(word 1,$(logargs))" in \
		s) \
			# Check for sub-arguments under 's' for different log types. \
			case "$(word 2,$(logargs))" in \
			a) \
				echo "Displaying area report:"; \
				cat ./output/logs/transcript/reports/KnightsTour_area.txt ;; \
			n) \
				echo "Displaying min delay report:"; \
				cat ./output/logs/transcript/reports/KnightsTour_min_delay.txt ;; \
			x) \
				echo "Displaying max delay report:"; \
				cat ./output/logs/transcript/reports/KnightsTour_max_delay.txt ;; \
			*) \
				echo "Error: Invalid sub-argument for 's' log type."; \
				exit 1 ;; \
			esac ;; \
		c) \
			if [ "$(words $(logargs))" -eq 2 ]; then \
				case "$(word 2,$(logargs))" in \
				s) \
					echo "Displaying synthesis compilation log:"; \
					cat ./output/logs/compilation/synth_compilation.log ;; \
				*) \
					echo "Displaying compilation log for test $(word 2,$(logargs)):"; \
					cat ./output/logs/compilation/compilation_$(word 2,$(logargs)).log ;; \
				esac; \
			else \
				echo "Error: Invalid argument for log target."; \
				exit 1; \
			fi ;; \
		t) \
			if [ "$(words $(logargs))" -eq 2 ]; then \
				echo "Displaying transcript log for test $(word 2,$(logargs)):"; \
				cat ./output/logs/transcript/KnightsTour_tb_$(word 2,$(logargs)).log; \
			else \
				echo "Error: 't' requires a test number (e.g., make log t 3)."; \
				exit 1; \
			fi ;; \
		*) \
			echo "Error: Missing or invalid arguments. Usage:"; \
			echo "  make log s <report_type>"; \
			echo "  make log c <type/number>"; \
			echo "  make log t <number>"; \
			exit 1 ;; \
		esac; \
	else \
		echo "Error: Missing argument for logs target."; \
		exit 1; \
	fi;

#--------------------------------------------------------
# Collect target - Collects design or test files for simulation or processing.
# Usage: make collect <start_test> <end_test>
collect:
	@if [ "$(words $(collectargs))" -eq 2 ]; then \
		start=$(word 1,$(collectargs)); \
		end=$(word 2,$(collectargs)); \
		target_dir="../KnightsTour"; \
		mkdir -p $$target_dir; \
		echo "Collecting test files from $$start to test $$end..."; \
		found=0; \
		for num in $$(seq $$start $$end); do \
			# Determine the subdirectory based on test number \
			if echo "$(simple_tests)" | grep -qw $$num; then \
				subdir="simple"; \
			elif echo "$(move_tests)" | grep -qw $$num; then \
				subdir="move"; \
			elif echo "$(logic_tests)" | grep -qw $$num; then \
				subdir="logic"; \
			else \
				echo "Warning: Test number $$num is not mapped to any subdirectory. Skipping."; \
				continue; \
			fi; \
			# Path to the test file. \
			src_file="./tests/$$subdir/KnightsTour_tb_$$num.sv"; \
			# Copy the file if it exists \
			if [ -f $$src_file ]; then \
				cp $$src_file $$target_dir/; \
				found=1; \
			else \
				echo "Error: Test file $$src_file not found."; \
			fi; \
		done; \
		# If no files were found in the range, print a message. \
		if [ $$found -eq 1 ]; then \
			echo "All test files collected."; \
		else \
			echo "No test files were found for the range $$start-$$end."; \
		fi; \
	else \
		# Collect all design files if no range is provided. \
		echo "Collecting all design files..."; \
		mkdir -p ../KnightsTour; \
		cp ./designs/pre_synthesis/*.sv ../KnightsTour/; \
		echo "All design files collected."; \
	fi;

#--------------------------------------------------------
# Clean target - Cleans up all generated files and directories.
clean:
	@echo "Cleaning up generated files..."
	@rm -rf TESTS/         # Remove the TESTS directory.
	@rm -rf output/        # Remove the output directory.
	@rm -rf synthesis/     # Remove the synthesis directory.
	@rm -rf ../KnightsTour # Remove collected files.
	@echo "Cleanup complete."