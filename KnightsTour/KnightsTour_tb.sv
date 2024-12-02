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
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
	
  ///////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses //
  /////////////////////////////////////////////////////////
  initial begin
    /////////////////////////////
    // Initialize all signals //
    ///////////////////////////
    Initialize(.clk(clk), .RST_n(RST_n), .send_cmd(send_cmd), .cmd(cmd));

    ///////////////////////////////////////////////
    // TEST 1: Test signals post initialization //
    /////////////////////////////////////////////
    // Check that the PWM signals are running and at midrail right after reset.
    if (iDUT.lftPWM1 !== 1'bx) begin
      $display("ERROR: lftPWM1 signal should have been midrail after reset but was not.");
      $stop(); 
    end

    if (iDUT.lftPWM2 !== 1'bx) begin
      $display("ERROR: lftPWM2 signal should have been midrail after reset but was not.");
      $stop(); 
    end

    if (iDUT.rghtPWM1 !== 1'bx) begin
      $display("ERROR: rghtPWM1 signal should have been midrail after reset but was not.");
      $stop(); 
    end
    if (iDUT.rghtPWM2 !== 1'bx) begin
      $display("ERROR: rghtPWM2 signal should have been midrail after reset but was not.");
      $stop(); 
    end

    if (iDUT.piezo !== 1'bx) begin
      $display("ERROR: piezo signal should have been midrail after reset but was not.");
      $stop(); 
    end

    if (iDUT.piezo_n !== 1'bx) begin
      $display("ERROR: piezo_n signal should have been midrail after reset but was not.");
      $stop(); 
    end

    // Check that NEMO_setup is being asserted after initialization.
    TimeoutTask(.sig(iPHYS.iNEMO.NEMO_setup), .clk(clk), .clks2wait(1000000), .signal("NEMO_setup"));
    /////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////
    // TEST 2: Test signals post calibration //
    //////////////////////////////////////////
    // Send a command to calibrate the gyro of the Knight.
    SendCmd(.cmd_to_send(CAL_GYRO), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Check that cal_done is being asserted after calibration.
    TimeoutTask(.sig(iDUT.cal_done), .clk(clk), .clks2wait(1000000), .signal("cal_done"));

    // Check that a positive acknowledge is received from the DUT.
    ChkPosAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));
    /////////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 3: Test whether the move command is processed correctly //
    /////////////////////////////////////////////////////////////////
    // Send a command to move the Knight west by one square.
    SendCmd(.cmd_to_send(16'h43F1), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Check that a movement acknowledge is received from the DUT.
    ChkAck(.resp_rdy(resp_rdy), .clk(clk), .resp(resp));

    // Check if Knight moved to desired position on board TODO: Complete ChkPos task

    ///////////////////////////////////////////////////////////////////
    // TEST 4: Test moving east by one square from center           //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 5: Test moving north by one square from center          //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 6: Test moving west by one square from center           //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 7: Test moving south by one square from center          //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 8: Test moving south by one square from center          //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 9: Test moving north by four squares from south edge    //
    /////////////////////////////////////////////////////////////////
    //TODO Can be a random position on the edge

    ///////////////////////////////////////////////////////////////////
    // TEST 10: Test moving east by four squares from west edge     //
    /////////////////////////////////////////////////////////////////
    
    ///////////////////////////////////////////////////////////////////
    // TEST 11: Test moving west by three squares                   //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 12: Test moving south by three squares                  //
    /////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////
    // TEST 13-xx: Test moving in L-shaped moves from different positions    //
    /////////////////////////////////////////////////////////////////
    //TODO: 

    ///////////////////////////////////////////////////////////////////
    // TEST xx: Test first few moves of tour                        //
    /////////////////////////////////////////////////////////////////

  end
  
  always
    #5 clk = ~clk;
  
endmodule


