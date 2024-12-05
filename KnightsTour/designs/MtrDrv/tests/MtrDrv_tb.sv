////////////////////////////////////////////////////
// MtrDrv_tb.sv                                  //
// This testbench will simulate the MtrDrv for  //
// 0%, 25%, 75%, and 100% duty cycles.         //
////////////////////////////////////////////////
module MtrDrv_tb();
  
  logic clk;    // 50MHz system clk.
  logic rst_n; // Asynchronous active low reset.
  logic signed [10:0] lft_spd; // Signed left motor speed.
  logic signed [10:0] rght_spd;   // Signed right motor speed.
  logic lftPWM1;  // To power MOSFETs that drive lft motor.
  logic lftPWM2;  // To power MOSFETs that drive lft motor.
  logic rghtPWM1;  // To power MOSFETs that drive right motor.
  logic rghtPWM2;  // To power MOSFETs that drive right motor.
  
  ////////////////////////////////
  // Instantiate MtrDrv module //
  //////////////////////////////
  MtrDrv iDUT(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), .rght_spd(rght_spd), 
  .lftPWM1(lftPWM1), .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2));  

  // Both test cases ensure that both motors are connected to
  // the correct PWM module, hence testing different duty cycles 
  // for both motors, i.e., 25%-75% and 100%-0%.  
  initial begin
		clk = 1'b0; // Initially clock is low.
		rst_n = 1'b0; // Reset the system.

		/* TEST CASE 1 */
		lft_spd = 11'h200; // Start at 75% forward left speed.
		rght_spd = 11'h600; // Start at 25% forward right speed.
		//// wait 1.5 clocks for reset ////
		@(posedge clk);
		@(negedge clk) rst_n = 1'b1;
		repeat(4096) @(posedge clk); // Check 2 cycles at 75% left and 25% right speeds.

		/* TEST CASE 2 */
		rst_n = 1'b0; // Reset the system.
		@(negedge clk) begin
			rst_n = 1'b1; // Deassert reset on the negative edge.
			lft_spd = 11'h3FF; // Start at 100% forward left speed.
			rght_spd = 11'h400; // Start at 0% forward right speed.
		end
		repeat(4096) @(posedge clk); // Check 2 cycles at 100% left and 0% right speeds.

		$stop(); // End the simulation.
	end

  always
    #5 clk = ~clk; // toggle clock every 5 time units
  
endmodule