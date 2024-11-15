///////////////////////////////////////////
// sponge_test.sv                        //
// This testbench simulates playing the  //
// SpongeBob last measure tune on the    //
// DEO Nano FPGA with a piezo buzzer.    //
///////////////////////////////////////////
module sponge_test (
  input logic clk,        // 50 MHz system clock input.
  input logic RST_n,      // Unsynchronized reset input from the push button.
  input logic GO,         // Unsynchronized GO input from the push button to start the tune.
  output logic piezo,     // Output signal for the piezo buzzer (high for sound).
  output logic piezo_n    // Complement of piezo, used for active-low buzzer operation.
);

  /////////////////////////////////////////
  // Declare any internal signals here  //
  ///////////////////////////////////////
  logic rst_n;   // Global reset signal synchronized for the system.
  logic go;      // Signal to initiate the tune generation.
  /////////////////////////////////////////////////////////

  ///////////////////////////////////////////////
  // Instantiate the DUTs (Device Under Test) //
  /////////////////////////////////////////////

  // Instantiate the reset synchronizer.
  // This module ensures the reset signal is synchronized to the system clock.
  reset_synch iRST(
    .clk(clk),        // System clock input.
    .RST_n(RST_n),    // Unsynchronized reset input from the push button.
    .rst_n(rst_n)     // Synchronized reset output signal for the system.
  );

  // Instantiate the push button synchronizer.
  // This module ensures the GO input from the push button is synchronized to the system clock.
  PB_release iPB(
    .clk(clk),        // System clock input.
    .rst_n(rst_n),    // Synchronized reset input.
    .PB(GO),          // Unsynchronized GO input from the push button.
    .released(go)     // Synchronized GO output signal to trigger tune generation.
  );

  // Instantiate the sponge module (DUT).
  // This module generates the sound based on the GO signal and drives the piezo buzzer.
  sponge iSPONGE(
    .clk(clk),        // System clock input.
    .rst_n(rst_n),    // Synchronized reset input.
    .go(go),          // Start signal to initiate the tune.
    .piezo(piezo),    // Output signal for piezo buzzer (active high).
    .piezo_n(piezo_n) // Complementary signal for active-low piezo buzzer operation.
  );

endmodule
