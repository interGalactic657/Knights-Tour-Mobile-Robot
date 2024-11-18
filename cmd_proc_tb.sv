///////////////////////////////////////////////////////////////
// cmd_proc_tb.sv                                            //
// This testbench simulates the PID controller,              //
// testing its functionality by using stimulus vectors       //
// and checking output using expected response vectors.      //
///////////////////////////////////////////////////////////////
module cmd_proc_tb();
  
  // Common signals for all DUTs
  logic clk;                    // System clock signal.
  logic rst_n;                  // Asynchronous active low reset.

  ///////////////////////////////
  // RemoteComm signals
  ///////////////////////////////
  logic snd_cmd;
  logic [15:0] cmd_sent;
  logic cmd_rx;
  logic cmd_tx;
  logic cmd_snt;
  logic resp_rdy;

  ///////////////////////////////
  // UART_wrapper signals
  ///////////////////////////////
  logic clr_cmd_rdy;
  logic [15:0] cmd_received;
  logic cmd_rdy;
  logic send_resp;
  logic resp;
  logic trmt;

  ///////////////////////////////
  // inert_intf signals
  ///////////////////////////////
  logic strt_cal;
  logic cal_done;
  logic [11:0] heading;
  logic heading_rdy;
  logic lftIR;
  logic rghtIR;
  logic SS_n;
  logic SCLK;
  logic MOSI;
  logic MISO;
  logic INT;

  ///////////////////////////////
  // cmd_proc signals
  ///////////////////////////////
  logic moving;
  logic [11:0] error;
  logic [9:0] frwrd;
  logic [10:0] lft_spd;
  logic [10:0] rght_spd;
  logic tour_go;
  logic fanfare_go;
  logic cntrIR;

  /////////////////////////////////////////////////
  // Instantiate the (DUTs) and simulate inputs //
  ///////////////////////////////////////////////

  // Instantiate RemoteComm. 
  RemoteComm iRemoteComm (
    .clk(clk), 
    .rst_n(rst_n), 
    .snd_cmd(snd_cmd), 
    .cmd(cmd_sent),
    .RX(cmd_rx), 
    .TX(cmd_tx), 
    .resp(), 
    .resp_rdy(resp_rdy), 
    .cmd_snt(cmd_snt)
  );

  // Instantiate UART_wrapper. 
  UART_wrapper iUART_wrapper(
    .clk(clk), 
    .rst_n(rst_n), 
    .clr_cmd_rdy(clr_cmd_rdy), 
    .trmt(trmt), 
    .RX(cmd_tx), 
    .TX(cmd_rx), 
    .resp(8'hA5), 
    .cmd(cmd_received), 
    .cmd_rdy(cmd_rdy), 
    .tx_done()
  );

  // Instantiate the inertial interface (iINERT) module.
  inert_intf iINERT(
    .clk(clk), 
    .rst_n(rst_n), 
    .strt_cal(strt_cal), 
    .cal_done(cal_done), 
    .heading(heading), 
    .rdy(heading_rdy), 
    .lftIR(lftIR), 
    .rghtIR(rghtIR), 
    .SS_n(SS_n), 
    .SCLK(SCLK), 
    .MOSI(MOSI), 
    .MISO(MISO), 
    .INT(INT),
    .moving(moving)
  );

  // Instantiate the NEMO gyro sensor (iNEMO).
  SPI_iNEMO3 iNEMO(
    .SS_n(SS_n), 
    .SCLK(SCLK), 
    .MISO(MISO), 
    .MOSI(MOSI), 
    .INT(INT)
  );

  // Instantiate the command processor module.
  cmd_proc iCMD_PROC (
    .clk(clk),
    .rst_n(rst_n),
    .cmd(cmd_sent),
    .cmd_rdy(cmd_rdy),
    .clr_cmd_rdy(clr_cmd_rdy),
    .send_resp(send_resp),
    .strt_cal(strt_cal),
    .cal_done(cal_done),
    .heading(heading),
    .heading_rdy(heading_rdy),
    .lftIR(lftIR),
    .cntrIR(cntrIR),
    .rghtIR(rghtIR),
    .error(error),
    .frwrd(frwrd),
    .moving(moving),
    .tour_go(tour_go),
    .fanfare_go(fanfare_go)
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

  ///////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses //
  /////////////////////////////////////////////////////////
  initial begin
    clk = 1'b0;                 // Initially clock is low
    rst_n = 1'b0;               // Reset the machines
    snd_cmd = 1'b0;             // Initially is low, i.e., inactive
    cmd_sent = 16'h2000;        // Command to start the calibration of the Knight's gyro
    trmt = 1'b0;                // Initially we are not transmitting the response back to the Bluetooth module
    lftIR = 1'b0;               // Initially the Knight doesn't veer to the left
    cntrIR = 1'b0;              // Initially the Knight doesn't see any guard rail
    rghtIR = 1'b0;              // Initially the Knight doesn't veer to the right
    
    // Wait 1.5 clocks for reset
    @(posedge clk);
    @(negedge clk) begin 
      rst_n = 1'b1;             // Deassert reset on a negative edge of clock
      snd_cmd = 1'b1;           // Assert snd_cmd and begin transmission
    end

    @(negedge clk) snd_cmd = 1'b0; // Deassert snd_cmd after one clock cycle

    ////////////////////////////////////////////////////////////////////////
    // TEST 1: Test whether the calibrate command is processed correctly //
    //////////////////////////////////////////////////////////////////////
    // Wait for resp_rdy to be asserted, or timeout.
    timeout_task(resp_rdy, 1000050, "resp_rdy");

    // Wait for cal_done to be asserted, or timeout after a 1000100 clocks.
    timeout_task(cal_done, 1000100, "cal_done");

    ////////////////////////////////////////////////////////////////////
    //// TEST 2: Test whether the move command is processed correctly //
    ////////////////////////////////////////////////////////////////////
    cmd_sent = 16'h4001;               // Command to move the Knight by 1 square to the north.
    @(negedge clk) snd_cmd = 1'b1;     // assert snd_cmd and begin transmission
    // Deassert snd_cmd after one clock cycle.
    @(negedge clk) snd_cmd = 1'b0;

    // Wait 60000 clock cycles, and ensure that 2 bytes are transmitted.
    timeout_task(cmd_snt, 60000, "cmd_snt");

    // Wait for resp_rdy to be asserted, or timeout slightly after 1000000 clocks.
    timeout_resp(resp_rdy, 1000050, "resp_rdy");

    // The forward speed register should be cleared to 0 initially right after the command was sent.
    if (frwrd !== 10'h000) begin
      $display("ERROR: frwrd should have been cleared to 10'h000 but was 0x%h", frwrd);
      $stop();
    end

    // Wait for 10 positive edges on heading ready, indicating 10 new readings. 
    repeat(10) @(posedge heading_rdy);

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

    // Wait for 20 more positive edges on heading ready, indicating 20 new readings. 
    repeat(20) @(posedge heading_rdy);

    // After 20 more positive edges on heading ready, frwrd speed should be saturated to the maximum speed.
    if (frwrd !== 10'h300) begin
      $display("ERROR: frwrd speed should have been saturated to the maximum speed but was 0x%h.", frwrd);
      $stop();
    end

    // Give a pulse on the cntrIR sensor.
    cntrIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Say it no longer sees the pulse on cntrIR.
    cntrIR = 1'b0;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // frwrd speed should still be saturated to the maximum speed.
    if (frwrd !== 10'h300) begin
      $display("ERROR: frwrd speed should have stayed saturated after pulse on cntrIR.");
      $stop();
    end

    // Give a second pulse on the cntrIR sensor indicating the Knight entered a square.
    cntrIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Say it no longer sees the pulse on cntrIR.
    cntrIR = 1'b0;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // After 10 clock cycles, the forward speed register should have been decremented by 10'd640.
    if (frwrd !== 10'h080) begin
        $display("ERROR: frwrd speed should have been decremented to 10'h080 but was %h", frwrd);
        $stop();
    end

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // The moving signal should be low as frwrd speed is zeroed out by now.
    if (moving !== 1'b0) begin
        $display("ERROR: moving should have been deasserted as the Knight completely slowed down but was not.");
        $stop();
    end

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // The moving signal should be low as frwrd speed is zeroed out by now.
    if (moving !== 1'b0) begin
        $display("ERROR: moving should have been deasserted as the Knight completely slowed down but was not.");
        $stop();
    end
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //// TEST 3: Test whether the move command is processed correctly along with a nudge factor //
    /////////////////////////////////////////////////////////////////////////////////////////////
    cmd_sent = 16'h4001;               // Command to move the Knight by 1 square to the north.
    @(negedge clk) snd_cmd = 1'b1;     // Assert snd_cmd and begin transmission
    // Deassert snd_cmd after one clock cycle.
    @(negedge clk) snd_cmd = 1'b0;

    // Wait 60000 clock cycles, and ensure that 2 bytes are transmitted.
    timeout_task(cmd_snt, 60000, "cmd_snt");

    // Wait for resp_rdy to be asserted, or timeout slightly after 1000000 clocks.
    timeout_resp(resp_rdy, 1000050, "resp_rdy");

    // Wait for the Knight to be moving. 
    @(posedge moving);

    // Say the Knight was veering slightly more towards the left.
    lftIR = 1'b1;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // Say it no longer sees the pulse on lftIR.
    lftIR = 1'b0;

    // Wait a couple of clock cycles.
    repeat(5) @(posedge clk);

    // The error should have a large disturbance after the Knight veers too much to the left.
    if (iCMD_PROC.error_abs > 12'h02C) begin
        $display("ERROR: the error term should have a great amount of disturbance but does not.");
        $stop();
    end
  end

always
  #5 clk = ~clk; // toggle clock every 5 time units

endmodule
