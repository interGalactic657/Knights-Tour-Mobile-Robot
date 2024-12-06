import os
import subprocess
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Run specific testbench or all testbenches in GUI or command-line mode.")
parser.add_argument(
    "-n", "--number", type=int, nargs="?", default=None,
    help="Specify the testbench number to run (e.g., 1 for test_1). If not specified, runs all tests."
)
parser.add_argument(
    "-m", "--mode", type=str, choices=["gui", "cmd"], default="cmd",
    help="Specify the mode to run the simulation: 'gui' or 'cmd'. Default is 'cmd'."
)
args = parser.parse_args()

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

# Mapping test numbers to subdirectories and file ranges
test_mapping = {
    "simple": range(1, 2),  # test_1
    "move": range(2, 13),   # test_2 to test_12
    "logic": range(13, 14)  # test_13
}

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

# Helper function to find the subdirectory and filename for a test number
def find_test_info(test_number):
    for subdir, test_range in test_mapping.items():
        if test_number in test_range:
            subdir_path = os.path.join(test_dir, subdir)
            if os.path.exists(subdir_path):
                for file in os.listdir(subdir_path):
                    if file.endswith(".sv") and f"_{test_number}" in file:
                        return subdir, file
    return None, None

def find_signals(signal_names):
    """Find the full hierarchy paths for the given signal names, prioritizing user-specified signals."""
    signal_paths = []  # List to store valid signal paths
    for signal in signal_names:
        try:
            # Launch vsim in batch mode to find signals
            result = subprocess.run(
                f"vsim -c work.KnightsTour_tb -do \"find signals *{signal} -recursive; quit;\"",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            # Parse the output to extract valid signal paths
            # Split the output by space and process each part
            found_signal = False  # Flag to track if we have already added the signal
            for part in result.stdout.split():
                # Skip invalid paths or comment lines (those starting with '#')
                if part.startswith("#") or not part.strip() or part.strip() == "//":
                    continue
                if "/" in part:  # Valid signal path will contain '/'
                    # If this signal is user-specified, use that first
                    if signal in part and not found_signal:
                        signal_paths.append(part.strip())  # Add to the list
                        found_signal = True  # Mark that we've added this signal
                    elif not found_signal:
                        signal_paths.append(part.strip())  # Add the first valid signal
                        found_signal = True  # Mark that we've added this signal
        except subprocess.CalledProcessError as e:
            print(f"Error finding signal {signal}: {e.stderr}")
    
    # Return a list of valid signal paths
    return signal_paths  # This will contain only the first match for each signal

# Function to run a specific testbench
def run_testbench(subdir, test_file, mode):
    test_path = os.path.join(test_dir, subdir, test_file)
    test_name = os.path.splitext(test_file)[0]
    log_file = os.path.join(transcript_dir, f"{test_name}.log")
    wave_file = os.path.join(waves_dir, f"{test_name}.wlf")

    # Compile the testbench
    print(f"Compiling testbench: {test_file}")
    subprocess.run(f"vlog +acc {test_path}", shell=True, check=True)

    # Run the simulation
    if mode == "cmd":
        print(f"Running simulation for: {test_name} (command-line mode)")
        sim_command = (
            f"vsim -c work.KnightsTour_tb -do \""  # Command for command-line mode
            f"add wave -internal *; "  # Add only internal signals to the wave window (by default)
            f"run -all; "  # Run the simulation
            f"write wave -file {wave_file}; "  # Save waveform even for passing tests
            f"log -flush /*; "  # Log all signals
            f"quit;\" > {log_file}"
        )
        subprocess.run(sim_command, shell=True, check=True)
    else:
        print(f"Running simulation for: {test_name} (GUI mode)")
        # Ask if custom signals should be added
        use_custom_signals = input("Do you want to add custom wave signals? (yes/no): ").strip().lower()
        if use_custom_signals in ["yes", "y"]:
            signal_names = input("Enter the signal names (comma-separated, e.g., cal_done, send_resp): ").strip()
            signal_names = [name.strip() for name in signal_names.split(",") if name.strip()]
            signal_paths = find_signals(signal_names)

            # Only add the specified signals, remove the default
            add_wave_command = " ".join([f"add wave {signal};" for signal in signal_paths])
        else:
            # Add the default internal signals if no custom signals are specified
            add_wave_command = "add wave -internal *;"  # Default: Add only internal testbench signals

        # Run simulation with selected wave signals
        sim_command = (
            f"vsim -gui work.KnightsTour_tb -voptargs=\"+acc\" -do \""  # Command for GUI mode
            f"{add_wave_command} "
            f"run -all;\""
        )
        subprocess.run(sim_command, shell=True, check=True)

# Run the specified test or all tests
if args.number:
    # Run a specific test by number
    subdir, test_file = find_test_info(args.number)
    if subdir and test_file:
        run_testbench(subdir, test_file, args.mode)
    else:
        print(f"Test number {args.number} not found.")
else:
    # Run all tests
    for subdir in ["simple", "move", "logic"]:
        subdir_path = os.path.join(test_dir, subdir)
        if os.path.exists(subdir_path):
            test_files = [
                file for file in os.listdir(subdir_path)
                if file.endswith(".sv")
            ]
            for file in sorted(test_files, key=lambda x: int(''.join(filter(str.isdigit, x)))):  # Sort by number
                run_testbench(subdir, file, args.mode)

print("All tests completed.")
