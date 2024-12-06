////////////////////////////////////////////////////
// sponge_tb.sv                                  //
// This testbench simulates the operation of    //
// generating piezo bender waveforms for the   //
// SpongeBob last measure theme song once the //
// Knight moved in an L shape.               //
//////////////////////////////////////////////
module sponge_tb();

  logic clk; // Clock signal.
  logic rst_n; // Active-low reset signal.
  logic go; // Signal to initiate system action (e.g., generating waveforms).
  logic piezo; // Piezoelectric bender output signal.
  logic piezo_n; // Inverted piezoelectric bender signal.

  //////////////////////////////////////////
  // Instantiate the sponge module (DUT) //
  ////////////////////////////////////////
  sponge iSPONGE(.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));

  // Testbench sequence to simulate system initialization and signal behavior.
  initial begin
    // Initialize signal values to ensure proper system startup.
    clk = 1'b0; // Initialize clock to low state.
    go = 1'b0;  // Initially, we are not asserting the fanfare.
    rst_n = 1'b0; // Assert reset to initialize the system in a safe state.
    
    // Wait for one clock cycle to ensure stability before further changes.
    @(posedge clk);
    
    // Deassert reset to begin normal system operation.
    // Assert the 'go' signal to trigger the system's action.
    @(negedge clk) begin
      rst_n = 1'b1; // Deassert reset to activate the system.
      go = 1'b1; // Signal the system to start the operation (e.g., waveform generation).
    end

    // Deassert go after one clock cycle.
    @(negedge clk) go = 1'b0;

    // Allow a couple of clock cycles for the system to generate waveforms and view the results.
    repeat(100000000) @(posedge clk); // Wait for 10000000 clock cycles to observe the output waveforms.
    $stop();
  end

  // Clock generation block to simulate clock signal.
  // Toggle the clock every 5 time units, creating a 10-time unit period.
  always
    #5 clk = ~clk; // Toggle the clock signal every 5 time units.

endmodule
