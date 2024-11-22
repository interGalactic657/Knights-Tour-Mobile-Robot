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

    for (i = 0; i < 24; i++) begin
      // Check cmd is vertical component of move
      if (cmd !== exp_vert) begin
        $display("ERROR: incorrect vertical cmd on index %d\nexpected: %h\nactual: 0x%h", mv_indx, exp_vert, cmd);
        $stop();
      end

      clr_cmd_rdy = 1'b1; // cmd has been received and is correct
      @(negedge clk);
      clr_cmd_rdy = 1'b0; // deassert clr

      repeat(10) @(negedge clk);

      send_resp = 1'b1; // move finished, get 2nd part of move
      @(negedge clk);
      send_resp = 1'b0; // desassert resp

      // Chck cmd is horizontal component of move
      if (cmd !== exp_horz) begin
        $display("ERROR: incorrect horizontal cmd on index %d\nexpected: %h\nactual: 0x%h", mv_indx, exp_horz, cmd);
        $stop();
      end

      clr_cmd_rdy = 1'b1; // cmd has been received and is correct
      @(negedge clk);
      clr_cmd_rdy = 1'b0; // deassert clr

      repeat(10) @(negedge clk);

      send_resp = 1'b1; // move finished, get next move
      @(negedge clk);
      send_resp = 1'b0; // desassert resp

      // check resp sent at end of move
      if (mv_indx == 5'h17)
        if (resp !== 8'hA5) begin
          $display("ERROR: incorrect resp after all moves have finished\nexpected: 0xA5\nactual: 0x%h", resp);
          $stop();
        end
      else
        if (resp !== 8'h5A) begin
          $display("ERROR: incorrect resp from intermdiate move\nexpected: 0x5A\nactual: 0x%h", resp);
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
