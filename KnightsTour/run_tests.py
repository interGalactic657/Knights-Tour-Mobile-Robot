import os
import subprocess
import time

# Directories
root_dir = os.path.abspath(os.path.dirname(__file__))  # Top-level directory (current directory)
design_dir = os.path.join(root_dir, "designs")  # Design files directory
test_dir = os.path.join(root_dir, "tests")  # Test files directory
output_dir = os.path.join(root_dir, "output")  # Output directory for logs and results
library_dir = os.path.join(root_dir, "work")  # Simulation library directory
project_dir = os.path.join(root_dir, "KnightsTour_project")  # Project directory for ModelSim

# Ensure output and library directories exist
os.makedirs(output_dir, exist_ok=True)
os.makedirs(library_dir, exist_ok=True)

# ModelSim project filename
project_file = os.path.join(project_dir, "KnightsTour_project.prj")

# Create the ModelSim project if it doesn't exist
def create_or_open_project():
    if not os.path.exists(project_file):
        print(f"Creating new ModelSim project at {project_file}...")
        # Create the project directory
        os.makedirs(project_dir, exist_ok=True)
        # Create the project file using vsim
        subprocess.run(f"vsim -do \"vlib work; vmap work {library_dir};\"", shell=True, check=True)
        
    else:
        print(f"Opening existing ModelSim project at {project_file}...")
        subprocess.run(f"vsim -do \"vlib work; vmap work {library_dir};\"", shell=True, check=True)

# Add design and test files to the project
def add_files_to_project():
    print("Adding files to the ModelSim project...")
    
    # Add design files
    for root, dirs, files in os.walk(design_dir):
        if "tests" in dirs:
            dirs.remove("tests")  # Skip the `tests` subdirectory
        
        for file in files:
            if file.endswith(".sv"):
                file_path = os.path.join(root, file)
                print(f"Adding design file to the project: {file}")
                subprocess.run(f"vsim -do \"vlog {file_path}\"", shell=True, check=True)
    
    # Add test files
    test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
    for test_file in test_files:
        test_path = os.path.join(test_dir, test_file)
        if os.path.exists(test_path):
            print(f"Adding test file to the project: {test_file}")
            subprocess.run(f"vsim -do \"vlog {test_path}\"", shell=True, check=True)

# Compile only the files that are out of date
def compile_modified_files():
    print("Compiling modified files...")

    # Compile design files
    for root, dirs, files in os.walk(design_dir):
        if "tests" in dirs:
            dirs.remove("tests")  # Skip the `tests` subdirectory
        
        for file in files:
            if file.endswith(".sv"):
                file_path = os.path.join(root, file)
                last_compile_time = os.path.getmtime(file_path)
                compiled_file = os.path.join(library_dir, file.replace(".sv", ".vhi"))

                # Compile if the file is out of date
                if not os.path.exists(compiled_file) or os.path.getmtime(compiled_file) < last_compile_time:
                    print(f"Compiling out-of-date design file: {file}")
                    subprocess.run(f"vlog {file_path}", shell=True, check=True)

    # Compile shared test files
    test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
    for test_file in test_files:
        test_path = os.path.join(test_dir, test_file)
        if os.path.exists(test_path):
            last_compile_time = os.path.getmtime(test_path)
            compiled_test_file = os.path.join(library_dir, test_file.replace(".sv", ".vhi"))

            # Compile if the file is out of date
            if not os.path.exists(compiled_test_file) or os.path.getmtime(compiled_test_file) < last_compile_time:
                print(f"Compiling out-of-date test file: {test_file}")
                subprocess.run(f"vlog {test_path}", shell=True, check=True)

# Compile and run testbenches from subdirectories: simple, move, logic
def compile_and_run_tests():
    print("Running simulations for testbenches...")

    test_subdirs = ["simple", "move", "logic"]
    for subdir in test_subdirs:
        subdir_path = os.path.join(test_dir, subdir)
        if os.path.exists(subdir_path):
            for file in os.listdir(subdir_path):
                if file.endswith(".sv"):
                    test_path = os.path.join(subdir_path, file)
                    test_name = os.path.splitext(file)[0]
                    log_file = os.path.join(output_dir, f"{test_name}.log")
                    wave_file = os.path.join(output_dir, f"{test_name}.wlf")

                    # Add the testbench to the project and run it
                    print(f"Running testbench: {file}")
                    subprocess.run(f"vsim work.KnightsTour_tb -do \"add wave -r /*; run -all; write wave -file {wave_file}; log -flush /*; quit;\"", shell=True, check=True)

# Main function to orchestrate the process
def main():
    # Create/open the ModelSim project
    create_or_open_project()

    # Add files to the project
    add_files_to_project()

    # Compile only the files that are out of date
    compile_modified_files()

    # Compile and run tests
    compile_and_run_tests()

    print("All tests completed.")

if __name__ == "__main__":
    main()
