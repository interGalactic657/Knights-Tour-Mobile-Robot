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
  input clk, rst_n,				                  // System clock and asynch active low reset
  input moving,                             // Clear I_term f not moving
  input err_vld,                            // Compute I & D again when vld
  input signed	[11:0] error,	              // 12-bit signed error term (heading - desired_heading)
  input [9:0] frwrd,                        // Summed iwth PID to form lft_spd, rght_spd
  output signed [10:0] lft_spd, rght_spd    // These form the input to mtr_drv
);

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic signed [9:0] err_sat;                       // Saturated error to 10 bits
  /* P Term */
  localparam signed P_COEFF = 6'h10;                // Coefficient to compute P_term
  logic signed  [13:0] P_term;                      // 14-bit signed P component of PID controller
  /* I Term */
  logic signed [14:0] err_ext;                      // Sign externsion of the saturated error
  logic signed [14:0] sum, accum;                   // Holds sum of integration and what to be added
  logic signed [14:0] integrator, nxt_integrator;   // Values to be fed to the I_term
  logic ov;                                         // Overflow has occured for I_term
  logic signed [8:0] I_term;                        // The I_term for eventual use in PID control
  /* D Term */
  localparam signed D_COEFF = 5'h07;                // Coefficient to compute D_term
  logic signed [9:0] stage1, stage2;                // reg for flops to hold previous values
  logic signed [9:0] prev_err, D_diff;              // reg for past error value used and difference between it and the current value
  logic signed [7:0] diff_sat;                      // holds the difference saturated to 8 bits
  logic signed  [12:0] D_term ;                     // The D_term for eventual use in PID control

  logic signed [13:0] P_ext, I_ext, D_ext;          // Sign extended PID terms
  logic signed [13:0] PID_term;                     // Sum of all the PID terms

  logic signed [10:0] frwrd_ext;                    // Zero extended frwrd term
  logic signed [10:0] raw_lft_spd, raw_rght_spd;    // Holds the summed values before saturaion

  //////////////////////////////
  // Saturate the error term //
  ////////////////////////////
  assign err_sat = (!error[11] && |error[10:9]) ? 10'h1FF :
                   (error[11] && !(&error[10:9])) ? 10'h200 :
                   error[9:0];

  /////////////////////////////////////
  // Get the P term from saturation //
  ///////////////////////////////////
  assign P_term = err_sat * P_COEFF;

  /////////////////////////////////////////
  // Extend and add error to integrator //
  ///////////////////////////////////////
  assign err_ext = {{5{err_sat[9]}}, err_sat};
  assign sum = err_ext + integrator;

  // check for overflow
  assign ov = (err_ext[14] ^ integrator[14]) ? 1'b0 : (err_ext[14] ^ sum[14]);

  ///////////////////////////////////////////
  // Get the new value for the integrator //
  /////////////////////////////////////////
  assign accum = (err_vld & ~ov) ? sum : integrator;
  assign nxt_integrator = moving ? accum : 15'h0000;

  always_ff @(posedge clk or negedge rst_n)
    if(!rst_n)
      integrator <= 15'h0000;
    else
      integrator <= nxt_integrator;

  /////////////////////////////////////////
  // Get the I term from the integrator //
  ///////////////////////////////////////
  assign I_term = integrator[14:6];


  ///////////////////////////////////////////////
  // Flop the error 3 times to have past data //
  /////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      stage1 <= 0;
      stage2 <= 0;
      prev_err <= 0;
    end
    else if (err_vld) begin
      stage1 <= err_sat;
      stage2 <= stage1;
      prev_err <= stage2;
    end
  end

  /////////////////////////////////////////////////
  // Get difference between curr and prev error //
  ///////////////////////////////////////////////
  assign D_diff = err_sat - prev_err;

  // saturate difference to 8 bits
  assign diff_sat = (!D_diff[9] && |D_diff[8:7]) ? 8'h7F :
                    (D_diff[9] && !(&D_diff[8:7])) ? 8'h80 :
                    D_diff[7:0];

  ////////////////////////////////////////////
  // Multiply by coeff to get final D_term //
  //////////////////////////////////////////
  assign D_term = diff_sat * D_COEFF;


  ///////////////////////////////////////
  // Sign extend and sum up PID terms //
  /////////////////////////////////////
  assign P_ext = {P_term[13], P_term[13:1]};
  assign I_ext = {{5{I_term[8]}}, I_term};
  assign D_ext = {D_term[12], D_term};

  assign PID_term = P_ext + I_ext + D_ext;

  ///////////////////////////////////////////////////////////////////////////
  // Calculate left and right speed based on PID and its forward movement //
  /////////////////////////////////////////////////////////////////////////
  // Zero extended frwrd to match bits
  assign frwrd_ext = {1'b0, frwrd};

  // Ensure Knight is moving when calulating speed
  assign raw_lft_spd = moving ? frwrd_ext + PID_term[13:3] :
                                11'h000;

  assign raw_rght_spd = moving ? frwrd_ext - PID_term[13:3] :
                                 11'h000;

  /////////////////////////////////////////////////////
  // Saturate left and right speed based on results //
  ///////////////////////////////////////////////////
  // Saturate lft if PID is positive and raw value is negative
  assign lft_spd = (~PID_term[13] & raw_lft_spd[10]) ? 11'h3FF :
                                                       raw_lft_spd;

  // Saturate rght if PID is negative and raw value is negative
  assign rght_spd = (PID_term[13] & raw_rght_spd[10]) ? 11'h3FF :
                                                        raw_rght_spd;

endmodule
