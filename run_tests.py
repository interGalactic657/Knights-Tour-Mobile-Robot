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
parser.add_argument(
    "-d", "--debug", type=int, nargs="?", default=None, 
    help="Debug mode for a specific test number (e.g., -d 1 to debug test 1)."
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
    "logic": range(13, 16)  # test_13 to test_15
}

# Compile all design files (ignoring `tests/` subdirectories)
for root, dirs, files in os.walk(design_dir):
    if "tests" in dirs:
        dirs.remove("tests")  # Skip the `tests` subdirectory

    for file in files:
        if file.endswith(".sv"):
            file_path = os.path.join(root, file)
            subprocess.run(f"vlog +acc {file_path}", shell=True, check=True)

# Compile shared test files
test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
for test_file in test_files:
    test_path = os.path.join(test_dir, test_file)
    if os.path.exists(test_path):
        subprocess.run(f"vlog +acc {test_path}", shell=True, check=True)

# Function to run a specific testbench
def run_testbench(subdir, test_file, mode):
    test_path = os.path.join(test_dir, subdir, test_file)
    test_name = os.path.splitext(test_file)[0]
    log_file = os.path.join(transcript_dir, f"{test_name}.log")
    wave_file = os.path.join(waves_dir, f"{test_name}.wlf")
    wave_format_file = os.path.join(waves_dir, f"{test_name}.do")

    subprocess.run(f"vlog +acc {test_path}", shell=True, check=True)

    # Command-line mode: Run simulation, check for failure, then switch to GUI if necessary
    if mode == "cmd":
        sim_command = (
            f"vsim -c -do \"" 
            f"vsim -wlf {wave_file} work.KnightsTour_tb; add wave -internal *; run -all; log -flush /*; quit;\" > {log_file}"
        )
        subprocess.run(sim_command, shell=True, check=True)

        # Check the transcript for success or error
        with open(log_file, 'r') as f:
            content = f.read()
            if "YAHOO!! All tests passed." in content:
                print(f"{test_name}: YAHOO!! All tests passed.")
            elif "ERROR" in content:
                print(f"{test_name}: Test failed. Launching GUI for debugging...")
    else:
        # GUI mode: Ask for custom signals, or add defaults
        use_custom_signals = input("Do you want to add custom wave signals? (yes/no): ").strip().lower()
        if use_custom_signals in ["yes", "y"]:
            signal_names = input("Enter the signal names (comma-separated, e.g., cal_done, send_resp): ").strip()
            signal_names = [name.strip() for name in signal_names.split(",") if name.strip()]
            signal_paths = find_signals(signal_names)
            add_wave_command = " ".join([f"add wave {signal};" for signal in signal_paths])
        else:
            add_wave_command = "add wave -internal *;"

        subprocess.run(f"vsim -wlf {wave_file} work.KnightsTour_tb -voptargs=\"+acc\" -do \"{add_wave_command} run -all; write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; log -flush /*;\"",
                shell=True, check=True
            )

# If -d flag is passed, debug the specific test number
if args.debug is not None:
    # Change the working directory to /output/waves
    os.chdir(waves_dir)
    # Run the specific debug command for the test number
    test_number = args.debug
    debug_command = f"vsim -view KnightsTour_tb_{test_number}.wlf -do KnightsTour_tb_{test_number}.do"
    subprocess.run(debug_command, shell=True, check=True)
else:
    # Run the specified test or all tests
    if args.number:
        for subdir, test_range in test_mapping.items():
            if args.number in test_range:
                subdir_path = os.path.join(test_dir, subdir)
                test_files = [
                    file for file in os.listdir(subdir_path)
                    if file.endswith(".sv") and f"_{args.number}" in file
                ]
                for test_file in test_files:
                    run_testbench(subdir, test_file, args.mode)
                break
    else:
        for subdir in ["simple", "move", "logic"]:
            subdir_path = os.path.join(test_dir, subdir)
            if os.path.exists(subdir_path):
                test_files = [
                    file for file in os.listdir(subdir_path)
                    if file.endswith(".sv")
                ]
                for file in sorted(test_files, key=lambda x: int(''.join(filter(str.isdigit, x)))): 
                    run_testbench(subdir, file, args.mode)

        print("All tests completed.")
