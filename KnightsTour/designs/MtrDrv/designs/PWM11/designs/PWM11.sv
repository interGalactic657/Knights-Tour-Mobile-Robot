/////////////////////////////////////////////////////
// PWM11.sv                                       //
// This design will create a 11-bit pulse width  // 
// modulation block that generates a signal     //
// and has 2048 levels of duty cycle.          //
////////////////////////////////////////////////
module PWM11(
  input logic clk, // 50MHz system clk.
  input logic rst_n, // Asynchronous active low reset.
  input logic [10:0] duty, // Specifies duty cycle (unsigned 11-bit)
  output logic PWM_sig,   // PWM signal out (glitch free)
  output logic PWM_sig_n   // Inverted PWM output.
);

	/////////////////////////////////////////////////
	// Declare any internal signals as type logic //
	///////////////////////////////////////////////
	logic comparison; // Output of the comparission between current count and duty cycle.
	logic [10:0] cnt; // Current count to output PWM signal as high until it is greater than duty.
	/////////////////////////////////////////////////////////
	// Implement PWM11 as behavioral and dataflow verilog //
	///////////////////////////////////////////////////////
	
	// Compare the current count and duty cycle, and output a high PWM signal only when this is true.
    assign comparison = cnt < duty;
	
	// Infer a positive edge triggered flip flop with active low asynchronous
	// reset, used as a 11-bit counter.
	always_ff @(posedge clk, negedge rst_n)
	    // Reset the flop to 0.
		if(!rst_n)
			cnt <= 11'h000;
		else
			// Increment the count.
			cnt <= cnt + 1;
    
    // Infer a positive edge triggered flip flop with active low asynchronous
	// reset, used as outputting the PWM signal.
	always_ff @(posedge clk, negedge rst_n)
	    // Reset the flop to 0.
		if(!rst_n)
			PWM_sig <= 1'b0;
		else
			// Store the new value.
			PWM_sig <= comparison;
			
	// Invert the PWM signal to get an inverted PWM output.
	assign PWM_sig_n = ~PWM_sig;
	
endmodule