///////////////////////////////////////////////////
// cmd_proc.sv                                   //
// This is the command processing unit of        //
// the Knight robot dictating how it should      //
// respond given a command from a Bluetooth      //
// module.                                       //
///////////////////////////////////////////////////
module cmd_proc(
    clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, send_resp, strt_cal,
    cal_done, heading, heading_rdy, lftIR, cntrIR, rghtIR, error,
    frwrd, moving, tour_go, fanfare_go
);

  parameter FAST_SIM = 1;                 // speeds up incrementing of frwrd register for faster simulation

  input         clk, rst_n;               // 50MHz clock and asynch active low reset
  input [15:0]  cmd;                      // command from BLE
  input         cmd_rdy;                  // command ready
  output logic  clr_cmd_rdy;              // mark command as consumed
  output logic  send_resp;                // command finished, send_response via UART_wrapper/BT

  output logic  strt_cal;                 // initiate calibration of gyro
  input         cal_done;                 // calibration of gyro done
  input signed [11:0] heading;            // heading from gyro
  input         heading_rdy;              // pulses high 1 clk for valid heading reading

  output logic  moving;                   // asserted when moving (allows yaw integration)

  output reg signed [11:0] error;         // error to PID (heading - desired_heading)
  output reg [9:0] frwrd;                 // forward speed register
  
  input         lftIR;                    // nudge error +
  input         cntrIR;                   // center IR reading (have I passed a line)
  input         rghtIR;                   // nudge error -

  output logic  tour_go;                  // pulse to initiate TourCmd block
  output logic  fanfare_go;               // kick off the "Charge!" fanfare on piezo

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [2:0] {IDLE, CALIBRATE, MOVE, INCR, DECR} state_t;

  ////////////////////////////////////////////
  // Declare command opcodes as enumerated //
  //////////////////////////////////////////
  typedef enum logic [3:0] {CAL = 4'b0010, MOV = 4'b0100, FANFARE = 4'b0101, TOUR = 4'b0110} op_t;

  ///////////////////////////////////
  // Declare any internal signals //
  ///////////////////////////////////
  ////////////////////////////// Forward Register Logic ////////////////////////////////////
  logic zero;                          // The forward register is zero when cleared or decremented all the way.
  logic max_spd;                       // The forward register has reached its max speed when the 2 most significant bits are ones.
  logic [6:0] inc_amt;                 // Amount of speed to increase/ramp up each clock cycle.
  logic [6:0] dec_amt;                 // Amount of speed to decrease/ramp down each clock cycle.
  ///////////////////////// Square Count Logic ///////////////////////////////////////////
  logic [4:0] pulse_cnt;               // Indicates number of times cntrIR went high when moving the Knight, max 16 times.
  logic [3:0] square_cnt;              // The number of squares the Knight moved on the board.
  logic pulse_detected;                // Indicates a rising edge on cntrIR.
  logic move_done;                     // Indicates that a move is completed by the Knight.
  logic cntrIR_prev;                   // Previous cntrIR signal from the IR sensor.
  ////////////////////////////// PID Interface Logic ////////////////////////////////////
  logic signed [11:0] desired_heading; // Compute the desired heading based on the command given.
  logic signed [11:0] err_nudge;       // An error offset term to correct for when the robot wanders.
  logic [11:0] error_abs;              // Absolute value of the error.
  ///////////////////////////// State Machine ////////////////////////////////////////////
  logic move_cmd;                      // The command that tells Knight to move from the state machine.
  logic clr_frwrd;                     // Tells the Knight to ramp up its speed starting from 0.
  logic inc_frwrd;                     // Tells the Knight to ramp up its speed.
  logic dec_frwrd;                     // Tells the Knight to decrease up its speed.
  op_t opcode;                         // Opcode held in cmd[15:12].
  state_t state;                       // Holds the current state.
  state_t nxt_state;                   // Holds the next state.
  ////////////////////////////////////////////////////////////////////////////////////////

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
      frwrd <= 10'h000; // Clear the register when we are beginning a movement.
    else if (heading_rdy) begin // Only increment or decrement the forward register when a new heading is ready.
      if (inc_frwrd) begin
        if (!max_spd) 
          // Only increment the register if we are not at the max speed.  
          frwrd <= frwrd + inc_amt;
      end else if (dec_frwrd) begin
        if (!zero)
          // Only decrement the register if we are not at the minimum speed.  
          frwrd <= frwrd - dec_amt;
      end
    end
  end

  generate // Increment frwrd by different amounts based on whether FAST_SIM is enabled.
    if (FAST_SIM)
      assign inc_amt = 7'h20;
    else 
      assign inc_amt = 7'h03;
  endgenerate

  generate // Decrement frwrd by different amounts based on whether FAST_SIM is enabled.
    if (FAST_SIM)
      assign dec_amt = 7'h40;
    else 
      assign dec_amt = 7'h06;
  endgenerate
  //////////////////////////////////////////////////////////////////////////
 
  ////////////////////////////////////////////////////////
  // Counts the number of squares the Knight has moved //
  //////////////////////////////////////////////////////
  // Implement rising edge detector to check when cntrIR pulse goes high.
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      cntrIR_prev <= 1'b0;   // Reset the cntrIR_prev value.
    else
      cntrIR_prev <= cntrIR; // Used to detect rising edge on cntrIR pulse.
  end

  // A pulse is detected from the cntrIR sensor when the previous value was low and current value is high.
  assign pulse_detected = ~cntrIR_prev & cntrIR;

  // Implement counter to count number squares moved by the Knight.
  always_ff @(posedge clk) begin
    // Load in the number of squares to move when the command is asserted, else hold current value.
    if (move_cmd)
      square_cnt <= cmd[3:0]; 
  end

  // Implement counter to count number of times the cntrIR pulse went high. 
  always_ff @(posedge clk) begin
    // Reset to 0 initially when begining a move.
    if (move_cmd)
      pulse_cnt <= 5'h0;
    else if (pulse_detected)
    // Increment the pulse count whenever we detect that cntrIR went high.
      pulse_cnt <= pulse_cnt + 1'b1;     
  end

  // Grab opcode that is being held in cmd.
  assign opcode = op_t'(cmd[15:12]);

  // Compare whether the pulse count detected is 2 times the number of sqaures requested to move,
  // to indicate that a move is complete.
  assign move_done = (pulse_cnt == {square_cnt, 1'b0});
  //////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////
  // Interfaces with the PID to move the Knight in the right direction  //
  ///////////////////////////////////////////////////////////////////////
  // Form the nudge factor based on whether the Knight veers too much to the left or right. 
  generate
    // Generate a different nudge factor when FAST_SIM is enabled.
    if (FAST_SIM)
      // Whenever lftIR goes high we add a positive nudge factor, and whenever rghtIR goes high,
      // we add a negative nudge factor.
      assign err_nudge = (lftIR)  ? 12'h1FF : 
		                     (rghtIR) ? 12'hE00 : 
                         12'h000;
    else
      assign err_nudge = (lftIR)  ? 12'h05F : 
	                       (rghtIR) ? 12'hFA1 : 
                         12'h000;
  endgenerate

  // Compute the desired heading based on the command.
  always_ff @(posedge clk, negedge rst_n) begin
    // If the Knight is required to move, take the heading from the command, and if it is non-zero append 0xF
    // to form the desired heading else, it is zero.
    if (!rst_n)
      desired_heading <= 12'h000; // Reset the flop.
    else if (move_cmd) begin
      if (cmd[11:4] == 8'h00)
        desired_heading <= 12'h000;
      else
        desired_heading <= {cmd[11:4], 4'hF};
    end 
  end

  // Form the error term as the difference of the actual and desired heading with the nudge factor.
  assign error = heading - desired_heading + err_nudge;

  // Computes the absolute value of the error.
  assign error_abs = (error[11]) ? -error : error;
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
    nxt_state = state;   // By default, assume we are in the current state.
    strt_cal = 1'b0;     // By default, do not start calibration of the gyro.
    move_cmd = 1'b0;     // By default, we are not processing a move command.
    moving = 1'b0;       // By default, the Knight is not moving.
    clr_frwrd = 1'b0;    // By default, the forward speed register is not cleared.
    inc_frwrd = 1'b0;    // By default, we are not incrementing the forward speed register.
    dec_frwrd = 1'b0;    // By default, we are not decrementing the forward speed register.
    tour_go = 1'b0;      // By default, we are not starting the Knight's tour.
    send_resp = 1'b0;    // By default, we are not sending an acknowledgment to the sender.
    fanfare_go = 1'b0;   // By default, we are not moving the Knight with fanfare.
    clr_cmd_rdy = 1'b0;  // By default, we are not clearing the command as read.

    case (state)
      CALIBRATE : begin // State for calibration process.
        if (cal_done) begin // Wait until calibration is complete.
          send_resp = 1'b1; // Send acknowledgment to Bluetooth.
          nxt_state = IDLE; // Return to IDLE.
        end
      end

      MOVE : begin // State to start moving.
        moving = 1'b1;    // Adjusting the heading qualifies as moving.
        if (error_abs < 12'h02C) begin
          clr_frwrd = 1'b1; // Clear the forward register.
          nxt_state = INCR; // Move to the increment speed state.
        end
      end

      INCR : begin // State to increment speed.
        inc_frwrd = 1'b1; // Increment forward speed.
        moving = 1'b1; // Continue moving.
        if (move_done) begin // If movement is complete.
          if (opcode == FANFARE) // If we move with fanfare, play the tune.
            fanfare_go = 1'b1; // Turn on fanfare for special move.
          nxt_state = DECR; // Go to the decrement speed state.
        end 
      end

      DECR : begin // State to decrement speed.
        dec_frwrd = 1'b1; // Decrement speed.
        if (zero) begin // If forward speed reaches zero.
          send_resp = 1'b1; // Send acknowledgment to Bluetooth.
          nxt_state = IDLE; // Return to IDLE.
        end else
          moving = 1'b1; // Continue moving if not zero.
      end

      default : begin // IDLE state - waits for a command
        if (cmd_rdy) begin // If a command is ready split into the following states based on the opcode.
          case (opcode)
            TOUR : begin
              tour_go = 1'b1; // Enable Knight's tour.
            end
            CAL : begin
              strt_cal = 1'b1; // Enable calibration.
              nxt_state = CALIBRATE; // Command to start calibration.
            end
            default : begin // MOV and FANFARE opcodes.
              move_cmd = 1'b1;  // Command to move.
              nxt_state = MOVE; // Command to move forward and slow down (optionally with fanfare).
            end
          endcase
          clr_cmd_rdy = 1'b1; // Clear the command ready signal.
        end      
      end
    endcase
  end
endmodule