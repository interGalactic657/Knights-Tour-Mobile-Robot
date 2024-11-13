///////////////////////////////////////////////////////////////
// cmd_proc_tb.sv                                            //
// This testbench simulates the PID controller,              //
// testing its functionality by using stimulus vectors       //
// and checking output using expected response vectors.      //
///////////////////////////////////////////////////////////////
module cmd_proc_tb();
  
  // Common signals used across multiple DUTs
  logic clk;                    // System clock signal.
  logic rst_n;                  // Asynchronous active low reset.

  // Signals for the RemoteComm instance
  logic snd_cmd;                // Signal to send a command.
  logic cmd_sent;               // Command sent status.
  logic cmd_rx;                 // Command receive line (from UART).
  logic cmd_tx;                 // Command transmit line (to UART).
  logic cmd_snt;                // Command sent indicator.

  // Signals for the UART_wrapper instance
  logic clr_cmd_rdy;            // Clears command ready signal.
  logic cmd_received;           // Command received from UART.
  logic cmd_rdy;                // Command ready status.

  // Signals for the inert_intf (iINERT) module
  logic strt_cal;               // Start calibration signal.
  logic cal_done;               // Calibration complete signal.
  logic signed [11:0] heading;  // 12-bit signed heading value.
  logic rdy;                    // Ready signal.
  logic lftIR;                  // Left IR sensor status.
  logic rghtIR;                 // Right IR sensor status.
  logic SS_n;                   // Active low serf select signal.
  logic SCLK;                   // SPI serial clock signal.
  logic MOSI;                   // SPI Master Out Serf In.
  logic MISO;                   // SPI Master In Serf Out.
  logic INT;                    // SPI interrupt line.
  logic moving;                 // Indicates whether the Knight is moving.

  // Signals for the cmd_proc instance
  logic send_resp;              // Send response signal.
  logic heading_rdy;            // Heading ready signal.
  logic cntrIR;                 // Center IR sensor status.
  logic signed [11:0] error;    // Signed 12-bit error term.
  logic signed [9:0] frwrd;     // Forward speed value for motor speed calculation.
  logic tour_go;                // Start knight’s tour signal.
  logic fanfare_go;             // Signal to trigger fanfare.

  // Additional signals for response
  logic signed [10:0] lft_spd;  // Left motor speed.
  logic signed [10:0] rght_spd; // Right motor speed.

  // Memory to hold stimulus and expected response vectors
  logic [24:0] stim[0:1999];    // 2000 stimulus vectors, 25-bits wide.
  logic [21:0] resp[0:1999];    // 2000 expected responses, 22-bits wide.

  integer i;                    // Loop variable to iterate through stimulus vectors.

  ///////////////////////////////////////////////////////////////////////
  // Instantiate the Command Processor (DUT) and simulate its inputs   //
  ///////////////////////////////////////////////////////////////////////

  // Instantiate RemoteComm
  RemoteComm iRemoteComm (
    .clk(clk), 
    .rst_n(rst_n), 
    .snd_cmd(snd_cmd), 
    .cmd(cmd_sent),
    .RX(cmd_rx), 
    .TX(cmd_tx), 
    .resp(),
    .resp_rdy(), 
    .cmd_snt(cmd_snt)
  );

  // Instantiate UART_wrapper
  UART_wrapper iUART_wrapper(
    .clk(clk), 
    .rst_n(rst_n), 
    .clr_cmd_rdy(clr_cmd_rdy), 
    .trmt(1'b0), 
    .RX(cmd_tx), 
    .TX(cmd_rx), 
    .resp(8'h00), 
    .cmd(cmd_received), 
    .cmd_rdy(cmd_rdy), 
    .tx_done()
  );

  // Instantiate the inertial interface (iINERT) module
  inert_intf iINERT(
    .clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done), 
    .heading(heading), .rdy(rdy), .lftIR(lftIR), .rghtIR(rghtIR), 
    .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT),
    .moving(moving)
  );

  // Instantiate the NEMO gyro sensor (iNEMO)
  SPI_iNEMO3 iNEMO(
    .SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI), .INT(INT)
  );

  // Instantiate the command processor module (iCMD_PROC)
  cmd_proc iCMD_PROC (
    .clk(clk),
    .rst_n(rst_n),
    .cmd(cmd_received),
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

  ///////////////////////////////////////////////////////////////////
  // Test procedure to apply stimulus and check responses          //
  ///////////////////////////////////////////////////////////////////
  initial begin
    // Initialize signals and load stimulus here
  end

  always
    #5 clk = ~clk; // toggle clock every 5 time units

endmodule
