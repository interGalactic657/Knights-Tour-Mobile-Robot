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
  input clk, rst_n,				                  // System clock and asynch active low reset.
  input moving,                             // The Knight is moving so PID should be active.
  input err_vld,                            // A new error signal is valid and should be accumulated into I_term.
  input signed	[11:0] error,	              // Signed 12-bit error term between desired and actual heading.
  input [9:0] frwrd,                        // Summed with PID to form lft_spd, right_spd.
  output signed [10:0] lft_spd, rght_spd    // These form the left and right inputs to mtr_drv.
);

  /////////////////////////////////////////////////
	// Declare any internal signals as type logic //
	///////////////////////////////////////////////
	////////////////////// P_term //////////////////////////////////////////
  logic err_vld1;               // Delayed error valid signal.
	logic signed [9:0] err_sat, err_sat0;   // Saturated error term in 10 bits.
	localparam P_COEFF = 6'h10;   // Coefficient used to compute the P_term.
	logic signed [13:0] P_term;   // Proportional term (P_term) required to correct heading.
	////////////////////// I_term //////////////////////////////////////////
  logic ov;                                       // Signal used for detecting overflow.
  logic signed [14:0] err_ext;                    // Sign extend the 10-bit saturated error term to 15 bits.
	logic signed [14:0] sum, accum;                 // Holds sum of integration and what to be added.
	logic signed [14:0] integrator, nxt_integrator; // Values to be fed to the I_term.
	logic signed [8:0] I_term;                      // The I_term for use in PID control.
	////////////////////// D_term //////////////////////////////////////////
  logic signed [9:0] stage1, stage2;   // Reg for flops to hold previous values.
  logic signed [9:0] prev_err, D_diff; // Reg for past error value used and difference between it and the current value.
	logic signed [7:0] D_diff_sat;       // Saturate the 10-bit difference term to 8 bits.
	localparam D_COEFF = 5'h07;          // Coefficient used to compute the D_term.
	logic signed [12:0] D_term;          // The D_term for use in PID control.  
  ///////////////////////// PID ///////////////////////////////////////////
	logic signed [13:0] P_ext, I_ext, D_ext;       // Sign extended PID terms.
  logic signed [13:0] PID_term, PID_term_PL;                  // Sum of all the PID terms.
	logic signed [10:0] frwrd_ext;                 // Zero extended frwrd term for computation.
	logic signed [10:0] raw_lft_spd, raw_rght_spd; // Holds the summed values before saturation.
	////////////////////////////////////////////////////////////////////////

  //Delay error valid signal by 1 clock cycle.
  always_ff @(posedge clk) begin
      err_vld1 <= err_vld;
  end

  ///////////////////////////////////////////
	// Implement P_term as dataflow verilog //
	/////////////////////////////////////////

  //////////////////////////////
  // Saturate the error term and pipleline it //
  ////////////////////////////
  // assign err_sat = (!error[11] && |error[10:9]) ? 10'h1FF :
  //                  (error[11] && !(&error[10:9])) ? 10'h200 :
  //                  error[9:0];
  always_ff @(posedge clk or negedge rst_n) begin
    // Reset the flop to 0.
    if(!rst_n)
      begin
      err_sat0 <= 10'h000;
      err_sat <= 10'h000;
      end
    else
      // Saturate the error term.
      begin
      err_sat <= err_sat0;
      err_sat0 <= (!error[11] && |error[10:9]) ? 10'h1FF :
                 (error[11] && !(&error[10:9])) ? 10'h200 :
                 error[9:0];
      end
  end

  /////////////////////////////////////
  // Get the P term from saturation //
  ///////////////////////////////////
  assign P_term = err_sat * $signed(P_COEFF);

  ////////////////////////////////////////////////////////////
	// Implement I_term as dataflow and behaviorial verilog  //
  //////////////////////////////////////////////////////////

  // Sign extend the 10-bit saturated error term to 15 bits.
  assign err_ext = {{5{err_sat[9]}}, err_sat};
	
	// Infer an accumulator to sum up previous value with current value.
	assign sum = err_sat + integrator;

  // Check for overflow.
  assign ov = (err_ext[14] ^ integrator[14]) ? 1'b0 : (err_ext[14] ^ sum[14]);

  // Decide whether to store new result or keep previous value
	// based on overflow and having a valid error term.
	assign accum = (err_vld1 & ~ov) ? sum : integrator;

  // Store a result, either previous or newly computed value if the robot is moving. Otherwise, 
  // clear the currently stored value to 0 as the robot is currently idle.
	assign nxt_integrator = (moving) ? accum : 15'h0000;

  // Performs integration over multiple clock cycles.
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

  ///////////////////////////////////////////////
  // Flop the error 3 times to have past data //
  /////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    // Reset all flip-flops.
    if(!rst_n) begin
      stage1 <= 0;
      stage2 <= 0;
      prev_err <= 0;
    end
    else if (err_vld1) begin
      // Store the new error if err_vld is asserted, else store the previous error. 
      stage1 <= err_sat;
      stage2 <= stage1;
      prev_err <= stage2;
    end
  end

  // Compute the difference in the current error and 3rd recent error.
	assign D_diff = err_sat - prev_err;

  // Saturate the difference as an 8-bit signed term.
  assign D_diff_sat = (!D_diff[9] && |D_diff[8:7]) ? 8'h7F   :
                      (D_diff[9] && !(&D_diff[8:7])) ? 8'h80 :
                      D_diff[7:0];

  // Calculate the D_term by multiplying the saturated difference term
	// with the chosen coefficient.
	assign D_term = D_diff_sat * $signed(D_COEFF);

  /////////////////////////////////////////
	// Implement PID as dataflow verilog  //
	///////////////////////////////////////

  ///////////////////////////////////////
  // Sign extend and sum up PID terms //
  /////////////////////////////////////
  assign P_ext = {P_term[13], P_term[13:1]};
  assign I_ext = {{5{I_term[8]}}, I_term};
  assign D_ext = {D_term[12], D_term};

  assign PID_term = P_ext + I_ext + D_ext;

  always_ff(@(posedge clk)) begin
      PID_term_PL <= PID_term;
  end

  ///////////////////////////////////////////////////////////////////////////
  // Calculate left and right speed based on PID and its forward movement //
  /////////////////////////////////////////////////////////////////////////
  // Zero extended frwrd to match bits.
  assign frwrd_ext = {1'b0, frwrd};

  // Ensure Knight is moving when calulating speed.
  assign raw_lft_spd = moving ? frwrd_ext + PID_term_PL[13:3] :
                                11'h000;

  assign raw_rght_spd = moving ? frwrd_ext - PID_term_PL[13:3] :
                                 11'h000;

  /////////////////////////////////////////////////////
  // Saturate left and right speed based on results //
  ///////////////////////////////////////////////////
  // Saturate lft if PID is positive and raw value is negative.
  assign lft_spd = (~PID_term_PL[13] & raw_lft_spd[10]) ? 11'h3FF : raw_lft_spd;

  // Saturate rght if PID is negative and raw value is negative.
  assign rght_spd = (PID_term_PL[13] & raw_rght_spd[10]) ? 11'h3FF : raw_rght_spd;

  
endmodule