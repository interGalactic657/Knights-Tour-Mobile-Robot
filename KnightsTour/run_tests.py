import os
import subprocess

# Directories
root_dir = os.path.abspath(os.path.dirname(__file__))  # Top-level directory (current directory)
design_dir = os.path.join(root_dir, "designs")  # Design files directory
test_dir = os.path.join(root_dir, "tests")  # Test files directory
output_dir = os.path.join(root_dir, "output")  # Output directory for logs and results
transcript_dir = os.path.join(output_dir, "transcript")  # Subdirectory for log files
waves_dir = os.path.join(output_dir, "waves")  # Subdirectory for waveform files
library_dir = os.path.join(root_dir, "work")  # Simulation library directory

# Ensure output and library directories exist
os.makedirs(transcript_dir, exist_ok=True)
os.makedirs(waves_dir, exist_ok=True)
os.makedirs(library_dir, exist_ok=True)

# Compile all design files (ignoring `tests/` subdirectories)
for root, dirs, files in os.walk(design_dir):
    if "tests" in dirs:
        dirs.remove("tests")  # Skip the `tests` subdirectory

    for file in files:
        if file.endswith(".sv"):
            file_path = os.path.join(root, file)
            print(f"Compiling design file: {file}")
            subprocess.run(f"vlog +acc {file_path}", shell=True, check=True)

# Compile shared test files
test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
for test_file in test_files:
    test_path = os.path.join(test_dir, test_file)
    if os.path.exists(test_path):
        print(f"Compiling test file: {test_file}")
        subprocess.run(f"vlog +acc {test_path}", shell=True, check=True)

# Map subdirectories to their test ranges
test_mapping = {
    "simple": range(1, 2),  # Only test_1
    "move": range(2, 13),   # test_2 to test_12
    "logic": range(13, 14)  # Only test_13
}

# Helper function to extract the test number from filenames
def extract_numeric_key(filename):
    """Extracts numeric part of a filename for sorting."""
    name, _ = os.path.splitext(filename)  # Split filename and extension
    return int(''.join(filter(str.isdigit, name)))  # Extract and convert numeric part to int

# Check transcript for pass or error
def check_transcript(log_file):
    """Check if the transcript contains success or error messages."""
    with open(log_file, 'r') as f:
        content = f.read()
        if "YAHOO!! All tests passed." in content:
            return "success"
        elif "ERROR" in content:
            return "error"
    return "unknown"

# Compile and run testbenches in the correct order
for subdir, test_range in test_mapping.items():
    subdir_path = os.path.join(test_dir, subdir)
    if os.path.exists(subdir_path):
        # Filter and sort files in this subdirectory
        test_files = [
            file for file in os.listdir(subdir_path)
            if file.endswith(".sv") and extract_numeric_key(file) in test_range
        ]
        for file in sorted(test_files, key=extract_numeric_key):
            test_path = os.path.join(subdir_path, file)
            test_name = os.path.splitext(file)[0]
            log_file = os.path.join(transcript_dir, f"{test_name}.log")
            wave_file = os.path.join(waves_dir, f"{test_name}.wlf")

            # Compile the testbench
            print(f"Compiling testbench: {file}")
            subprocess.run(f"vlog +acc {test_path}", shell=True, check=True)

            # Run the simulation in command-line mode
            print(f"Running simulation for: {test_name}")
            sim_command = (
                f"vsim -c work.KnightsTour_tb -do \""
                f"add wave -internal *; "  # Add only internal signals to the wave window
                f"run -all; "  # Run the simulation
                f"write wave -file {wave_file}; "  # Save waveform even for passing tests
                f"quit;\" > {log_file}"
            )
            subprocess.run(sim_command, shell=True, check=True)

            # Check the transcript for success or error
            result = check_transcript(log_file)
            if result == "success":
                print(f"{test_name}: Test passed!")
            elif result == "error":
                print(f"{test_name}: Test failed. Launching ModelSim GUI...")
                # Launch ModelSim GUI with +acc for visibility of all signals
                subprocess.run(
                    f"vsim -gui work.KnightsTour_tb -voptargs=\"+acc\" -do \""
                    f"add wave -internal *; "  # Add only internal testbench signals
                    f"run -all;\"", shell=True, check=True
                )
            else:
                print(f"{test_name}: Test status unknown. Check log file: {log_file}")

print("All tests completed.")
