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
  // We have ? states
  typedef enum logic [1:0] {IDLE, ???} state_t;

  // Declare state signals
  state_t state, nxt_state;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  logic move_cmd;            // The command that tells Knight to move from the state machine.
  logic move_done;           // Indicates that a move is complete by the Knight.
  logic [3:0] pulse_cnt;     // Indicates number of times cntrIR went high when moving the Knight, max 16 times.
  logic [2:0] square_cnt;    // The number of squares the Knight moved on the board.
  logic move_done;           // Indicates that a move is completed by the Knight.
  logic cntrIR_step;         // Metastable cntrIR signal from the IR sensor.
	logic cntrIR_stable_prev;  // Stabilized cntrIR signal from the IR sensor.
  logic cntrIR_stable_curr;  // Used to detect rising edge on the cntrIR signal.
  //////////////////////////////////////////////////////////////////////////////
 
  ///////////////////////////////////////////////////////////////
  // Implements square count logic when Knight is told to move /
  /////////////////////////////////////////////////////////////
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

  ////////////////////////////////////
	// Implement State Machine Logic //
	//////////////////////////////////

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
    case (state)
      default : begin 
        
      end
      ???? : begin 
        
      end
      ???? : begin
        
      end
    endcase
  end
  
endmodule