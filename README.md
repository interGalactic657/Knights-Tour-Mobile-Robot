# **KnightsTour Project**

## **Overview**

The **KnightsTour** project is a SystemVerilog-based design intended for solving the KnightsTour problem, where a knight robot moves around a chessboard visiting all squares exactly once. This project includes testbenches (`KnightsTour_tb`) to verify the design, as well as Python-based scripts for simulation control, waveform viewing, log collection, and file management. The design can be synthesized to a DEO-Nano (Altera Cyclone-IV) FPGA for a real-life demo of the KnightsTour.

The project uses a Makefile to automate the testing, logging, and file management processes. This README provides an overview of the project's structure, setup, and usage.

---

## **Project Structure**

```text
/Knights-Tour-Mobile-Robot
├── code_coverage/             # Directory containing reports of old and new code coverage analysis
│   ├── code_coverage_new/     # Directory containing reports of improved code coverage analysis
│   └── code_coverage_old/     # Directory containing reports of old code coverage analysis
├── designs/                   # Directory containing pre/post synthesis and Quartus design files
│   ├── pre_synthesis/         # Directory containing pre-synthesis design files
│   ├── post_synthesis/        # Directory containing the post-synthesis .vg file
│   └── quartus/               # Directory containing Quartus design files
├── scripts/                   # Directory containing scripts for automating testing/synthesis/post-synthesis tasks
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
   git clone https://github.com/InterGalactic657/Knights-Tour-Mobile-Robot
   cd Knights-Tour-Mobile-Robot/
   ```

2. Ensure that Python 3 and Make are installed on your system:
   - Python 3: [Installation Guide](https://www.python.org/downloads/)
   - Make: [Installation Guide](https://www.gnu.org/software/make/)

3. Install required Python dependencies (if any):
   ```bash
   pip install <dependencies>
   ```

---

# **Makefile for Synthesis, Simulation, Logs, and File Collection**

This Makefile is designed to streamline the process of managing synthesis, running simulations, viewing logs, and collecting design/test files. Below are the available targets and their respective usage instructions.

---

## **Table of Contents**
1. [Synthesis](#synthesis)
2. [Run Simulations](#run-simulations)
3. [View Logs](#view-logs)
4. [Collect Files](#collect-files)
5. [Clean Directory](#clean-directory)

---

## **Synthesis**
Generates a synthesized Verilog netlist and timing constraints using Synopsys Design Compiler.

### Usage:
```bash
make synthesis
```
### Description:
- Synthesizes the design to a Synopsys 32-nm Cell Library.
- Generates: a compilation log file, min/max delay reports, an area report, a `.vg` file (netlist), and a `.sdc` file (timing constraints).
- Automatically runs only if source files or the synthesis script have been updated.

### Output Files:
- `synth_compilation.log` (Synthesis Compilation Log)
- `KnightsTour_min_delay.txt` (Min Delay Report)
- `KnightsTour_max_delay.txt` (Max Delay Report)
- `KnightsTour_area.txt` (Area Report)
- `KnightsTour.vg` (Netlist)
- `KnightsTour.sdc` (Timing Constraints)

---

## **Run Simulations**
Executes test cases in different modes (CMD, GUI, save waveforms).

### Usage:
```bash
make run
make run <test_type> <mode> <args>
```
### Test Types:
- `a` - All tests
- `m` - Main tests
- `e` - Extra tests

### Modes:
- `v` - View waveforms in GUI mode
- `g` - Run in GUI mode
- `s` - Save waveforms
- `c` - Run in CMD mode

### Args:
- `<test_number>` - A specific test to run
- `<test_range>` - A range of tests to run

### Examples:
1. Run all tests in CMD mode:
   ```bash
   make run
   ```
2. Run all main tests and save waveforms:
   ```bash
   make run m s
   ```
3. Run a specific test in GUI mode:
   ```bash
   make run m g 1
   ```
4. Run a range of extra tests in CMD mode:
   ```bash
   make run e c 1 5
   ```

---

## **View Logs**
Displays logs for synthesis, compilation, or test transcripts.

### Usage:
```bash
make log <type> <sub_type> <args>
```
### Log Types:
1. **Synthesis Reports (`s`)**
   - `a`: Area report
   - `n`: Min delay report
   - `x`: Max delay report
   - Example:
      ```bash
      make log s a
      ```
2. **Compilation Logs (`c`)**
   - `s`: Synthesis compilation log
   - `m <number>`: Main test compilation log
   - `e <number>`: Extra test compilation log
   - Example:
      ```bash
      make log c m 1
      ```
3. **Test Transcripts (`t`)**
   - `m <number>`: Main test transcript
   - `e <number>`: Extra test transcript
   - Example:
      ```bash
      make log t m 1
      ```

---

## **Collect Files**
Collects design or test files into a target directory.

### Usage:
```bash
make collect <type> <start_number> <end_number>
make collect <type>
```
### Arguments:
- `<type>`: `m` (main) or `e` (extra)
- `<start_number>` and `<end_number>`: Range of test numbers to collect.

### Examples:
1. Collect test files for tests 1-5 in the main directory:
   ```bash
   make collect m 1 5
   ```
2. Collect all design files for the extra directory:
   ```bash
   make collect e
   ```

---

## **Clean Directory**
Removes generated files to clean up the workspace.

### Usage:
```bash
make clean
```

---

## **Notes**
- Ensure you have all required dependencies installed (e.g., Synopsys tools, Python).
- For troubleshooting or additional details, refer to individual target sections.

---

## **Acknowledgments**
Special thanks to contributors and open-source tools that made this project possible.
