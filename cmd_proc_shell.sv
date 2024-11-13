module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
                frwrd,moving,tour_go,fanfare_go);
                
  parameter FAST_SIM = 1;              // speeds up incrementing of frwrd register for faster simulation
                
  input clk,rst_n;                     // 50MHz clock and asynch active low reset

  input [15:0] cmd;                    // command from BLE
  input cmd_rdy;                       // command ready
  output logic clr_cmd_rdy;            // mark command as consumed
  output logic send_resp;              // command finished, send_response via UART_wrapper/BT

  output logic strt_cal;               // initiate calibration of gyro
  input cal_done;                      // calibration of gyro done
  input signed [11:0] heading;         // heading from gyro
  input heading_rdy;                   // pulses high 1 clk for valid heading reading

  output logic moving;                 // asserted when moving (allows yaw integration)

  output reg signed [11:0] error;      // error to PID (heading - desired_heading)
  output reg [9:0] frwrd;              // forward speed register
  
  input lftIR;                         // nudge error +
  input cntrIR;                        // center IR reading (have I passed a line)
  input rghtIR;                        // nudge error -

  output logic tour_go;                // pulse to initiate TourCmd block
  output logic fanfare_go;             // kick off the "Charge!" fanfare on piezo

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 6 states in total.
  typedef enum logic [2:0] {IDLE, START_TOUR, CALIBRATE, MOVE, INCR, DECR} state_t;
  /////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  ////////////////////////////// Forward Register Logic ////////////////////////////////////
  logic zero;  // The forward register is zero when cleared or decremented all the way.
  logic max_spd; // The forward register has reached its max speed when the 2 most significant bits are ones.
  ///////////////////////// Square Count Logic ///////////////////////////////////////////
  logic [3:0] pulse_cnt;     // Indicates number of times cntrIR went high when moving the Knight, max 16 times.
  logic [2:0] square_cnt;    // The number of squares the Knight moved on the board.
  logic move_done;           // Indicates that a move is completed by the Knight.
  logic cntrIR_step;         // Metastable cntrIR signal from the IR sensor.
	logic cntrIR_stable_prev;  // Stabilized cntrIR signal from the IR sensor.
  logic cntrIR_stable_curr;  // Used to detect rising edge on the cntrIR signal.
  ////////////////////////////// PID Interface Logic ////////////////////////////////////
  logic lftIR_step;       // Metastable lftIR signal from the inertial sensor.
  logic lftIR_stable;     // Stabilized lftIR signal from the inertial sensor.
  logic rghtIR_step;       // Metastable rghtIR signal from the inertial sensor.
  logic rghtIR_stable;     // Stabilized rghtIR signal from the inertial sensor.
  logic signed [11:0] desired_heading;     // Compute the desired heading based on the command given.
  logic signed [11:0] err_nudge; // An error offset term to correct for when the robot wanders.
  ///////////////////////////// State Machine //////////////////////////////////////
  logic strt_cal;            // Initiate claibration of yaw readings.
  logic move_cmd;            // The command that tells Knight to move from the state machine.
  logic clr_frwrd;           // Tells the Knight to ramp up its speed starting from 0.
  logic inc_frwrd;           // Tells the Knight to ramp up its speed.
  logic dec_frwrd;           // Tells the Knight to decrease up its speed.
  state_t state;             // Holds the current state.
	state_t nxt_state;         // Holds the next state.
  //////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////
  // Implements forward speed register to move the Knight //
  /////////////////////////////////////////////////////////
  // The forward register is zero when cleared.
  assign zero = (frwrd == 10'h000);

  // The forward register has reached its max speed 
  // when the 2 most significant bits are ones.
  assign max_spd = &frwrd[9:8];

  // Implement the forward speed register of the Knight to move it forward or slow down.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      frwrd <= 10'h000; // Clear the register asynchronously.
    else if (clr_frwrd)
      frwrd <= 10'h000; // Clear the register when we are done with a movement.
    else if (heading_rdy) begin // Only increment or decrement the forward register when a new heading is ready.
      if (inc_frwrd) begin
        if (!max_spd) begin // Only increment the register if we are not at the max speed.
        generate // Increment frwrd by different amounts based on whether FAST_SIM is enabled.
          if (FAST_SIM)
            frwrd <= frwrd + 10'h020;
          else 
            frwrd <= frwrd + 10'h003;
        endgenerate
        end
      end else if (dec_frwrd) begin
        if (!zero) begin // Only decrement the register if we are not at the minimum speed. 
          generate // Decrement frwrd by different amounts based on whether FAST_SIM is enabled.
          if (FAST_SIM)
            frwrd <= frwrd - 10'h040;
          else 
            frwrd <= frwrd - 10'h006;
          endgenerate
        end
      end
    end
  end
  //////////////////////////////////////////////////////////////////////////
 
  ////////////////////////////////////////////////////////
  // Counts the number of squares the Knight has moved //
  //////////////////////////////////////////////////////
  // Implement rising edge detector to check when cntrIR pulse goes high.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      cntrIR_step <= 1'b0;          // Reset the cntrIR metastable value.
      cntrIR_stable_prev <= 1'b0;   // Reset the cntrIR stable value.
      cntrIR_stable_curr <= 1'b0;   // Reset the cntrIR edge detection flop.
    end else begin
      cntrIR_step <= cntrIR;                    // Flop the cntrIR signal to correct metastability.
      cntrIR_stable_prev <= cntrIR_step;        // The synchronized cntrIR signal with the system clock.
      cntrIR_stable_curr <= cntrIR_stable_prev; // Used to detect rising edge on cntrIR pulse.
    end
  end

  // A pulse is detected from the cntrIR sensor when the previous value was low and current value is high.
  assign pulse_detected = ~cntrIR_stable_prev & cntrIR_stable_curr;

  // Implement counter to count number squares moved by the Knight.
  always_ff @(posedge clk) begin
    // Load in the number of squares to move when the command is asserted, else hold current value.
    square_cnt <= (move_cmd) ? cmd[2:0] : square_cnt;  
  end

  // Implement counter to count number of times the cntrIR pulse went high. 
  always_ff @(posedge clk) begin
    pulse_cnt <= (move_cmd)       ? 4'h0           : // Reset to 0 initially when begining a move.
                 (pulse_detected) ? pulse_cnt + 1  : // Increment the pulse count whenever we detect that cntrIR went high.
                 pulse_cnt;                          // Otherwise hold current value.
  end

  // Compare whether the pulse count detected is 2 times the number of sqaures requested to move,
  // to indicate that a move is complete.
	assign move_done = (pulse_cnt == {square_cnt, 1'b0});
  //////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
  // Interfaces with the PID to move the Knight in the right direction  //
  ///////////////////////////////////////////////////////////////////////
  // Stabalizes lftIR to synchronize with the system clock. 
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      lftIR_step <= 1'b0;   // Reset the lftIR metastable value.
      lftIR_stable <= 1'b0; // Reset the lftIR stable value.
    end else begin
      lftIR_step <= lftIR;        // Flop the lftIR signal to correct metastability.
      lftIR_stable <= lftIR_step; // The synchronized lftIR signal with the system clock.
    end
  end

  // Stabalizes rghtIR to synchronize with the system clock.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      rghtIR_step <= 1'b0;        // Reset the rghtIR metastable value.
      rghtIR_stable <= 1'b0;       // Reset the rghtIR stable value.
    end else begin
      rghtIR_step <= rghtIR;        // Flop the rghtIR signal to correct metastability.
      rghtIR_stable <= rghtIR_step; // The synchronized rghtIR signal with the system clock.
    end
  end

  // Form the nudge factor based on whether the Knight veers too much to the left or right. 
  generate
    // Generate a different nudge factor when FAST_SIM is enabled.
    if (FAST_SIM)
      // Whenever lftIR goes high we add a positive nudge factor, and whenever rghtIR goes high,
      // we add a negative nudge factor.
      assign err_nudge = (lftIR_stable)  ? 12'h05F : 
                         (rghtIR_stable) ? 12'hFA1 : 
                         12'h000;
    else
      assign err_nudge = (lftIR_stable)  ? 12'h1FF : 
                         (rghtIR_stable) ? 12'hE00 : 
                         12'h000;
  endgenerate

  // Compute the desired heading based on the command.
  always_ff @(posedge clk) begin
    // If the Knight is required to move, take the heading from the command, and if it is non-zero append 0xF
    // to form the desired heading else, it is zero.
    desired_heading <= (move_cmd) ? ((cmd[11:4] == 8'h00) ? 12'h000 : {cmd[11:4], 4'hF}) : desired_heading;  
  end

  // Form the error term as the difference of the actual and desired heading with the nudge factor.
	assign error = heading - desired_heading + err_nudge;
  //////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////
	// Implements State Machine Logic //
	///////////////////////////////////

  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        state <= IDLE; // Reset into the idle state if machine is reset.
      else
        state <= nxt_state; // Store the next state as the current state by default.
  end

  //////////////////////////////////////////////////////////////////////////////////////////
	// Implements the combinational state transition and output logic of the state machine.//
	////////////////////////////////////////////////////////////////////////////////////////
	always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state; // By default, assume we are in the current state.
    strt_cal = 1'b0;   // Start calibration signal (disabled by default)
    move_cmd = 1'b0;   // Move command signal (disabled by default)
    clr_frwrd = 1'b0;  // Clear forward speed register (disabled by default)
    inc_frwrd = 1'b0;  // Increment forward speed register command (disabled by default)
    dec_frwrd = 1'b0;  // Decrement forward speed register (disabled by default)
    tour_go = 1'b0;    // Start the Knight's tour (disabled by default)
    send_resp = 1'b0;  // Send acknowledgment to the Bluetooth module (disabled by default)

    case (state)
    default : begin // IDLE state - waits for a command
      if (cmd_rdy) begin // If a command is ready
        if (cmd[15:12] == 4'b0010)
          nxt_state = START_TOUR; // Command to start Knight's tour
        else if (cmd[15:12] == 4'b0010) begin
          nxt_state = CALIBRATE; // Command to start calibration
          strt_cal = 1'b1; // Enable calibration
        end
        else if (cmd[15:12] == 4'b0100 || cmd[15:12] == 4'b0101)
          nxt_state = MOVE; // Command to move forward or backward
        clr_cmd_rdy = 1'b1; // Clear command ready signal
      end        
    end
    
    START_TOUR : begin // State to initiate Knight's tour
      nxt_state = IDLE; // Return to IDLE after starting
      tour_go = 1'b1; // Enable Knight's tour
    end

    CALIBRATE : begin // State for calibration process
      if (cal_done) begin // Wait until calibration is complete
        send_resp = 1'b1; // Send acknowledgment to Bluetooth
        nxt_state = IDLE; // Return to IDLE
      end
    end

    MOVE : begin // State to start moving process
      if (error < $signed(12'h02C) || error < $signed(12'hFFD4)) begin
        move_cmd = 1'b1; // Command to move
        clr_frwrd = 1'b1; // Clear forward command
        nxt_state = INCR; // Move to increment state
      end
    end

    INCR : begin // State to increment speed
      inc_frwrd = 1'b1; // Increment forward speed
      if (move_done) begin // If movement is complete
        dec_frwrd = 1'b1; // Decrement speed
        if (cmd[15:12] == 4'b0100)
          fanfare_go = 1'b0; // Turn off fanfare for normal move
        else if (cmd[15:12] == 4'b0101)
          fanfare_go = 1'b1; // Turn on fanfare for special move
        nxt_state = DECR; // Go to decrement state
      end else 
        move_cmd = 1'b1; // Continue moving
    end

    DECR : begin // State to decrement speed
      if (zero) begin // If forward speed reaches zero
        send_resp = 1'b1; // Send acknowledgment to Bluetooth
        nxt_state = IDLE; // Return to IDLE
      end else
        move_cmd = 1'b1; // Continue moving if not zero
    end
  endcase
  end

  
endmodule