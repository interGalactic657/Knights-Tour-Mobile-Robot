/////////////////////////////////////////////////
// TourCmd_tb.sv                               //
// This is the testbench for the command       //
// processing unit of the Knight robot. It     //
// simulates various Bluetooth commands and    //
// verifies the DUT's responses.               //
/////////////////////////////////////////////////
module TourCmd_tb();

  logic clk;                             // System clock signal.
  logic rst_n;                           // Asynchronous active low reset.
  logic start_tour;	                     // from done signal from TourLogic
  logic [7:0] move;	                     // encoded 1-hot move to perform
  logic cmd_rdy_UART;	                   // cmd_rdy from UART_wrapper
  logic send_resp;                       // lets us know cmd_proc is done with the move command
  logic [15:0] cmd;                      // multiplexed cmd to cmd_proc
  logic cmd_rdy;                         // cmd_rdy signal to cmd_proc
  logic clr_cmd_rdy;		                 // from cmd_proc (goes to UART_wrapper too)
  logic [4:0] mv_indx;                   // "address" to access next move
  logic [7:0] resp;                      // either 0xA5 (done) or 0x5A (in progress)
  logic [7:0] moves[0:23];               // 8-bit wide 24 entry ROM modelling the KnightsTour movements.
  logic [23:0] response_vectors[0:47];   // 24-bit wide 48 entry array modelling the expected KnightsTour commands to be issued.
  logic [4:0] expected_mv_indx;          // the expected move index to perform
  logic [7:0] expected_resp;             // expected response to receive from TourCmd
  logic [15:0] expected_cmd;             // expected cmd to receive from TourCmd
  integer i;                             // Loop variable to iterate through response vectors.

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
    $readmemh("expected_commands.hex",response_vectors); // Read in a file containing the expected commands TourCmd must generate, given a move.
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

    // Loop through the 48 expected commands to check if TourCmd processes moves correctly. 
    for (i = 0; i < 48; i = i + 1) begin
      // Wait for the PID controller to process the input and generate output.
      @(posedge clk);

      // Check expected output slightly after the rising edge of clock.
      #1

      expected_mv_indx = i/2; // The expected move index of the KnightsTour.
      expected_cmd = response_vectors[i][23:8]; // The expected command to receive from TourCmd.
      expected_resp = response_vectors[i][7:0]; // The expected response to receive from TourCmd.
      
      // Check if the correct move is being processed by TourCmd.
      if (mv_indx !== expected_mv_indx) begin
        $display("ERROR: Incorrect move being processed expected: 0x%h\nactual: 0x%h.", expected_mv_indx, mv_indx);
        $stop();
      end

      // Check if the cmd is processed correctly by TourCmd.
      if (cmd !== expected_cmd) begin
        $display("ERROR: Incorrect command sent on move index %d\nexpected: 0x%h\nactual: 0x%h.", mv_indx, expected_cmd, cmd);
        $stop();
      end

      @(negedge clk) clr_cmd_rdy = 1'b1; // Assert clr_cmd_rdy indicating that the command is correct and has been received.
      @(negedge clk) clr_cmd_rdy = 1'b0; // Deassert clr_cmd_rdy on negative edge of clock.

      repeat(10) @(posedge clk); // Wait for a couple clocks for the Knight to perform the move.

      @(negedge clk) send_resp = 1'b1; // Send an acknowledgement back to the Bluetooth module. 
      @(negedge clk) send_resp = 1'b0; // Deassert the send_resp signal.

        // Check if correct response is sent back to the Bluetooth module for a given move.
      if (resp !== expected_resp) begin
        $display("ERROR: Incorrect response sent back to Bluetooth module on move index %d\nexpected: 0x%h\nactual: 0x%h", mv_indx, expected_resp, resp);
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
