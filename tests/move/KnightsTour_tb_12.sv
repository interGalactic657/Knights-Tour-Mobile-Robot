module KnightsTour_tb();

  import tb_tasks::*;
  
  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
  reg [15:0] cmd;
  reg send_cmd;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire SS_n,SCLK,MOSI,MISO,INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  wire IR_en;
  wire lftIR_n,rghtIR_n,cntrIR_n;
  wire piezo, piezo_n;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .snd_cmd(send_cmd), .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics #(15'h1800, 15'h1800) iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
	
  // Task to initialize the testbench.
  task automatic Setup();
    begin
      // Initialize all signals for the testbench.
      Initialize(.clk(clk), .RST_n(RST_n), .send_cmd(send_cmd), .cmd(cmd));

      // Send a command to calibrate the gyro of the Knight.
      SendCmd(.cmd_to_send(CAL_GYRO), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

      // Check that cal_done is being asserted after calibration.
      TimeoutTask(.sig(iDUT.cal_done), .clk(clk), .clks2wait(1000000), .signal("cal_done"));

      // Check that a positive acknowledge is received from the DUT.
      ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));
    end
  endtask 
	
  ///////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses //
  /////////////////////////////////////////////////////////
  initial begin
    ///////////////////////////////
    // Initialize the testbench //
    /////////////////////////////
    Setup();
    
    ///////////////////////////////////////////////////////////////////////////////////////
    // Test moving in L-shaped move from (1,1) (NE) by moving up 2 and right 1 to (2,3) //
    /////////////////////////////////////////////////////////////////////////////////////
    // Send a command to move the Knight north by two squares.
    SendCmd(.cmd_to_send(16'h4002), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait for the Knight to begin moving before checking heading
    WaitMoving(.clk(clk), .velocity_sum(iPHYS.omega_sum));

    // Check that the Knight achieved the desired heading
    ChkHeading(.clk(clk), .target_heading(NORTH), .actual_heading(iPHYS.heading_robot));

    // Wait till the move is complete and check that send_resp is asserted.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that a movement acknowledge is received from the DUT.
    ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Send a command to move the Knight east by one square (with fanfare).
    SendCmd(.cmd_to_send(16'h5BF1), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait for the Knight to begin moving before checking heading.
    WaitMoving(.clk(clk), .velocity_sum(iPHYS.omega_sum));

    // Check that the Knight achieved the desired heading
    ChkHeading(.clk(clk), .target_heading(EAST), .actual_heading(iPHYS.heading_robot));

    // Wait till the move is complete and check that send_resp is asserted.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that a movement acknowledge is received from the DUT.
    ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    ////////////////////////////////////////////////////////////////////////////////////////
    // Test moving in L-shaped move from (2,3) (SW) by moving down 1 and left 2 to (0,2) //
    //////////////////////////////////////////////////////////////////////////////////////
    // Send a command to move the Knight south by one square.
    SendCmd(.cmd_to_send(16'h47F1), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait for the Knight to begin moving before checking heading
    WaitMoving(.clk(clk), .velocity_sum(iPHYS.omega_sum));

    // Check that the Knight achieved the desired heading
    ChkHeading(.clk(clk), .target_heading(SOUTH), .actual_heading(iPHYS.heading_robot));

    // Wait till the move is complete and check that send_resp is asserted.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that a movement acknowledge is received from the DUT.
    ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Send a command to move the Knight west by two squares (with fanfare).
    SendCmd(.cmd_to_send(16'h53F2), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait for the Knight to begin moving before checking heading
    WaitMoving(.clk(clk), .velocity_sum(iPHYS.omega_sum));

    // Check that the Knight achieved the desired heading
    ChkHeading(.clk(clk), .target_heading(WEST), .actual_heading(iPHYS.heading_robot));

    // Wait till the move is complete and check that send_resp is asserted.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that a movement acknowledge is received from the DUT.
    ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Check if Knight moved to desired position on board.
    ChkPos(.clk(clk), .target_xx(3'h0), .target_yy(3'h2), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));

    // If we reached here, that means all test cases were successful.
		$display("YAHOO!! All tests passed.");
		$stop();
    /////////////////////////////////////////////////////////////////////////////////////////////////
  end

  // Checks that we are never off the board.
  always @(negedge clk)
    ChkOffBoard(.clk(clk), .RST_n(RST_n), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));
  
  always
    #5 clk = ~clk;
  
endmodule