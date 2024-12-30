import os
import re
import sys
import argparse
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# Constants for directory paths
ROOT_DIR = os.path.abspath(os.path.dirname(__file__))
DESIGN_DIR = os.path.join(ROOT_DIR, "designs")
TEST_DIR = os.path.join(ROOT_DIR, "tests")
POST_SYNTHESIS_DIR = os.path.join(TEST_DIR, "post_synthesis")
OUTPUT_DIR = os.path.join(ROOT_DIR, "output")
LOGS_DIR = os.path.join(OUTPUT_DIR, "logs")
TRANSCRIPT_DIR = os.path.join(LOGS_DIR, "transcript")
COMPILATION_DIR = os.path.join(LOGS_DIR, "compilation")
WAVES_DIR = os.path.join(OUTPUT_DIR, "waves")
LIBRARY_DIR = os.path.join(ROOT_DIR, "TESTS")
LIBRARY_PATH = os.path.abspath(os.path.join(POST_SYNTHESIS_DIR, 'SAED32_lib'))

# Test mapping for subdirectories and file ranges.
TEST_MAPPING = {
    "simple": range(0, 2),
    "move": range(2, 15),
    "logic": range(15, 19)
}

# By default, assume we are not compiling files yet.
design_files = None
test_paths = None

def parse_arguments():
    """Parse and validate command-line arguments.

    This function defines the arguments available for the script,
    validates them, and provides a help message for the user.

    Returns:
        argparse.Namespace: Parsed arguments from the command line.
    """
    parser = argparse.ArgumentParser(description="Run testbenches in various modes.")

    # Argument for specifying the testbench number (optional, can be None)
    parser.add_argument("-n", "--number", type=int, nargs="?", default=None,
                        help="Specify the testbench number to run (e.g., 1 for test_1). If not provided, the script will run all available tests.")
    
    # Argument for specifying a range of tests to run (inclusive)
    parser.add_argument("-r", "--range", type=int, nargs=2, metavar=("START", "END"),
                        help="Test range to run (inclusive, e.g., -r 2 10).")
    
    # Argument for specifying the debugging mode
    parser.add_argument("-m", "--mode", type=int, choices=[0, 1, 2, 3], default=0,
                        help="Debugging mode: 0=Command-line, 1=Save waves, 2=GUI, 3=View saved waves.")
    
    # Argument for specifying custom signals for waveform
    parser.add_argument("-s", "--signals", type=str, nargs="*", default=None,
                        help="Custom signals for waveform (default signals will be used if not specified).")
    
    # Parse the arguments from the command line
    args = parser.parse_args()

    return args

def setup_directories():
    """Ensure necessary directories exist for logs, compilation, waves, etc.

    This function creates all required directories (logs, transcripts, compilation,
    waveform output, and the library). If the directories already exist, they are
    not recreated. Also, creates test directories (TEST_0 through TEST_18).

    Raises:
        OSError: If a directory cannot be created.
    """
    # Paths for all required directories (using pathlib for better cross-platform compatibility)
    directories = [Path(LOGS_DIR), Path(TRANSCRIPT_DIR), Path(COMPILATION_DIR), Path(WAVES_DIR), Path(LIBRARY_DIR)]

    # Ensure all required directories exist
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)

    # Create subdirectories for each test (TEST_0 through TEST_18) under the LIBRARY_DIR
    for i in range(19):  # TEST_0 through TEST_18
        (Path(LIBRARY_DIR) / f"TEST_{i}").mkdir(exist_ok=True)

    # Optionally change back to the root directory if needed
    os.chdir(ROOT_DIR)

def find_signals(signal_names, test_num):
    """Find full hierarchy paths for the given signal names in the simulation.

    Args:
        signal_names (list of str): List of signal names to find.
        test_num (int): The test number (used to identify the test for signal searching).

    Returns:
        list of str: List of full signal hierarchy paths found in the simulation.
    """
    signal_paths = []

    # Iterate through the provided signal names
    for signal in signal_names:
        if "/" in signal:
            # If the signal already contains a path, append it directly
            signal_paths.append(signal)
        else:
            try:
                # Run the 'vsim' command to find signals in the given test
                result = subprocess.run(
                    f"vsim -c TEST_{test_num}.KnightsTour_tb -do \"find signals /KnightsTour_tb/{signal}* -recursive; quit -f;\"",
                    shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                )

                # Parse the output to find signals that match the requested signal name
                found_signal = False
                for part in result.stdout.split():
                    # Ignore irrelevant parts or lines
                    if part.startswith("#") or not part.strip():
                        continue
                    if "/" in part and part.strip().split("/")[-1] == signal and not found_signal:
                        signal_paths.append(part.strip())
                        found_signal = True

            except subprocess.CalledProcessError as e:
                print(f"Error finding signal '{signal}' in test {test_num}: {e.stderr}")
    
    return signal_paths

def check_compilation(log_file):
    """Check the compilation log for errors or warnings.

    Args:
        log_file (str): Path to the compilation log file.

    Returns:
        str: Returns "error" if any errors are found, "warning" if warnings are present, or "success" if no issues are found.
    """
    # Open and read the content of the log file
    with open(log_file, "r") as file:
        content = file.read()

        # Check for the presence of "Error:" or "Warning:"
        if "Error:" in content:
            return "error"
        elif "Warning:" in content:
            return "warning"
        else:
            return "success"

def check_transcript(log_file):
    """Check the simulation transcript for success or failure.

    Args:
        log_file (str): Path to the simulation transcript log file.

    Returns:
        str: Returns "success" if the test passed, "error" if there was an error, or "unknown" if the status is not determined.
    """
    # Open and read the content of the transcript log file
    with open(log_file, "r") as file:
        content = file.read()

        # Check for specific success or failure strings in the transcript
        if "YAHOO!! All tests passed." in content:
            return "success"
        elif "ERROR" in content:
            return "error"
    
    # If no status is found, return unknown
    return "unknown"

def check_logs(logfile, mode):
    """Check the status of a log file based on the specified mode.

    Args:
        logfile (str): Path to the log file.
        mode (str): Mode of checking, either "t" for transcript or "c" for compilation.

    Returns:
        str: The result of the log check, either "success", "error", or "unknown".
    """
    # Direct to the appropriate check function based on the mode
    if mode == "t":
        return check_transcript(logfile)
    elif mode == "c":
        return check_compilation(logfile)

def collect_files():
    """Collect the design and testbench files for the simulation.

    Returns:
        tuple: A tuple containing two lists:
            - List of design files (.sv files)
            - List of testbench file paths (.sv files)
    
    Raises:
        FileNotFoundError: If no design files or testbench files are found.
    """
    # Collect all design files from the design directory, skipping the 'tests' directory
    design_files = []
    for root, dirs, files in os.walk(DESIGN_DIR):
        if "tests" in dirs:
            dirs.remove("tests")  # Exclude the 'tests' subdirectory
        for file in files:
            if file.endswith(".sv"):
                design_files.append(os.path.join(root, file))

    if not design_files:
        raise FileNotFoundError("No design files found in the design directory.")

    # Specify the required testbench files
    test_files = ["tb_tasks.sv", "KnightPhysics.sv", "SPI_iNEMO4.sv"]
    test_paths = [
        os.path.join(TEST_DIR, file)
        for file in test_files if os.path.exists(os.path.join(TEST_DIR, file))
    ]
    if not test_paths:
        raise FileNotFoundError("No testbench files found in the test directory.")

    return design_files, test_paths

def compile_files(test_num, test_path):
    """Compile the required files for the test simulation.

    Args:
        test_num (int): The test number to identify the test for compilation.
        test_path (str): The path to the test file to be compiled.

    Raises:
        SystemExit: If compilation fails, the program exits with an error.
    """
    global design_files, test_paths

    # Define the path for the compilation log
    log_file = os.path.join(COMPILATION_DIR, f"compilation_{test_num}.log")

    # Determine the files to compile based on the test number
    if test_num != 0:
        all_files = " ".join(design_files + test_paths) + " " + "".join(test_path)
    else:
        all_files = f"../tests/post_synthesis/*.sv ../tests/post_synthesis/*.vg {test_path}"

    # Attempt to compile the files
    with open(log_file, 'w') as log_fh:
        try:
            compile_command = f"vsim -c -logfile {log_file} -do 'vlog -work TEST_{test_num} -vopt -stats=none {all_files}; quit -f;'"
            subprocess.run(compile_command, shell=True, stdout=log_fh, stderr=subprocess.STDOUT, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Compilation failed. Check the log file for details: {log_file}")
            sys.exit(1)  # Exit the program if compilation fails
            raise e

    # Check if the compilation was successful or not
    result = check_logs(log_file, "c")

    # Provide feedback on the compilation result
    if result == "warning":
        print(f"Compilation has warnings for {test_path}. Check the log file for details: {log_file}")
    elif result == "error":
        print(f"Compilation failed for {test_path}. Check the log file for details: {log_file}")
        sys.exit(1)  # Exit the program if there is a compilation error

def get_wave_command(args, test_num):
    """Generate the command for waveform signals based on the test number.

    Args:
        args (argparse.Namespace): Parsed arguments from the command line.
        test_num (int): The test number to determine the required signals.

    Returns:
        str: A string containing the waveform command for the selected signals.
    """
    # Define default signals based on the test number
    default_signals = []

    if test_num == 0:
        default_signals = ["iDUT/clk", "iDUT/RST_n", "iDUT/TX", "iDUT/RX", "iRMT/resp", "iRMT/resp_rdy"]
    elif test_num == 1:
        default_signals = ["iDUT/clk", "iDUT/RST_n", "iDUT/cal_done", "NEMO_setup", "send_resp", "iRMT/resp", "iRMT/resp_rdy"]
    else:
        if 2 <= test_num <= 14:
            default_signals = [
                "clk", "RST_n", "iPHYS/xx", "iPHYS/yy", "heading", "heading_robot", "desired_heading", "omega_sum",
                "iPHYS/cntrIR_n", "iDUT/iCMD/lftIR", "iDUT/iCMD/cntrIR", "iDUT/iCMD/rghtIR", "error_abs", 
                "iDUT/iCMD/square_cnt", "iDUT/iCMD/move_done", "iDUT/iTC/state", "send_resp", "resp", 
                "/KnightsTour_tb/resp_rdy", "mv_indx", "move", "iDUT/iCMD/pulse_cnt", "iDUT/iCMD/state"
            ]
        elif 15 <= test_num <= 18:
            default_signals = [
                "clk", "RST_n", "iPHYS/xx", "iPHYS/yy", "heading", "heading_robot", "desired_heading", "omega_sum",
                "iPHYS/cntrIR_n", "iDUT/iCMD/lftIR", "iDUT/iCMD/cntrIR", "iDUT/iCMD/rghtIR", "error_abs", 
                "iDUT/iCMD/square_cnt", "iDUT/iCMD/move_done", "iDUT/iTC/state", "send_resp", "resp", 
                "/KnightsTour_tb/resp_rdy", "mv_indx", "move", "iDUT/iCMD/pulse_cnt", "iDUT/iCMD/state", 
                "iDUT/iCMD/tour_go", "fanfare_go", "iDUT/ISPNG/state"
            ]

    # Determine the signals to use based on command-line arguments or defaults
    signals_to_use = args.signals or default_signals

    # Find and return the signals to be used in the waveform command
    signal_paths = find_signals(signals_to_use, test_num)
    return " ".join([f"add wave {signal};" for signal in signal_paths])

def run_simulation(test_num, test_name, log_file, wave_file, wave_format_file, args):
    """Run the simulation based on the selected mode.

    Args:
        test_num (int): The test number to identify the specific test.
        test_name (str): The name of the test (used for logging and messages).
        log_file (str): Path to the log file where simulation output will be saved.
        wave_file (str): Path to the waveform file where simulation waveforms will be saved.
        wave_format_file (str): Path to the file where waveform format will be written.
        args (argparse.Namespace): Parsed command-line arguments, including mode and test-specific settings.

    Returns:
        str: The result of the simulation, typically "success", "error", or "unknown".
    """
    # Precompute the simulation command based on the mode
    if args.mode == 0:
        if args.number is not None and args.range is None:
            print(f"{test_name}: Running in command-line mode...")

        sim_command = get_cli_command(test_num, log_file)
    else:
        if args.mode == 1: # Save waveforms and log in file
            if args.number is not None and args.range is None:
                print(f"{test_name}: Saving waveforms and logging to file...")
        elif args.mode == 2: # GUI mode
            if args.number is not None and args.range is None:
                print(f"{test_name}: Running in GUI mode...")

        sim_command = get_gui_command(test_num, log_file, wave_file, wave_format_file, args)

    # Execute the simulation command and log the output
    with open(log_file, 'w') as log_fh:
        subprocess.run(sim_command, shell=True, stdout=log_fh, stderr=subprocess.STDOUT, check=True)

    # Check simulation result and return status
    return check_logs(log_file, "t")

def get_cli_command(test_num, log_file):
    """Generate the simulation command for mode 0 (command-line mode).

    Args:
        test_num (int): The test number to identify the specific test.
        log_file (str): Path to the log file where simulation output will be saved.

    Returns:
        str: The complete simulation command string for mode 0.
    """

    # Base simulation command.
    base_command = f"vsim -c TEST_{test_num}.KnightsTour_tb -logfile {log_file} -do 'run -all; log -flush /*; quit -f;'"
    
    # Modify the command for test 0.
    if test_num == 0:
        base_command = f"vsim -c TEST_0.KnightsTour_tb -logfile {log_file} -t ns " \
                   f"-L {LIBRARY_PATH} -Lf {LIBRARY_PATH} -voptargs=+acc -do 'run -all; log -flush /*; quit -f;'"
    
    return base_command

def get_gui_command(test_num, log_file, wave_file, wave_format_file, args):
    """Generate the simulation command for GUI-based waveform viewing.

    Args:
        test_num (int): The test number to identify the specific test.
        log_file (str): Path to the log file where simulation output will be saved.
        wave_file (str): Path to the waveform file where simulation waveforms will be saved.
        wave_format_file (str): Path to the file where waveform format will be written.
        args (argparse.Namespace): Parsed command-line arguments, including mode and test-specific settings.

    Returns:
        str: The complete simulation command string to execute for GUI mode.
    """
    # Generate waveform command based on the test arguments
    add_wave_command = get_wave_command(args, test_num)

    # Construct the simulation command with necessary flags for waveform generation
    if test_num == 0:
        sim_command = f"vsim -wlf {wave_file} TEST_{test_num}.KnightsTour_tb -logfile {log_file} -t ns " \
                      f"-L {LIBRARY_PATH} -Lf {LIBRARY_PATH} -voptargs=+acc -do '{add_wave_command}; run -all; " \
                      f"write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; " \
                      f"log -flush /*;'"
    else:
        sim_command = (
            f"vsim -wlf {wave_file} TEST_{test_num}.KnightsTour_tb -voptargs=+acc -logfile {log_file} -do '{add_wave_command} run -all; "
            f"write format wave -window .main_pane.wave.interior.cs.body.pw.wf {wave_format_file}; log -flush /*;'"
        )

    # Adjust for mode 0 or 1 to ensure the simulation quits after completion
    if args.mode == 0 or args.mode == 1:
        sim_command = sim_command[:-1] + " quit -f;'"

    return sim_command

def run_test(subdir, test_file, args):
    """Run a specific testbench by compiling and executing the simulation.

    Args:
        subdir (str): The subdirectory where the test file is located.
        test_file (str): The test file to be compiled and executed.
        args (argparse.Namespace): Parsed command-line arguments, including mode and test-specific settings.

    Returns:
        None: This function prints status messages based on the test result.
    """
    # Determine the full path to the test file
    test_path = os.path.join(TEST_DIR, subdir, test_file)
    test_name = os.path.splitext(test_file)[0]
    log_file = os.path.join(LOGS_DIR, f"{test_name}.log")
    wave_file = os.path.join(WAVES_DIR, f"{test_name}.wlf")
    wave_format_file = os.path.join(WAVES_DIR, f"{test_name}.do")
    os.chdir(LIBRARY_DIR)

    # Extract the test number from the test name (if it exists)
    test_num = int(re.search(r'\d+', test_name).group()) if re.search(r'\d+', test_name) else None

    # Step 1: Compile the testbench
    compile_files(test_num, test_path)

    # Step 2: Run the simulation and handle different modes
    result = run_simulation(test_num, test_name, log_file, wave_file, wave_format_file, args)
    
    # Output the result of the test based on the simulation result
    if result == "success":
        print(f"{test_name}: YAHOO!! All tests passed.")
    elif result == "error":
        handle_error(test_name, test_num, log_file, args)
    elif result == "unknown":
        print(f"{test_name}: Unknown status. Check the log file saved to {log_file}.")

def handle_error(test_name, test_num, log_file, args):
    """Handle simulation errors based on the mode.

    Args:
        test_name (str): The name of the test (used for logging and messages).
        test_num (int): The test number to identify the specific test.
        log_file (str): Path to the log file where simulation output will be saved.
        args (argparse.Namespace): Parsed command-line arguments, including mode and test-specific settings.
    
    Returns:
        None: This function manages error handling depending on the selected mode.
    """
    if args.mode == 0:
        print(f"{test_name}: Test failed. Saving waveforms for later debug...")
        debug_command = get_gui_command(test_num, log_file, log_file, log_file, args)
        with open(log_file, 'w') as log_fh:
            subprocess.run(debug_command, shell=True, stdout=log_fh, stderr=subprocess.STDOUT, check=True)
    elif args.mode == 1:
        print(f"{test_name}: Test failed. Debug logs saved to {log_file}.")

def view_waveforms(test_number):
    """View previously saved waveforms for a specific test.

    Args:
        test_number (int): The test number to view waveforms for.

    Returns:
        None: This function executes the simulation command to view waveforms.
    """
    # Change to the wave directory and view the saved waveforms
    with open("./transcript", 'w') as transcript:
        os.chdir(WAVES_DIR)
        print(f"KnightsTour_tb_{test_number}: Viewing saved waveforms...")
        sim_command = f"vsim -view KnightsTour_tb_{test_number}.wlf -do KnightsTour_tb_{test_number}.do;"
        subprocess.run(sim_command, shell=True, stdout=transcript, stderr=subprocess.STDOUT, check=True)

def execute_tests(args):
    """Execute tests based on parsed arguments.

    This function handles the execution of tests based on the provided arguments. 
    It can run a specific test, a range of tests, or all tests, and supports different 
    modes for running tests (command-line, saving, or GUI mode). It also manages 
    parallel execution of tests and waveform viewing.

    Args:
        args (argparse.Namespace): Parsed command-line arguments.
    """
    global design_files, test_paths

    def get_tests_in_range(start, end):
        """Collect test files for a given range of tests.

        Args:
            start (int): The starting test number.
            end (int): The ending test number.

        Returns:
            list: A list of tuples containing the subdirectory and test file for each test in the range.
        """
        return [
            (subdir, f"KnightsTour_tb_{i}.sv")
            for subdir, test_range in TEST_MAPPING.items()
            for i in test_range if start <= i <= end
        ]

    def collect_all_tests():
        """Collect all available test files.

        This function collects all test files that match the naming convention 
        'KnightsTour_tb_*.sv' from all subdirectories in the test directory.

        Returns:
            list: A list of tuples containing the subdirectory and test file for all available tests.
        """
        return [
            (subdir, test_file)
            for subdir in TEST_MAPPING.keys()
            for test_file in os.listdir(os.path.join(TEST_DIR, subdir))
            if test_file.startswith("KnightsTour_tb")
        ]

    def run_parallel_tests(tests):
        """Run multiple tests in parallel using threads.

        Args:
            tests (list): A list of tuples containing the subdirectory and test file to run.

        This function uses a ThreadPoolExecutor to run tests concurrently, improving the speed of I/O-bound operations.
        """
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(run_test, subdir, test_file, args) for subdir, test_file in tests]
            for future in futures:
                try:
                    future.result()  # Will raise an exception if any occurred
                except Exception as e:
                    print(f"Test failed with error: {e}")

    def view_parallel_waves(test_numbers):
        """View waveforms for multiple tests in parallel using threads.

        Args:
            test_numbers (list): A list of test numbers for which to view the waveforms.

        This function uses a ThreadPoolExecutor to view waveforms concurrently, improving the speed of I/O-bound operations.
        """
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(view_waveforms, i) for i in test_numbers]
            for future in futures:
                try:
                    future.result()  # Will raise an exception if any occurred
                except Exception as e:
                    print(f"Waveform view failed with error: {e}")

    def run_specific_test(test_num):
        """Run a specific test by its number.

        Args:
            test_num (int): The test number to run.

        This function looks up the test based on the test number and runs it if found.
        If the test is not found, it prints an error message.
        """
        test = get_tests_in_range(test_num, test_num)
        if test:
            run_test(test[0][0], test[0][1], args)
        else:
            print(f"Test {test_num} not found.")

    def handle_mode_3(test_range=None):
        """Handle waveform viewing in mode 3.

        Args:
            test_range (list, optional): A list of test numbers to view waveforms for. If None, all tests are shown.

        This function is responsible for viewing waveforms for tests in parallel. If a range is provided, it views 
        waveforms for the specified tests; otherwise, it views waveforms for all tests.
        """
        if test_range:
            view_parallel_waves(test_range)
        else:
            all_tests = [i for subdir, test_range in TEST_MAPPING.items() for i in test_range]
            view_parallel_waves(all_tests)

    # Handle different cases based on parsed arguments
    if args.number is not None:
        # If a specific test number is provided, run that test
        if args.number != 0:
            try:
                design_files, test_paths = collect_files()
            except FileNotFoundError as e:
                print(f"Error during file collection: {e}")
                sys.exit(1)

        if args.mode == 3:
            # Mode 3: View waveforms for the specific test
            handle_mode_3([args.number])
        else:
            # Run the specific test
            run_specific_test(args.number)

    elif args.range is not None:
        # If a range of tests is provided, run all tests in that range
        start, end = args.range
        try:
            design_files, test_paths = collect_files() if start != 0 or end != 0 else ([], [])
        except FileNotFoundError as e:
            print(f"Error during file collection: {e}")
            sys.exit(1)

        if args.mode == 3:
            # Mode 3: View waveforms for the test range
            handle_mode_3(list(range(start, end + 1)))
        else:
            # Print a message based on the selected mode and range
            mode_messages = {
                0: f"Running all tests from {start} to {end} in command-line mode...",
                1: f"Running all tests from {start} to {end} in saving mode...",
                2: f"Running all tests from {start} to {end} in GUI mode..."
            }
            print(mode_messages.get(args.mode, "Running tests..."))

            # Collect and run the tests in the specified range
            tests = get_tests_in_range(start, end)
            run_parallel_tests(tests)

    else:
        # If no specific test or range is provided, run all tests
        if args.mode == 3:
            handle_mode_3()
        else:
            mode_messages = {
                0: "Running all tests in command-line mode...",
                1: "Running all tests in saving mode...",
                2: "Running all tests in GUI mode..."
            }
            print(mode_messages.get(args.mode, "Running tests..."))

            try:
                design_files, test_paths = collect_files()
            except FileNotFoundError as e:
                print(f"Error during file collection: {e}")
                sys.exit(1)

            # Collect and run all tests
            tests = collect_all_tests()
            run_parallel_tests(tests)

def main():
    """Main function to parse arguments, set up directories, and execute tests.

    This function is the entry point for the test execution process. It performs the following tasks:
    - Parses the command-line arguments using `parse_arguments`.
    - Ensures necessary directories exist using `setup_directories`.
    - Executes the tests based on the parsed arguments using `execute_tests`.
    - Prints a completion message once all tests are finished.

    Args:
        None
    """
    # Parse the command-line arguments
    args = parse_arguments()

    # Set up necessary directories for test execution (logs, transcripts, etc.)
    setup_directories()

    # Execute the tests based on the parsed arguments
    execute_tests(args)

    # Print completion message after all tests are done
    print("All tests completed.")

if __name__ == "__main__":
    main()
