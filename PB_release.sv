/////////////////////////////////////////////
// PB_release.sv                          //
// Synchronizes the push button release, //
// which is metastable on deassertion,  //
// to the system clock.                //
////////////////////////////////////////
module PB_release(
    input logic clk, // 50MHz system clock.
    input logic rst_n, // Global asynchronous active low reset.
    input logic PB, // Unsynchronized input from push button.
    output logic released // Indicates that the push button is released.
  );

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic PB_step; // Metastable PB signal.
  logic PB_stable_prev; // Synchronized previous PB signal.
  logic PB_stable_curr; // Synchronized current PB signal.
  ///////////////////////////////////////////////////

  // Implement rising edge detector to check when PB goes back high (inactive).
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      PB_step <= 1'b1;          // Preset the PB metastable value.
      PB_stable_prev <= 1'b1;   // Preset the PB stable value.
      PB_stable_curr <= 1'b1;   // Preset the PB edge detection flop.
    end else begin
      PB_step <= PB;                    // Flop the PB signal to correct metastability.
      PB_stable_prev <= PB_step;        // The synchronized PB signal with the system clock.
      PB_stable_curr <= PB_stable_prev; // Used to detect rising edge on PB pulse.
    end
  end

  // The PB is released when the previous value was low and current value is high.
  assign released = ~PB_stable_prev & PB_stable_curr;
endmodule