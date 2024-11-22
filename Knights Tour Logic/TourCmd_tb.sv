/////////////////////////////////////////////////
// TourCmd_tb.sv                               //
// This is the testbench for the command       //
// processing unit of the Knight robot. It     //
// simulates various Bluetooth commands and    //
// verifies the DUT's responses.               //
/////////////////////////////////////////////////
module TourCmd_tb();

  logic clk;               // System clock signal.
  logic rst_n;             // Asynchronous active low reset.
  logic start_tour;	       // from done signal from TourLogic
  logic [7:0] move;	       // encoded 1-hot move to perform
  logic cmd_rdy_UART;	     // cmd_rdy from UART_wrapper
  logic send_resp;         // lets us know cmd_proc is done with the move command
  logic [15:0] cmd;        // multiplexed cmd to cmd_proc
  logic cmd_rdy;           // cmd_rdy signal to cmd_proc
  logic [4:0] mv_indx;     // "address" to access next move
  logic [7:0] resp;        // either 0xA5 (done) or 0x5A (in progress)
  logic [7:0] moves[0:23]; // 8-bit wide 24 entry ROM modelling the KnightsTour movements.
  logic [:0] moves[0:23]; // 8-bit wide 24 entry ROM modelling the KnightsTour movements.

  /////////////////////////////////////////////////
  // Instantiate the (DUTs) and simulate inputs //
  ///////////////////////////////////////////////
  // Instantiate the TourCmd (iTOUR) module
  TourCmd iTOUR(
      .clk(clk), 
      .rst_n(rst_n), 
      .start_tour(start_tour), 
      .move(move), 
      .mv_indx(mv_indx), 
      .cmd_UART(16'h0000), 
      .cmd(cmd), 
      .cmd_rdy_UART(1'b0), 
      .cmd_rdy(cmd_rdy), 
      .clr_cmd_rdy(clr_cmd_rdy), 
      .send_resp(send_resp), 
      .resp(resp)
  );

  // Task to wait for a signal to be asserted, otherwise times out.
  task automatic timeout_task(ref sig, input int clks2wait, input string signal);
    fork
      begin : timeout
        repeat(clks2wait) @(posedge clk);
        $display("ERROR: %s not getting asserted and/or held at its value.", signal);
        $stop(); // Stop simulation on error.
      end : timeout
      begin
        @(posedge sig) disable timeout; // Disable timeout if sig is asserted.
      end
    join
  endtask

  initial 

  // Present the requested move on clock low.
  always @(negedge clk) begin
    move <= moves[mv_indx];
  end

  ///////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses //
  /////////////////////////////////////////////////////////
  initial begin
    clk = 1'b0;          // Initially clock is low
    rst_n = 1'b0;        // Reset the machine
    $readmemh("sample_tour.hex",moves); // Read in a file containing a sample KnightsTour into the ROM.
    $readmemh("expected_commands.hex",resp); // Read in a file containing the expected commands TourCmd must generate, given a move.
    start_tour = 1'b0;   // Initially is low, i.e., inactive
    send_resp = 1'b0;    // Initially is low, i.e., inactive
    clr_cmd_rdy = 1'b0;  // Initially is low, i.e., inactive
    
    // Wait 1.5 clocks for reset
    @(posedge clk);
    @(negedge clk) begin 
      rst_n = 1'b1;               // Deassert reset on a negative edge of clock.
      start_tour = 1'b1;          // Assert start_tour and begin move decoding.
    end

    @(negedge clk) start_tour = 1'b0; // Deassert start_tour after one clock cycle.

    @(posedge clk); // Wait for a positive edge to process a move command.
    
    @(negedge clk) clr_cmd_rdy = 1'b1; // Clear the command ready signal.
    @(negedge clk) clr_cmd_rdy = 1'b0; // Deassert the signal.

    repeat(50) @(posedge clk); // Wait a couple of clock cycles.

    @(negedge clk) send_resp = 1'b1; // Assert send_resp as an acknowledgement.
    @(negedge clk) send_resp = 1'b0; // Deassert send_resp.




    ////////////////////////////////////////////////////////////////////////
    // TEST 1: Test whether the calibrate command is processed correctly //
    //////////////////////////////////////////////////////////////////////
    // Wait for cal_done to be asserted, or timeout after a 1000000 clocks.
    timeout_task(cal_done, 1000000, "cal_done");

    // Wait 60000 clock cycles, and ensure that 2 bytes are received.
    timeout_task(resp_rdy, 60000, "resp_rdy");

    ////////////////////////////////////////////////////////////////////
    //// TEST 2: Test whether the move command is processed correctly //
    ////////////////////////////////////////////////////////////////////
    cmd_sent = 16'h4001;               // Command to move the Knight by 1 square to the north.
    @(negedge clk) snd_cmd = 1'b1;     // assert snd_cmd and begin transmission
    
    // Deassert snd_cmd after one clock cycle.
    @(negedge clk) snd_cmd = 1'b0;

    // Wait 60000 clock cycles, and ensure that 2 bytes are transmitted.
    timeout_task(cmd_snt, 60000, "cmd_snt");

    // The forward speed register should be 10'h020 initially right after the command was sent.
    // As cmd_rdy is asserted before cmd_snt, it has already incremented once.
    if (frwrd !== 10'h020) begin
      $display("ERROR: frwrd should have been 10'h020 but was 0x%h", frwrd);
      $stop();
    end

    // Wait for 10 positive edges on heading ready, indicating 10 new readings. 
    repeat(10) @(posedge heading_rdy);
    
    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // After 10 positive edges on heading ready, frwrd speed should be incremented accordingly.
      if (frwrd !== 10'h140) begin
        $display("ERROR: frwrd speed should have been incremented to 10'h140 but was 0x%h", frwrd);
        $stop();
      end

      // The moving signal should be asserted at this time as the Knight is moving.
      if (moving !== 1'b1) begin
        $display("ERROR: moving should have been asserted as the Knight was moving but was not.");
        $stop();
      end
    end

    // Wait for 20 more positive edges on heading ready, indicating 20 new readings. 
    repeat(20) @(posedge heading_rdy);

    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // After 20 more positive edges on heading ready, frwrd speed should be saturated to the maximum speed.
      if (frwrd !== 10'h300) begin
        $display("ERROR: frwrd speed should have been saturated to the maximum speed but was 0x%h.", frwrd);
        $stop();
      end
    end
    
    // Give a pulse on the cntrIR sensor.
    @(negedge clk) cntrIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Say it no longer sees the pulse on cntrIR.
    @(negedge clk) cntrIR = 1'b0;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // frwrd speed should still be saturated to the maximum speed.
      if (frwrd !== 10'h300) begin
        $display("ERROR: frwrd speed should have been saturated to the maximum speed but was 0x%h.", frwrd);
        $stop();
      end
    end

    // Give a second pulse on the cntrIR sensor indicating the Knight entered a square.
    @(negedge clk) cntrIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(5) @(negedge clk);

    // Say it no longer sees the pulse on cntrIR.
    @(negedge clk) cntrIR = 1'b0;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Wait for two new headings, to decrement the speed twice.
    repeat(2) @(posedge heading_rdy);

    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // After 2 new headings, the forward speed register should have been decremented by 10'h2C0.
      if (frwrd !== 10'h2C0) begin
          $display("ERROR: frwrd speed should have been decremented to 10'h2C0 but was 0x%h", frwrd);
          $stop();
      end
    end

    // Wait for a couple new headings, to decrement the speed to zero eventually.
    repeat(12) @(posedge heading_rdy);

    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // After 12 positive edges on heading ready, frwrd speed should be decremented to zero.
      if (frwrd !== 10'h000) begin
        $display("ERROR: frwrd speed should have been zeroed out but was 0x%h.", frwrd);
        $stop();
      end

      // The moving signal should be low as frwrd speed is zeroed out by now.
      if (moving !== 1'b0) begin
          $display("ERROR: moving should have been deasserted as the Knight completely slowed down but was not.");
          $stop();
      end
    end

    // Wait for resp_rdy to be asserted (sending 2 bytes over UART_Wrapper), or timeout.
    timeout_task(resp_rdy, 60000, "resp_rdy");
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //// TEST 3: Test whether the move command is processed correctly along with a nudge factor //
    /////////////////////////////////////////////////////////////////////////////////////////////
    cmd_sent = 16'h4001;               // Command to move the Knight by 1 square to the north.
    @(negedge clk) snd_cmd = 1'b1;     // Assert snd_cmd and begin transmission.
    
    // Deassert snd_cmd after one clock cycle.
    @(negedge clk) snd_cmd = 1'b0;

    // Wait 60000 clock cycles, and ensure that 2 bytes are transmitted.
    timeout_task(cmd_snt, 60000, "cmd_snt");

    // Wait for the speed to saturate.
    repeat(25) @(posedge heading_rdy);

    // Say the Knight was veering slightly more towards the left.
    @(negedge clk) lftIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(50) @(posedge clk);

    // Check the output on an negative edge of clock.
    @(negedge clk) begin
      // Say it no longer sees the pulse on lftIR.
      lftIR = 1'b0;

      // The error should have a large disturbance after the Knight veers too much to the left.
      if (iCMD_PROC.error_abs < 12'h02C) begin
          $display("ERROR: the error term should have a great amount of disturbance but does not.");
          $stop();
      end
    end

    // If we reached here, that means all test cases were successful.
		$display("YAHOO!! All tests passed.");
		$stop();
  end

always
  #5 clk = ~clk; // toggle clock every 5 time units

endmodule
