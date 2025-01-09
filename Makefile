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

# Declare the `synthesis`, `run`, `log`, `collect`, and `clean` targets as phony to avoid conflicts.
.PHONY: synthesis run log collect clean

#--------------------------------------------------------
# Default Synthesis Target
# Runs the Design Compiler script to perform RTL-to-Gate 
# synthesis, generating a .vg file (Verilog netlist) and
# a .sdc file (timing constraints). The synthesis process
# will only run if the .dc script changes or if any .sv 
# files are modified, ensuring efficient execution.
#
# Usage:
#   make synthesis - Executes synthesis if the .vg
#                    file is missing or out of date.
#--------------------------------------------------------
# Variables for directories and file patterns
DC_SCRIPT := ./scripts/KnightsTour.dc
PRE_SYNTH_DIR := ./designs/pre_synthesis
PRE_SYNTH_MAIN_DIR := ./designs/pre_synthesis/main
POST_SYNTH_DIR := ./designs/post_synthesis
OUTPUT_LOG_DIR := ./main/output/logs/compilation
VG_FILE := $(POST_SYNTH_DIR)/KnightsTour.vg

# Find all .sv files in the pre-synthesis directories
SV_FILES := $(wildcard $(PRE_SYNTH_DIR)/*.sv) $(wildcard $(PRE_SYNTH_MAIN_DIR)/*.sv)

# Top-level synthesis target
synthesis: $(VG_FILE)

# Dependency rule for generating the .vg file
$(VG_FILE): $(DC_SCRIPT) $(SV_FILES)
	@echo "Synthesizing KnightsTour to Synopsys 32-nm Cell Library..."
	@mkdir -p ./main/synthesis
	@mkdir -p $(POST_SYNTH_DIR)
	@mkdir -p $(OUTPUT_LOG_DIR)
	@mkdir -p ./main/output/logs/transcript/reports/
	@cd ./main/synthesis && \
	echo "source ../../scripts/KnightsTour.dc; report_register -level_sensitive; check_design; exit;" | \
	dc_shell -no_gui > ../../$(OUTPUT_LOG_DIR)/synth_compilation.log 2>&1
	@echo "Synthesis complete. Run 'make log c s' for details."

#--------------------------------------------------------
# Run Target
# Executes test cases based on the provided mode and arguments.
#
# Usage:
#   make run                        - Runs all tests in default mode.
#   make run <test_number>          - Runs a specific test by number.
#   make run <test_range>           - Runs a range of tests.
#   make run a/m/e g <args>         - Run all/main/extra tests in GUI mode.
#   make run a/m/e s <args>         - Run all/main/extra tests in GUI mode and save waveforms.
#   make run a/m/e v <args>         - View all/main/extra waveforms in GUI mode.
#
# Arguments:
#   v - View waveforms in GUI mode.
#   g - Run tests in GUI mode.
#   s - Run tests and save waveforms.
#   <test_number> - The number of the test to execute.
#   <test_range>  - A range of tests to execute, e.g., 1-10.
#
# Description:
# This target determines the behavior based on the number and type of
# arguments passed (`runargs`). It invokes a Python script with the
# appropriate mode flags:
#   - Mode 0: Default mode.
#   - Mode 1: Save waveforms.
#   - Mode 2: GUI mode.
#   - Mode 3: View waveforms in GUI mode.
# It provides usage guidance and error handling for invalid inputs.
#--------------------------------------------------------
run:
	@if [ "$(words $(runargs))" -eq 0 ]; then \
		# No arguments provided: Default behavior, run all tests. \
		cd scripts && python3 run_tests.py -m 0; \
	else \
		# Parse arguments based on the first word. \
		case "$(word 1,$(runargs))" in \
			a|m|e) \
				# Handle test types: all (a), main (m), or extra (e). \
				if [ "$(words $(runargs))" -eq 1 ]; then \
					# Run all tests of the specified type in default mode. \
					cd scripts && python3 run_tests.py -m 0 -t $(word 1,$(runargs)); \
				else \
					case "$(word 2,$(runargs))" in \
						v) mode=3 ;;  # View waveforms. \
						g) mode=2 ;;  # GUI mode. \
						s) mode=1 ;;  # Save waveforms. \
						[0-9]*) \
							# Handle specific test numbers or ranges without specifying test type. \
							if [ "$(words $(runargs))" -eq 2 ]; then \
								# Single test number. \
								cd scripts && python3 run_tests.py -n $(word 2,$(runargs)) -m 0 -t $(word 1,$(runargs)); \
							elif [ "$(words $(runargs))" -eq 3 ]; then \
								# Test range. \
								cd scripts && python3 run_tests.py -r $(word 2,$(runargs)) $(word 3,$(runargs)) -m 0 -t $(word 1,$(runargs)); \
							else \
								# Invalid number of arguments for test numbers/ranges. \
								echo "Error: Invalid argument format for test number or range."; \
								exit 1; \
							fi; \
							;; \
						*) \
							# Invalid sub-mode, show error. \
							echo "Error: Invalid sub-mode for tests. Supported modes are v, g, or s."; \
							exit 1; \
							;; \
					esac; \
					if [ "$(words $(runargs))" -eq 4 ]; then \
						# Handle test ranges with sub-mode. \
						cd scripts && python3 run_tests.py -r $(word 3,$(runargs)) $(word 4,$(runargs)) -m $$mode -t $(word 1,$(runargs)); \
					elif [ "$(words $(runargs))" -eq 3 ]; then \
						# Handle specific test numbers with sub-mode. \
						cd scripts && python3 run_tests.py -n $(word 3,$(runargs)) -m $$mode -t $(word 1,$(runargs)); \
					else \
						# Run all tests of the specified type with the sub-mode. \
						cd scripts && python3 run_tests.py -m $$mode -t $(word 1,$(runargs)); \
					fi; \
				fi; \
				;; \
			[0-9]*) \
				# Handle specific test numbers or ranges without specifying test type. \
				if [ "$(words $(runargs))" -eq 2 ]; then \
					# Single test number. \
					cd scripts && python3 run_tests.py -n $(word 1,$(runargs)) -m 0; \
				elif [ "$(words $(runargs))" -eq 3 ]; then \
					# Test range. \
					cd scripts && python3 run_tests.py -r $(word 1,$(runargs)) $(word 2,$(runargs)) -m 0; \
				else \
					# Invalid number of arguments for test numbers/ranges. \
					echo "Error: Invalid argument format for test number or range."; \
					exit 1; \
				fi; \
				;; \
			*) \
				# Invalid first argument, show usage guidance. \
				echo "Error: Invalid argument combination."; \
				echo "Usage:"; \
				echo "  make run                        # Run all tests in default mode."; \
				echo "  make run <test_number>          # Run a specific test."; \
				echo "  make run <test_range>           # Run a range of tests."; \
				echo "  make run a|m|e v|g|s <args>     # Run tests with specified mode."; \
				exit 1; \
				;; \
		esac; \
	fi;

#--------------------------------------------------------
# Log Target
# Displays various log files depending on the specified mode and arguments.
#
# Usage:
#   make log logargs="s <report_type>"  - Displays synthesis reports based on the specified type.
#   make log logargs="c <type> <number>" - Displays compilation logs based on type or test number.
#   make log logargs="t <type> <number>" - Displays transcript logs for a specific test.
#
# Arguments:
#   s - For displaying synthesis-related reports:
#       a - Area report.
#       n - Min delay report.
#       x - Max delay report.
#   c - For displaying compilation logs:
#       s - Synthesis compilation log.
#       m <test_number> - Compilation log for a specific main test.
#       e <test_number> - Compilation log for a specific extra test.
#   t - For displaying transcript logs for a specific test:
#       m <test_number> - Transcript log for a main test.
#       e <test_number> - Transcript log for an extra test.
#
# Description:
# This target checks for different modes (`s`, `c`, `t`) and performs corresponding actions
# to display the appropriate log files based on the sub-arguments provided.
# Displays error messages for invalid or missing arguments.
#--------------------------------------------------------
log:
	@if [ "$(words $(logargs))" -ge 1 ]; then \
		case "$(word 1,$(logargs))" in \
		s) \
			# Handle 's' for synthesis reports. \
			case "$(word 2,$(logargs))" in \
			a) \
				echo "Displaying area report:"; \
				cat ./main/output/logs/transcript/reports/KnightsTour_area.txt ;; \
			n) \
				echo "Displaying min delay report:"; \
				cat ./main/output/logs/transcript/reports/KnightsTour_min_delay.txt ;; \
			x) \
				echo "Displaying max delay report:"; \
				cat ./main/output/logs/transcript/reports/KnightsTour_max_delay.txt ;; \
			*) \
				echo "Error: Invalid sub-argument for 's' log type. Valid options: a, n, x."; \
				exit 1 ;; \
			esac ;; \
		c) \
			# Handle 'c' for compilation logs. \
			if [ "$(words $(logargs))" -ge 2 ]; then \
				case "$(word 2,$(logargs))" in \
				s) \
					echo "Displaying synthesis compilation log:"; \
					cat ./main/output/logs/compilation/synth_compilation.log ;; \
				m) \
					echo "Displaying compilation log for main test $(word 3,$(logargs)):"; \
					cat ./main/output/logs/compilation/compilation_$(word 3,$(logargs)).log ;; \
				e) \
					echo "Displaying compilation log for extra test $(word 3,$(logargs)):"; \
					cat ./extra/output/logs/compilation/compilation_$(word 3,$(logargs)).log ;; \
				*) \
					echo "Error: Invalid argument for 'c' log type. Usage: c s | c m <number> | c e <number>"; \
					exit 1 ;; \
				esac; \
			else \
				echo "Error: Missing argument for 'c' log type. Usage: c s | c m <number> | c e <number>"; \
				exit 1; \
			fi ;; \
		t) \
			# Handle 't' for transcript logs. \
			if [ "$(words $(logargs))" -ge 3 ]; then \
				case "$(word 2,$(logargs))" in \
				m) \
					echo "Displaying transcript log for main test $(word 3,$(logargs)):"; \
					cat ./main/output/logs/transcript/KnightsTour_tb_$(word 3,$(logargs)).log ;; \
				e) \
					echo "Displaying transcript log for extra test $(word 3,$(logargs)):"; \
					cat ./extra/output/logs/transcript/KnightsTour_tb_$(word 3,$(logargs)).log ;; \
				*) \
					echo "Error: Invalid argument for 't' log type. Usage: t m <number> | t e <number>"; \
					exit 1 ;; \
				esac; \
			else \
				echo "Error: Missing argument for 't' log type. Usage: t m <number> | t e <number>"; \
				exit 1; \
			fi ;; \
		*) \
			# Handle invalid log types. \
			echo "Error: Invalid argument for log target. Usage:"; \
			echo "  make log logargs=\"s <report_type>\""; \
			echo "  make log logargs=\"c <type> <number>\""; \
			echo "  make log logargs=\"t <type> <number>\""; \
			exit 1 ;; \
		esac; \
	else \
		# Handle missing arguments. \
		echo "Error: Missing arguments for log target. Usage:"; \
		echo "  make log logargs=\"s <report_type>\""; \
		echo "  make log logargs=\"c <type> <number>\""; \
		echo "  make log logargs=\"t <type> <number>\""; \
		exit 1; \
	fi;

#--------------------------------------------------------
# Collect Target
# Collects test files or all design files based on the specified arguments.
#
# Usage:
#   make collect <m|e> <start_number> <end_number> - Collects test files for a range of test numbers and design files.
#   make collect <m|e>                              - Collects all design files from the specified directory.
#
# Arguments:
#   <m|e> - Mandatory flag specifying which subdirectory to use for design files:
#           'm' for 'main', 'e' for 'extra'.
#   <start_number> <end_number> - Range of test numbers (inclusive) to collect test files.
#
# Description:
# This target handles two scenarios:
# 1. Collecting test files for a specified range of test numbers (if three arguments are provided).
#    - Test files are collected from their respective subdirectories (`simple`, `move`, `logic`).
#    - For `logic` tests, the `main` or `extra` subdirectory is determined by the flag.
# 2. Collecting all design files (if only the flag is provided).
#    - Design files are copied from the base directory and either `main` or `extra` based on the flag.
#
# If no files are found for the specified range, a warning message is displayed.
#--------------------------------------------------------
collect:
	@if [ "$(words $(collectargs))" -eq 3 ]; then \
		# Three arguments: m/e + range. \
		flag=$(word 1,$(collectargs)); \
		start=$(word 2,$(collectargs)); \
		end=$(word 3,$(collectargs)); \
		if [ "$$flag" = "m" ]; then \
			dir="main"; \
			target_dir="../KnightsTourMain"; \
		elif [ "$$flag" = "e" ]; then \
			dir="extra"; \
			target_dir="../KnightsTourExtra"; \
		else \
			echo "Error: Invalid argument '$$flag'. Use 'm' for main or 'e' for extra."; \
			exit 1; \
		fi; \
		mkdir -p $$target_dir; \
		echo "Collecting test files from $$start to test $$end for '$$dir'..."; \
		found=0; \
		for num in $$(seq $$start $$end); do \
			# Determine the subdirectory based on test number. \
			if echo "$(simple_tests)" | grep -qw $$num; then \
				subdir="simple"; \
			elif echo "$(move_tests)" | grep -qw $$num; then \
				subdir="move"; \
			elif echo "$(logic_tests)" | grep -qw $$num; then \
				subdir="logic/$$dir"; \
			else \
				echo "Warning: Test number $$num is not mapped to any subdirectory. Skipping."; \
				continue; \
			fi; \
			# Path to the test file. \
			src_file="./tests/$$subdir/KnightsTour_tb_$$num.sv"; \
			# Copy the file if it exists. \
			if [ -f $$src_file ]; then \
				cp $$src_file $$target_dir/; \
				found=1; \
			else \
				echo "Error: Test file $$src_file not found."; \
			fi; \
		done; \
		# If no files were found in the range, print a message. \
		if [ $$found -eq 1 ]; then \
			echo "All test files collected for '$$dir'."; \
		else \
			echo "No test files were found for the range $$start-$$end."; \
		fi; \
	elif [ "$(words $(collectargs))" -eq 1 ]; then \
		# One argument: m/e only. \
		flag=$(word 1,$(collectargs)); \
		if [ "$$flag" = "m" ]; then \
			dir="main"; \
			target_dir="../KnightsTourMain"; \
		elif [ "$$flag" = "e" ]; then \
			dir="extra"; \
			target_dir="../KnightsTourExtra"; \
		else \
			echo "Error: Invalid argument '$$flag'. Use 'm' for main or 'e' for extra."; \
			exit 1; \
		fi; \
		echo "Collecting all design files for '$$dir'..."; \
		mkdir -p $$target_dir; \
		cp ./designs/pre_synthesis/*.sv $$target_dir/; \
		cp ./designs/pre_synthesis/$$dir/*.sv $$target_dir/; \
		echo "All design files collected for '$$dir'."; \
	else \
		# Invalid usage: Display error and usage information. \
		echo "Error: Invalid arguments. Usage:"; \
		echo "  make collect <m|e> <start_number> <end_number>"; \
		echo "  make collect <m|e>"; \
		exit 1; \
	fi;

#--------------------------------------------------------
# Clean Target
# Removes all generated files and directories to start fresh.
#
# Usage:
#   make clean
#
# Description:
# This target is used to clean up the generated files and directories that are created during the build or test process.
# It removes the following directories:
# - main: Contains the main directory related to design files.
# - extra: Contains the extra directory related to design files.
# - KnightsTourMain/Extra: A directory where collected test files are stored.
#
# This is typically used to ensure that the build process starts with a clean slate, removing all files that might be left over from previous runs.
#--------------------------------------------------------
clean:
	@echo "Cleaning up generated files..."
	@rm -rf main/        # Remove the main directory.
	@rm -rf extra/       # Remove the extra directory.
	@rm -rf ../KnightsTourMain # Remove main collected files.
	@rm -rf ../KnightsTourExtra # Remove extra collected files.
	@echo "Cleanup complete."