import os
import subprocess

# Directories
root_dir = os.path.abspath(os.path.dirname(__file__))  # Top-level directory (current directory)
design_dir = os.path.join(root_dir, "designs")  # Design files directory
test_dir = os.path.join(root_dir, "tests")  # Test files directory
output_dir = os.path.join(root_dir, "output")  # Output directory for logs and results
library_dir = os.path.join(root_dir, "work")  # Simulation library directory
waves_dir = os.path.join(output_dir, "waves")  # Waves directory
transcript_dir = os.path.join(output_dir, "transcript")  # Transcript directory

# Ensure output, waves, and transcript directories exist
os.makedirs(output_dir, exist_ok=True)
os.makedirs(waves_dir, exist_ok=True)
os.makedirs(transcript_dir, exist_ok=True)

# Compile all design files (ignoring `tests/` subdirectories)
for root, dirs, files in os.walk(design_dir):
    if "tests" in dirs:
        dirs.remove("tests")  # Skip the `tests` subdirectory
    
    for file in files:
        if file.endswith(".sv"):
            file_path = os.path.join(root, file)
            print(f"Compiling design file: {file}")
            subprocess.run(f"vlog {file_path} +acc=all", shell=True, check=True)  # Enable full signal access

# Compile shared test files
test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
for test_file in test_files:
    test_path = os.path.join(test_dir, test_file)
    if os.path.exists(test_path):
        print(f"Compiling test file: {test_file}")
        subprocess.run(f"vlog {test_path} +acc=all", shell=True, check=True)  # Enable full signal access

# Compile and run testbenches from subdirectories: simple, move, logic
test_subdirs = ["simple", "move", "logic"]
for subdir in test_subdirs:
    subdir_path = os.path.join(test_dir, subdir)
    if os.path.exists(subdir_path):
        for file in os.listdir(subdir_path):
            if file.endswith(".sv"):
                test_path = os.path.join(subdir_path, file)
                test_name = os.path.splitext(file)[0]
                log_file = os.path.join(transcript_dir, f"{test_name}.log")
                wlf_file = os.path.join(waves_dir, f"{test_name}.wlf")

                # Compile the testbench
                print(f"Compiling testbench: {file}")
                subprocess.run(f"vlog {test_path} +acc=all", shell=True, check=True)  # Enable full signal access

                # Run the simulation with full signal visibility
                print(f"Running simulation for: {test_name}")
                sim_command = f"vsim -c work.KnightsTour_tb -do 'run -all; quit;' -logfile {log_file} -wlf {wlf_file} > {log_file}"
                subprocess.run(sim_command, shell=True, check=True)

                # If needed, manually add signals to the waveform window for the simulation
                # For example, you could add only necessary signals like `cmd_proc` signals
                print(f"Adding necessary signals to the waveform for: {test_name}")
                add_wave_command = f"vsim -c work.KnightsTour_tb -do 'add wave -position insert_point {/KnightsTour_tb/cmd_proc/*}; run -all; quit;'"
                subprocess.run(add_wave_command, shell=True, check=True)

print("All tests completed.")
