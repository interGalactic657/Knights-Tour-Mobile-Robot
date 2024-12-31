
# **KnightsTour Project**

## **Overview**

The **KnightsTour** project is a Verilog-based design intended for the KnightsTour problem, where a knight robot moves around a chessboard visiting all squares exactly once. This project includes testbenches (`KnightsTour_tb`) to verify the design, as well as Python-based scripts for simulation control, waveform viewing, log collection, and file management. The design can be synthesized to an Alterra Cyclone-IV FPGA for real-life simulation.

The project uses a Makefile to automate the testing, logging, and file management processes. This README provides an overview of the project's structure, setup, and usage.

---

## **Project Structure**

```text
/Knights-Tour-Mobile-Robot
├── code_coverage/             # Directory containing reports of old and new code coverage analysis
│   ├── code_coverage_new      # Directory containing reports of improved code coverage analysis 
│   ├── code_coverage_old/     # Directory containing reports of old code coverage analysis
├── designs/                   # Directory containing pre/post synthesis and quartus design files 
│   ├── pre_synthesis/         # Directory containing pre-synthesis design files 
│   ├── post_synthesis/        # Directory containing the post-synthesis .vg file 
│   └── quartus/               # Directory containing quartus design files
├── scripts/                   # Directory containing scripts for automating testing/synthesis/post_synthesis tasks 
├── tests/                     # Directory containing simulation test files
├── Makefile                   # Makefile for automating tasks
```
---

## **Dependencies**

- **Python 3.x**: Required to run the `run_tests.py` script.
- **Make**: For running the Makefile commands.
- **Verilog Simulator**: E.g., ModelSim, XSIM, or any simulator capable of running Verilog tests.

---

## **Installation**

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/Prathmesh-K/Knights-Tour-Mobile-Robot
   cd Knights-Tour-Mobile-Robot/
   ```

2. Ensure that Python 3 and Make are installed on your system:
   - Python 3: [Installation Guide](https://www.python.org/downloads/)
   - Make: [Installation Guide](https://www.gnu.org/software/make/)

3. Install required Python dependencies (if any):
   ```bash
   pip install -r requirements.txt
   ```

---

## **Usage**

### **Makefile Targets**

The **Makefile** provides multiple targets for synthesis, running simulations, viewing logs, collecting design/test files, and cleaning up.

### **Synthesis Target**
The synthesis target synthesizes the design using the Synopsys 32-nm Cell Library via the Design Compiler.

#### Example:
```bash
make synthesis
```
This command will create a synthesis directory and compile the design files, logging the results in ./output/logs/compilation/.

### **Run Target**

The `run` target executes the testbench simulations with various modes:
- **Command-line mode (default)**: Runs the tests in the terminal without GUI.
- **Saving waveform mode**: Saves waveform data.
- **GUI mode**: Runs tests and views waveforms in a graphical interface.

#### Example:
```bash
make run v 1        # View waveforms for test 1 in GUI mode
make run g 2        # Run test 2 in GUI mode
make run s 3        # Save waveforms for test 3
make run 1 5        # Run tests 1 to 5 in command-line mode
make run            # Run all tests in command line mode
```

### **Log Target**

The `log` target displays specific logs:
- **Synthesis logs**: Displays area or min/max delay reports post-synthesis.
- **Compilation logs**: Displays logs for compilation of tests.
- **Transcript logs**: Displays simulation results for the specified test.

#### Example:
```bash
make log s a        # Display the area report post synthesis
make log s n        # Display the min delay report post synthesis
make log s x        # Display the max delay report post synthesis
make log c s        # Display the compilation log for synthesis
make log c 3        # Display the compilation log for test 3
make log t 3        # Display the transcript log for test 3
```

### **Collect Target**

The `collect` target gathers design or test files:
- **`collect`**: Collects all design files.
- **`collect <start> <end>`**: Collects files for tests in the specified range.
- 
#### Example:
```bash
make collect 1 10    # Collect files for tests 1 to 10
make collect         # Collect all design files
```

### **Clean Target**

The `clean` target deletes generated directories and files from previous runs:

```bash
make clean                  # Clean up generated files (logs, waves, etc.)
```

---

## **Error Handling**

- If the `run` or `log` targets are provided with invalid arguments, the Makefile will output an error message with usage instructions.
- The `collect` target will give an error if it does not receive valid arguments.
- The `clean` target will remove all generated files and directories, so use it cautiously.

---

## **Acknowledgments**
- Special thanks to contributors and open-source tools that made this project possible.
