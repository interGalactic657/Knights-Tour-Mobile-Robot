// Set the timescale for the testbench.
`timescale 1ns/1ps

///////////////////////////////////////////////////////////////
// PID_tb.sv                                                 //
// This testbench simulates the PID controller,              //
// testing its functionality by using stimulus vectors       //
// and checking output using expected response vectors.      //
///////////////////////////////////////////////////////////////
module PID_tb();
  
  logic clk;                    // System clock signal.
  logic rst_n;                  // Asynchronous active low reset.
  logic moving;                 // Indicates whether the Knight is moving.
  logic err_vld;                // Indicates whether a new error is valid.
  logic signed [11:0] error;    // Signed 12-bit error term between desired and actual heading.
  logic signed [9:0] frwrd;     // Forward speed value summed with PID for motor speed calculation.
  logic signed [10:0] lft_spd;  // Left motor speed.
  logic signed [10:0] rght_spd; // Right motor speed.
  
  // Memory to hold stimulus and expected response vectors
  logic [24:0] stim[0:1999];    // 2000 stimulus vectors, 25-bits wide.
  logic [21:0] resp[0:1999];    // 2000 expected responses, 22-bits wide.
  
  integer i;                    // Loop variable to iterate through stimulus vectors.

  ///////////////////////////////////////////////////////////////////
  // Instantiate the PID controller (DUT) and simulate its inputs  //
  ///////////////////////////////////////////////////////////////////
  
  // Instantiate the PID controller module
  PID iPID (
    .clk(clk), 
    .rst_n(rst_n), 
    .moving(moving), 
    .err_vld(err_vld), 
    .error(error), 
    .frwrd(frwrd),
    .lft_spd(lft_spd), 
    .rght_spd(rght_spd)
  );

  ///////////////////////////////////////////////////////////////////
  // Test procedure to apply stimulus vectors and check responses  //
  ///////////////////////////////////////////////////////////////////
  initial begin
    clk = 1'b0;                      // Initially, clock is low.
    $readmemh("PID_stim.hex", stim); // Read stimulus vectors from file.
    $readmemh("PID_resp.hex", resp); // Read expected responses from file.
    // Wait for the negative edge of clock to set input stimulus.
    @(negedge clk);

    // Loop through the 2000 vectors in the stimulus memory.
    for (i = 0; i < 2000; i = i + 1) begin
      // Apply stimulus to the DUT inputs based on the current vector.
      rst_n = stim[i][24];
      moving = stim[i][23];
      err_vld = stim[i][22];             
      error = stim[i][21:10];          
      frwrd = stim[i][9:0];

      // Wait for the PID controller to process the input and generate output.
      @(posedge clk);

      // Check expected output slightly after the rising edge of clock.
      #1

      // Check whether the left motor speed matches the expected value.
      if (lft_spd !== resp[i][21:11]) begin
        $display("ERROR: Left motor speed: 0x%h does not match the expected value: 0x%h at index %d.", lft_spd, resp[i][21:11], i);
        $stop();
      end

      // Check whether the right motor speed matches the expected value.
      if (rght_spd !== resp[i][10:0]) begin
        $display("ERROR: Right motor speed: 0x%h does not match the expected value: 0x%h at index %d.", rght_spd, resp[i][10:0], i);
        $stop();
      end

      // Wait for a negative edge before applying next stimulus.
      @(negedge clk);
    end

    // If all test cases passed, print a success message.
    $display("Srivibhav Jonnalagadda: YAHOO!! All tests passed.");
    $stop();
  end

  always
    #5 clk = ~clk; // toggle clock every 5 time units

endmodule
