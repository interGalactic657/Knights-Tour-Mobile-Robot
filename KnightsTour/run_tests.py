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

# Compile all design files (ignoring `tests/` subdirectories)
for root, dirs, files in os.walk(design_dir):
    if "tests" in dirs:
        dirs.remove("tests")  # Skip the `tests` subdirectory
    
    for file in files:
        if file.endswith(".sv"):
            file_path = os.path.join(root, file)
            print(f"Compiling design file: {file}")
            subprocess.run(f"vlog {file_path}", shell=True, check=True)

# Compile shared test files
test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
for test_file in test_files:
    test_path = os.path.join(test_dir, test_file)
    if os.path.exists(test_path):
        print(f"Compiling test file: {test_file}")
        subprocess.run(f"vlog {test_path}", shell=True, check=True)

# Compile and run testbenches from subdirectories: simple, move, logic
test_subdirs = ["simple", "move", "logic"]
for subdir in test_subdirs:
    subdir_path = os.path.join(test_dir, subdir)
    if os.path.exists(subdir_path):
        for file in os.listdir(subdir_path):
            if file.endswith(".sv"):
                test_path = os.path.join(subdir_path, file)
                test_name = os.path.splitext(file)[0]
                log_file = os.path.join(output_dir, f"{test_name}.log")

                # Compile the testbench
                print(f"Compiling testbench: {file}")
                subprocess.run(f"vlog {test_path}", shell=True, check=True)

                ## Run the simulation
                print(f"Running simulation for: {test_name}")
                sim_command = f"vsim -c work.KnightsTour_tb -do 'run -all; quit;' > {log_file}"
                subprocess.run(sim_command, shell=True, check=True)
                
print("All tests completed.")