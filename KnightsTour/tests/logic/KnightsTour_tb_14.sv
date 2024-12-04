module KnightsTour_tb();

  import tb_tasks::*;

  localparam FAST_SIM = 1;
  
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
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour #(FAST_SIM) iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  RemoteComm_e iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics #(15'h2800, 15'h0800) iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
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
    
    ////////////////////////////////////////////////////////////////
    // Test a couple moves of the KnightsTour starting at (2,0)  //
    //////////////////////////////////////////////////////////////
    // Send a command to start the KnightsTour from (2,0) without giving the y position.
    SendCmd(.cmd_to_send(16'h7020), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait till the Knight found out its position on the board.
    ChkOffset(.tour_go(iDUT.tour_go), .clk(clk), .target_yy(3'h2), .actual_yy(iDUT.y_offset));

    // Check that the Knight achieved the desired heading (should be facing south).
    ChkHeading(.clk(clk), .target_heading(12'h7FF), .actual_heading(iPHYS.heading_robot[19:8]));

    // Check if Knight moved back to the starting location on the board.
    ChkPos(.clk(clk), .target_xx(3'h2), .target_yy(3'h2), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));

    // Wait till the solution for the KnightsTour is complete or times out.
    WaitComputeSol(.start_tour(iDUT.start_tour), .clk(clk));

    // Wait till the vertical component of the first move is made.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that the response received is 0x5A.
    ChkAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Wait till the horizontal component of the first move is made.
    WaitForMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that the response received is 0x5A at the end of the first move.
    ChkAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Check that the Knight is at (0,1) at the end of the first move.
    ChkPos(.clk(clk), .target_xx(3'h0), .target_yy(3'h1), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));

    // Wait till the second L-shape move is made.
    WaitTourMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that the Knight is at (1,3) at the end of the second move.
    ChkPos(.clk(clk), .target_xx(3'h1), .target_yy(3'h3), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));

    // Wait till the third L-shape move is made.
    WaitTourMove(.send_resp(iDUT.send_resp), .clk(clk));

    // Check that the Knight is at (3,4) at the end of the third move.
    ChkPos(.clk(clk), .target_xx(3'h3), .target_yy(3'h4), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));
    /////////////////////////////////////////////////////////////////////////////////////////////////
  end
  
  always
    #5 clk = ~clk;
  
endmodule