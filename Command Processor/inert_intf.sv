///////////////////////////////////////////////////////
// inert_intf.sv                                    //
// Interfaces with ST 6-axis inertial sensor. In   //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n; // 50MHz system clock and asynchronous active low reset.
  input MISO;	// SPI input from the inertial sensor.
  input INT;	// Goes high when measurement ready.
  input strt_cal; // Initiate claibration of yaw readings.
  input moving;	// Only integrate yaw when going.
  input lftIR,rghtIR; // Gaurdrail sensors.
  
  output cal_done; // Pulses high for 1 clock when calibration done.
  output signed [11:0] heading;	// Heading of robot. 000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW.
  output rdy;	// Goes high for 1 clock when new outputs ready (from inertial_integrator).
  output SS_n,SCLK,MOSI; // SPI outputs.

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 6 states in total, INIT1, INIT2, INIT3, INTW, YAWH, YAWL.
  typedef enum logic [2:0] {INIT1, INIT2, INIT3, INTW, YAWH, YAWL} state_t;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic set_vld;        // Asserted by the state machine to set the vld signal.
  logic vld;            // Valid signal provided to the inertial_integrator to start computation.
  logic [15:0] yaw_rt;  // 2 byte yaw_rt to be sent to the intertial integrator.
  logic snd;            // Asserted high for 1 clk by SM to initiate SPI transaction.
  logic [15:0] cmd;     // Data being sent from the state machine to the inertial sensor.
  logic done;           // Asserted when SPI transaction is complete.
  logic [15:0] resp;    // Data from SPI serf. For inertial sensor we will only ever use bits [7:0].
  logic [7:0] high_reg; // Holds the first byte received from the SPI monarch.
  logic C_Y_H, C_Y_L;   // Asserted by the state machine to determine which byte we received.
  logic INT_step;       // Metastable INT signal from the inertial sensor.
  logic INT_stable;     // Stabilized INT signal from the inertial sensor.
  logic [15:0] timer;   // 16-bit timer that increments every clock cycle.
  logic full;           // Asserted when  the timer is full.
  state_t state;        // Holds the current state.
	state_t nxt_state;    // Holds the next state.
  ///////////////////////////////////////////////

  //////////////////////////////////////////
  // Instantiate the inertal system DUTs //
  ////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  
  // and acceleration info and produces a heading reading.
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading), .LED());

  // Instantiate SPI monarch to send and receive commands. 
  SPI_mnrch iSPI(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd),
                    .cmd(cmd), .done(done), .resp(resp));
  ///////////////////////////////////////////////////////////////////////////////////////////////////////

  // Stabalizes INT to synchronize with the system clock 
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      INT_step <= 1'b0; // Reset the INT metastable value.
      INT_stable <= 1'b0; // Reset the INT stable value.
    end else begin
      INT_step <= INT; // Flop the INT signal to correct metastability.
      INT_stable <= INT_step; // The synchronized INT signal with the system clock.
    end
  end

  // Timer to wait for the configuration of the MEMs gyro.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      timer <= 16'h0000; // Reset timer to 0 initially.
    else
      timer <= timer + 1'b1; // Increment the timer every clock cycle.
  end

  // The timer is full when the register contains all 1's.
  assign full = &timer;

  // Capture the high and low bytes of the YAW register from the sensor as recieved.
  always_ff @(posedge clk) begin
    if(C_Y_H)
      high_reg <= resp[7:0];           // Capture the byte as received from the yaw_h register.
    else if (C_Y_L)
      yaw_rt <= {high_reg, resp[7:0]}; //  Package both high byte and low byte as yaw_rt as received from the sensor.
  end
  
  ////////////////////////////////////
	// Implement State Machine Logic //
	//////////////////////////////////

  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      state <= INIT1; // Reset into the INT1 state if machine is reset.
    else
      state <= nxt_state; // Store the next state as the current state by default.
  end

  // Implements the delay flop for the vld signal after both bytes were read from the sensor.
  always_ff @(posedge clk) begin
    vld <= set_vld;
  end

  //////////////////////////////////////////////////////////////////////////////////////////
	// Implements the combinational state transition and output logic of the state machine.//
	////////////////////////////////////////////////////////////////////////////////////////
	always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state; // By default, assume we are in the current state. 
    cmd = 16'h0000; // By default, assume we are not sneding meaningful data across the SPI. 
    snd = 1'b0; // By default, we are not sending any data across the SPI.
    set_vld = 1'b0; // By default, we don't have valid data for the inertial integrator yet.
    C_Y_H = 1'b0; // By default, we did not receive the high byte from the yaw register of the sensor.
    C_Y_L = 1'b0; // By default, we did not receive the low byte from the yaw register of the sensor.

    case (state)
      INIT2 : begin
        cmd = 16'h1160; // Setup gyro for 416Hz data rate, +/- 250°/sec range.
        if (done) begin // Wait till the SPI transaction is complete.
          snd = 1'b1; // Send the data across SPI.
          nxt_state = INIT3; // Shift to the next state to turn rounding on for gyro readings.
        end
      end
      INIT3 : begin
        cmd = 16'h1440; // Turn rounding on for gyro readings.
        if (done) begin // Wait till the SPI transaction is complete.
          snd = 1'b1; // Send the data across SPI.
          nxt_state = INTW; // Shift to the next state to wait for valid data as received by the gyro.
        end
      end
      INTW : begin
        cmd = 16'hA700; // Read the yaw rate high register from the gyro.
        if (INT_stable) begin // Wait for an interrupt to occur to read the acceleration registers.
          snd = 1'b1; // Send the data across SPI.
          nxt_state = YAWH; // Shift to the next state to read the yaw rate low register.
        end
      end
      YAWH : begin
        cmd = 16'hA600; // Read the yaw rate low register from the gyro.
        if (done) begin // Wait till the SPI transaction is complete.
          C_Y_H = 1'b1; // Assert that the high byte is received to be read and stored into the holding register.
          snd = 1'b1; // Send the data across SPI.
          nxt_state = YAWL; // Shift to the next state to wait for the low byte to be read.
        end
      end
      YAWL : begin
        if (done) begin // Wait till the SPI transaction is complete.
          C_Y_L = 1'b1; // Assert that the high byte is received to be read and stored into the holding register.
          set_vld = 1'b1; // Assert that data is ready for the inertial integrator to perform calibration.
          nxt_state = INTW; // Shift to the next state to wait for new data to be received.
        end
      end
      default : begin   // Used as the INIT1 state and checks if timer is full, else stay in the current state. 
        cmd = 16'h0D02; // Configure the sensor to genrate an interrupt whenever new data is ready.
        if (full) begin // Wait till the gyro is booted up and configured correctly.
          snd = 1'b1; // Send the data across SPI.
          nxt_state = INIT2; // Shift to the next state to configure the reading rate range.
        end
      end
    endcase
  end
endmodule