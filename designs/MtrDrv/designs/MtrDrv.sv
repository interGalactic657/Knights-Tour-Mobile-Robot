/////////////////////////////////////////////////////
// MtrDrv.sv                                      //
// This design will drive both motors via PWM    //
// signal generation.                           //
/////////////////////////////////////////////////
module MtrDrv(
  input logic clk, // 50MHz system clk.
  input logic rst_n, // Asynchronous active low reset.
  input logic signed [10:0] lft_spd, // Signed left motor speed.
  input logic signed [10:0] rght_spd,   // Signed right motor speed.
  output logic lftPWM1,  // To power MOSFETs that drive lft motor.
  output logic lftPWM2,  // To power MOSFETs that drive lft motor.
  output logic rghtPWM1,  // To power MOSFETs that drive right motor.
  output logic rghtPWM2  // To power MOSFETs that drive right motor.
);

	/////////////////////////////////////////////////
	// Declare any internal signals as type logic //
	///////////////////////////////////////////////
	logic [10:0] left_duty; // Duty cycle of the left motor.
	logic [10:0] right_duty; // Duty cycle of the right motor.
	//////////////////////////////////////////////////////////
	// Implement MtrDrv as dataflow and structural verilog //
	////////////////////////////////////////////////////////

	// Scale the left speed with 50% drive duty to get left duty.
	assign left_duty = lft_spd + 11'h400;

    // Scale the right speed with 50% drive duty to get right duty.
	assign right_duty = rght_spd + 11'h400;
	
	// Instantiate left and right PWM11 blocks to control both motors accordingly.
	PWM11 iLEFT(.clk(clk), .rst_n(rst_n), .duty(left_duty), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
	PWM11 iRIGHT(.clk(clk), .rst_n(rst_n), .duty(right_duty), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));
endmodule