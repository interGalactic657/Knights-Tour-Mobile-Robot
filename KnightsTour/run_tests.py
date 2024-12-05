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

# Initialize the .do file for ModelSim
do_file_path = os.path.join(root_dir, "run_tests.do")
with open(do_file_path, "w") as do_file:
    # Write commands to create the library
    do_file.write(f"vlib work\n")
    
    # Compile all design files (ignoring `tests/` subdirectories)
    for root, dirs, files in os.walk(design_dir):
        if "tests" in dirs:
            dirs.remove("tests")  # Skip the `tests` subdirectory
        
        for file in files:
            if file.endswith(".sv"):
                file_path = os.path.join(root, file)
                print(f"Adding design file to .do: {file}")
                do_file.write(f"vlog {file_path}\n")
    
    # Compile shared test files
    test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
    for test_file in test_files:
        test_path = os.path.join(test_dir, test_file)
        if os.path.exists(test_path):
            print(f"Adding test file to .do: {test_file}")
            do_file.write(f"vlog {test_path}\n")
    
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
                    wave_file = os.path.join(output_dir, f"{test_name}.wlf")

                    # Add the testbench to the .do file
                    print(f"Adding testbench to .do: {file}")
                    do_file.write(f"vlog {test_path}\n")  # Compile the file
                    do_file.write(f"vsim work.KnightsTour_tb\n")  # Always run `KnightsTour_tb`
                    do_file.write(f"add wave -r /*\n")  # Add all signals to the waveform
                    do_file.write(f"run -all\n")  # Run the simulation
                    do_file.write(f"write wave -file {wave_file}\n")  # Save the waveform

                    # Corrected logging command:
                    do_file.write(f"log -flush /*\n")  # Log all signals (or specify signals as needed)
                    do_file.write(f"exit\n")  # Exit after each test

    # End the .do file
    do_file.write("quit\n")

# Run the generated .do file in ModelSim with GUI (without -novopt)
print(f"Running ModelSim with .do file: {do_file_path}")
subprocess.run(f"vsim -gui -do {do_file_path}", shell=True, check=True)

print("All tests completed.")
