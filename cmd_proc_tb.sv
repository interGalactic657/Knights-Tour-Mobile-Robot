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

  // Memory to hold stimulus and expected response vectors
  logic [24:0] stim[0:1999];    // 2000 stimulus vectors, 25-bits wide.
  logic [21:0] resp[0:1999];    // 2000 expected responses, 22-bits wide.
  
  integer i;                    // Loop variable to iterate through stimulus vectors.

  ////////////////////////////////////////////////////////////////////////
  // Instantiate the Command Processor (DUT) and simulate its inputs //
  //////////////////////////////////////////////////////////////////////

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
    .lftIR(1'b0), 
    .rghtIR(1'b0), 
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
    .lftIR(1'b0),
    .cntrIR(cntrIR),
    .rghtIR(1'b0),
    .error(error),
    .frwrd(frwrd),
    .moving(moving),
    .tour_go(tour_go),
    .fanfare_go(fanfare_go)
  );

  ///////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses //
  /////////////////////////////////////////////////////////
  initial begin
    clk = 1'b0; // initially clock is low
	rst_n = 1'b0; // reset the machines
    snd_cmd = 1'b0; // initially is low, i.e. inactive
    cmd_sent = 16'h2000; // Command to start the calibration of the Knight's gyro.
    trmt = 1'b0; // Initially we are not transmitting the response back to the bluetooth module.
    cntrIR = 1'b0; // Initially the Knight doesn't see any guard rail.

    ////////////////////////////////////////////////////////////////////////
    // TEST 1: Test whether the calibrate command is processed correctly //
    //////////////////////////////////////////////////////////////////////
    fork
      begin : timeout_cal
        // Wait for a million clock cycles for cal_done to be asserted.
        repeat(1000000) @(posedge clk);
        // If cal_done is not asserted, display error.
        $display("ERROR: cal_done not getting asserted and/or held at its value.");
        $stop(); // Stop simulation on error.
      end : timeout_cal
      begin : timeout_resp
        // Wait for a million clock cycles for response to be ready.
        repeat(1000000) @(posedge clk);
        // If resp_rdy is not asserted, display error.
        $display("ERROR: resp_rdy not getting asserted and/or held at its value.");
        $stop(); // Stop simulation on error.
      end : timeout_resp
      begin
        // Wait for the cal_done signal to be asserted to indicate calibration completion.
        @(posedge cal_done)
          disable timeout_cal; // Disable timeout if cal_done is asserted.
        // Wait for the resp_rdy signal to be asserted to indicate an acknowledge from the processor.
        @(posedge resp_rdy)
          disable timeout_resp; // Disable timeout if resp_rdy is asserted.
      end
    join

  end

  always
    #5 clk = ~clk; // toggle clock every 5 time units

endmodule
