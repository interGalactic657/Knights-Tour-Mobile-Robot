/////////////////////////////////////////////
// reset_synch.sv                         //
// Synchronizes the incoming RST_n,      //
// which is metastable on deassertion,  //
// to the system clock.                //
////////////////////////////////////////
module reset_synch(
    input logic clk, // // 50MHz system clock.
    input logic RST_n, // Unsynchronized input from push button
    output logic rst_n // Synchronized global active low reset.
  );

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic RST_n_step; // Metastable RST_n signal.
  ///////////////////////////////////////////////////

  // Synchronize RST_n to the system clock.
  always_ff @(negedge clk, negedge RST_n) begin
  	if (!RST_n) begin
  	  RST_n_step <= 1'b0; // Asynchronously reset the RST_n metastable value.
  	  rst_n <= 1'b0; // Asynchronously reset the stable the rst_n table value.
  	end else begin
  	  RST_n_step <= 1'b1;  // By default, it is inactive, tied to VDD.
  	  rst_n <= RST_n_step; // The synchronized rst_n signal with the system clock to deassert correctly.
  	end
  end
endmodule
