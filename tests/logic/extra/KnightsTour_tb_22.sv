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
  bit found_offset;

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
  KnightPhysics #(15'h2800, 15'h2800) iPHYS(.clk(clk), .RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
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

    // Initially the y_offset is not found.
    found_offset = 1'b0;

    /////////////////////////////////////////////////////////
    // Test the KnightsTour starting at coordinate (2,2)  //
    ///////////////////////////////////////////////////////
    // Send a command to start the KnightsTour from (2,2).
    SendCmd(.cmd_to_send(16'h7020), .cmd(cmd), .clk(clk), .send_cmd(send_cmd), .cmd_sent(cmd_sent));

    // Wait till the Knight found out its position on the board.
    ChkOffset(.clk(clk), .tour_go(iDUT.tour_go), .target_xx(3'h2), .actual_xx(iPHYS.xx), .target_yy(3'h2), .actual_yy(iPHYS.yy));

    // The y_offset is correctly found.
    found_offset = 1'b1;

    // Wait till the solution is complete or times out.
    WaitComputeSol(.start_tour(iDUT.start_tour), .clk(clk));

    // Indicate that the Knight's Tour is starting from (2,2)
    $display("KnightsTour starting at coordinate: (2,2)");

    // Wait till the KnightsTour has finished.
    WaitTourDone(.clk(clk), .send_resp(iDUT.send_resp), .resp_rdy(iRMT.resp_rdy), .resp(iRMT.resp), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy), .mv_indx(iDUT.mv_indx), .fanfare_go(iDUT.fanfare_go));

    // If we reached here, that means all test cases were successful.
    $stop();
  end

  // Checks that we are never off the board.
  always @(negedge clk)
    // Ignore checking if the Knight is off the board if we didn't find the y_offset yet.
    if (found_offset)
      ChkOffBoard(.clk(clk), .RST_n(RST_n), .actual_xx(iPHYS.xx), .actual_yy(iPHYS.yy));

  always
    #5 clk = ~clk;

endmodule
