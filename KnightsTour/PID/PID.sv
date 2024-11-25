//////////////////////////////////////////////////////////////////
// PID.sv                                                      //
// Computes the PID control loop to correct system            //
// deviation based on proportional (P), integral (I),        //
// and derivative (D) terms. The PID controller adjusts     //
// the control output by combining the immediate error     //
// correction (P-term), the accumulated error over time   //
// (I-term), and the rate of change of the error         //
// (D-term) to achieve precise and stable control.      //
/////////////////////////////////////////////////////////
module PID(
  input logic clk, // System clock signal. 
  input logic rst_n, // Asynchronous active low reset.
  input logic moving, // The Knight is moving so PID should be active.
  input logic err_vld, // A new error signal is valid and should be accumulated into I_term.
  input logic signed [11:0] error, // Signed 12-bit error term between desired and actual heading.
  input logic [9:0] frwrd, // Summed with PID to form lft_spd,right_spd
  output logic signed [10:0] lft_spd, // Signed left motor speed.
  output logic signed [10:0] rght_spd // Signed right motor speed.
);
	/////////////////////////////////////////////////
	// Declare any internal signals as type logic //
	///////////////////////////////////////////////
	////////////////////// P_term //////////////////////////////////////////
	logic signed [9:0] err_sat;   // Saturated error term in 10 bits.
	localparam P_COEFF = 6'h10;   // Coefficient used to compute the P_term.
	logic signed [13:0] P_term;   // proportional term (P_term) required to correct heading
	////////////////////// I_term //////////////////////////////////////////
	logic signed [14:0] err_sat_ext; // Sign extend the 10-bit saturated error term to 15 bits.
	logic signed [14:0] sum; // Sum of new error with previous value.
	logic ov; // Signal used for detecting overflow.
	logic signed [14:0] accumulate; // Stores either the new computed sum, or previous result.
	logic signed [14:0] nxt_integrator; // New result to store in the system.
	logic signed [14:0] integrator; // Computed I_term over multiple clock cycles, only the most significant 9 bits used.
	logic signed [8:0] I_term; // The I_term for use in PID control.
	////////////////////// D_term //////////////////////////////////////////
	logic signed [9:0] first_error;    // The first valid error.
	logic signed [9:0] second_error;  // The second valid error.
	logic signed [9:0] prev_err;     // The third recent valid error.
	logic signed [9:0] D_diff;      // Difference between the third valid error and current error.
	logic signed [7:0] D_diff_sat; // Saturate the 10-bit difference term to 8 bits.
	localparam D_COEFF = 5'h07;   // Coefficient used to compute the D_term.
	logic signed [12:0] D_term; // The D_term for use in PID control.
	///////////////////////// PID ///////////////////////////////////////////
	logic signed [13:0] P_term_ext; // Sign extended (P_term) required to correct heading.
	logic signed [13:0] I_term_ext; // Sign extended I_term for use in PID control.
	logic signed [13:0] D_term_ext; // Sign extended D_term for use in PID control.
	logic signed [13:0] PID_term; // The PID term for correcting system heading.
	logic signed [10:0] frwrd_ext; // Zero extended frwrd term for computation.
	logic signed [10:0] lft_spd_raw; // The raw left speed, formed by summing frwrd_ext term with PID term.
	logic signed [10:0] rght_spd_raw; // The raw right speed, formed by subtracting PID term from frwrd_ext term.
	////////////////////////////////////////////////////////////////////////
	
	///////////////////////////////////////////
	// Implement P_term as dataflow verilog //
	/////////////////////////////////////////

	// Saturate error: clamp to 0x1FF if error is greater than max, 
	// 0x200 if error is less than min, else use the 10 least significant
	// bits as the error, where max and min are the most positive
	// and most negative numbers representable in signed 10 bit binary.
    assign err_sat = (~error[11] & |error[10:9]) ? 10'h1FF:
					 (error[11] & ~&error[10:9]) ? 10'h200:
					 error[9:0];
	
	// Calculate the P_term by multiplying the saturated error term
	// with the chosen coefficient.
	assign P_term = err_sat * $signed(P_COEFF);
	
	////////////////////////////////////////////////////////////
	// Implement I_term as dataflow and behaviorial verilog  //
	//////////////////////////////////////////////////////////
	
	// Sign extend the 10-bit saturated error term to 15 bits.
    assign err_sat_ext = {{5{err_sat[9]}}, err_sat};
	
	// Infer an accumulator to sum up previous value with current value.
	assign sum = err_sat_ext + integrator;
	
	/* OVERFLOW DETECTION LOGIC */
	// Inferring a 2:1 MUX and checking if the MSBs of each, 
	// the currently stored sum and the new error term 
	// are equal, then we check if the sum has a different sign, meaning the sum
	// has overflowed. Otheriwse, we have not overflowed the sum.
	assign ov = (err_sat_ext[14] ^ integrator[14]) ? 1'b0 : (sum[14] ^ err_sat_ext[14]);
	
	// Infer a 2:1 MUX to decide whether to store new result or keep previous value
	// based on overflow and having a valid error term.
	assign accumulate = (~ov & err_vld) ? sum : integrator;
	
	// Infer a 2:1 MUX to store a result, either previous or newly computed
	// value if the robot is moving. Otherwise, clear the currently stored value to 0,
	// as the robot is currently idle.
	assign nxt_integrator = (moving) ? accumulate : 15'h0000;
	
	// Infer a positive edge triggered flip-flop with active low asynchronous
	// reset, for performing integration over multiple clock cycles.
	always_ff @(posedge clk, negedge rst_n)
	    // Reset the flop to 0.
		if(!rst_n)
			integrator <= 15'h0000;
		else
			// Store the previous value.
			integrator <= nxt_integrator;
			
	// Grab the most significant 9 bits of the integrator as the I_term.
	assign I_term = integrator[14:6];

	////////////////////////////////////////////////////////////
	// Implement D_term as dataflow and behaviorial verilog  //
	//////////////////////////////////////////////////////////
	
	// Infer a 3 flop pipeline, each holding the first, second, and most recent valid error
	// to compute the difference in the error over 3 clock cycles. 
	always_ff @(posedge clk, negedge rst_n) begin
		// Reset all flip-flops.
		if(!rst_n) begin
			first_error <= 10'h000;
			second_error <= 10'h000;
			prev_err <= 10'h000;
		end else if(err_vld) begin
			// Store the new error if err_vld is asserted, else store the previous error. 
			first_error <= err_sat;
			second_error <= first_error;
			prev_err <= second_error;
		end
	end

	// Compute the difference in the current error and 3rd recent error.
	assign D_diff = err_sat - prev_err;

	// Saturate the difference as an 8-bit signed term.
	assign D_diff_sat = (~D_diff[9] & |D_diff[8:7]) ? 8'h7F:
					    (D_diff[9] & ~&D_diff[8:7]) ? 8'h80:
					    D_diff[7:0];
			
	// Calculate the D_term by multiplying the saturated difference term
	// with the chosen coefficient.
	assign D_term = D_diff_sat * $signed(D_COEFF);

	/////////////////////////////////////////
	// Implement PID as dataflow verilog  //
	///////////////////////////////////////

	// Divide the P_term by 2 and sign extend the result to 14 bits.
	assign P_term_ext = {P_term[13],P_term[13:1]};

	// Sign extend the I_term to 14 bits.
	assign I_term_ext = {{5{I_term[8]}},I_term};

	// Sign extend the D_term to 14 bits.
	assign D_term_ext = {D_term[12],D_term};

	// Form the PID term by summing the P,I,D terms.
	assign PID_term = P_term_ext + I_term_ext + D_term_ext;

	// Zero extend the frwrd term for computation.
	assign frwrd_ext = {1'b0, frwrd};

	// Stores the raw left speed if the robot is moving. 
	// Otherwise, clear the currently stored value to 0,
	// as the robot is currently idle.
	assign lft_spd_raw = (moving) ? (PID_term[13:3] + frwrd_ext) : 11'h000;

	// Stores the raw right speed if the robot is moving. 
	// Otherwise, clear the currently stored value to 0,
	// as the robot is currently idle.
	assign rght_spd_raw = (moving) ? (frwrd_ext - PID_term[13:3]) : 11'h000;

	// Clamp lft_spd to 0x3FF if the PID_term was positive but
	// the lft_spd_raw was negative, else use the raw computed value 
	// as the lft_spd.
    assign lft_spd = (~PID_term[13] & lft_spd_raw[10]) ? 11'h3FF : lft_spd_raw;

	// Clamp rght_spd to 0x3FF if rght_spd_raw was more
	// positive than could be represented in 11 bits, 
	// else use the raw computed value as the rght_spd.
    assign rght_spd =  (PID_term[13] & rght_spd_raw[10]) ? 11'h3FF : rght_spd_raw;
endmodule