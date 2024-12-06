////////////////////////////////////////////////////
// PWM11_tb.sv                                   //
// This testbench will simulate the PWM11 for   //
// 0%, 25%, 75%, and 100% duty cycles.         //
////////////////////////////////////////////////
module PWM11_tb();
  
  logic clk;    // 50MHz system clk.
  logic rst_n; // Asynchronous active low reset.
  logic [10:0] duty; // Specifies duty cycle (unsigned 11-bit).
  logic PWM_sig;  // PWM signal out (glitch free)
  logic PWM_sig_n;  // Inverted PWM output.
  
  //////////////////////////////
  // Instantiate PWM11 module /
  ////////////////////////////
  PWM11 iDUT(.clk(clk), .rst_n(rst_n), .duty(duty), .PWM_sig(PWM_sig), .PWM_sig_n(PWM_sig_n));  

  // Test the PWM11 module for multiple duty cycles,
  // 0%, 25%, 75%, and 100%.		  
  initial begin
		clk = 1'b0; // Initially clock is low.
		rst_n = 1'b0; // Reset the system.

		/* TEST CASE 1 */
		duty = 11'h000; // Start at 0% duty cycle.
		//// wait 1.5 clocks for reset ////
		@(posedge clk);
		@(negedge clk) rst_n = 1'b1;
		repeat(4096) @(posedge clk); // Check 2 cycles at 0% duty cycle
        
		/* TEST CASE 2 */
        rst_n = 1'b0; // Reset the system.
		@(negedge clk) begin 
			rst_n = 1'b1;   // Deassert reset on the negative edge.
			duty = 11'h200; // Set to 25% duty cycle.
		end
		repeat(4096) @(posedge clk); // Check 2 cycles at 25% duty cycle.

        /* TEST CASE 3 */
		rst_n = 1'b0; // Reset the system.
		@(negedge clk) begin
			rst_n = 1'b1; // Deassert reset on the negative edge.
			duty = 11'h400; // Set to 50% duty cycle.
		end
		repeat(4096) @(posedge clk); // Check 2 cycles at 50% duty cycle.

		/* TEST CASE 4 */
		rst_n = 1'b0; // Reset the system.
		@(negedge clk) begin
			rst_n = 1'b1; // Deassert reset on the negative edge.
			duty = 11'h600; // Set to 75% duty cycle.
		end
		repeat(4096) @(posedge clk); // Check 2 cycles at 75% duty cycle.

		/* TEST CASE 5 */
		rst_n = 1'b0; // Reset the system.
		@(negedge clk) begin
		    rst_n = 1'b1; // Deassert reset on the negative edge.
			duty = 11'h7FF; // Set to 100% duty cycle.
		end
		repeat(4096) @(posedge clk); // Check 2 cycles at 100% duty cycle.

		$stop(); // End the simulation.
	end

  always
    #5 clk = ~clk; // toggle clock every 5 time units
  
endmodule