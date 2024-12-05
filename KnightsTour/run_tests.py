import os
import subprocess

# Directories
root_dir = os.path.abspath(os.path.dirname(__file__))  # Top-level directory (current directory)
design_dir = os.path.join(root_dir, "designs")  # Design files directory
test_dir = os.path.join(root_dir, "tests")  # Test files directory
output_dir = os.path.join(root_dir, "output")  # Output directory for logs and results
library_dir = os.path.join(root_dir, "work")  # Simulation library directory

# Ensure output and library directories exist
os.makedirs(output_dir, exist_ok=True)
os.makedirs(library_dir, exist_ok=True)

# List of all test directories (one for each test)
test_directories = [f"test_{i}" for i in range(1, 15)]  # test_1, test_2, ..., test_14

# Compile all design files
def compile_design_files():
    for root, dirs, files in os.walk(design_dir):
        for file in files:
            if file.endswith(".sv"):
                file_path = os.path.join(root, file)
                print(f"Compiling design file: {file}")
                subprocess.run(f"vlog {file_path}", shell=True, check=True)

# Compile and run tests for each test directory
def compile_and_run_tests():
    for test_dir_name in test_directories:
        testbench_dir = os.path.join(test_dir, test_dir_name)

        if os.path.exists(testbench_dir):
            # Compile testbench-specific files (and ensure all design files are compiled)
            for root, dirs, files in os.walk(testbench_dir):
                for file in files:
                    if file.endswith(".sv") and file != "KnightsTour_tb.sv":
                        file_path = os.path.join(root, file)
                        print(f"Compiling testbench file: {file}")
                        subprocess.run(f"vlog {file_path}", shell=True, check=True)

            # Run the simulation for the testbench
            testbench_file = os.path.join(testbench_dir, "KnightsTour_tb.sv")
            if os.path.exists(testbench_file):
                test_name = f"{test_dir_name}_KnightsTour_tb"
                log_file = os.path.join(output_dir, f"{test_name}.log")
                wave_file = os.path.join(output_dir, f"{test_name}.wlf")

                print(f"Running simulation for: {test_name}")
                sim_command = f"vsim -c work.KnightsTour_tb -do \"add wave -r /*; run -all; write wave -file {wave_file}; log -flush /*; quit;\" > {log_file}"
                subprocess.run(sim_command, shell=True, check=True)
            else:
                print(f"Testbench file KnightsTour_tb.sv not found in {testbench_dir}. Skipping.")

# Main function to orchestrate the process
def main():
    # Compile all design files once
    compile_design_files()

    # Compile and run tests for all test directories
    compile_and_run_tests()

    print("All tests completed.")

if __name__ == "__main__":
    main()
