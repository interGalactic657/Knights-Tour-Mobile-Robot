///////////////////////////////////////////////////
// TourCmd.sv                                    //
// This block will make “The Knight”             //
// physically re-play the KnightsTour solution   //
// as 48 individual movements on a 5x5 board.    //
///////////////////////////////////////////////////
module TourCmd(
    clk, rst_n, start_tour, move, mv_indx, cmd_UART, cmd, 
    cmd_rdy_UART, cmd_rdy, clr_cmd_rdy, send_resp, resp
);

  input logic clk,rst_n;			  // 50MHz clock and asynch active low reset
  input logic start_tour;			  // from done signal from TourLogic
  input logic [7:0] move;			  // encoded 1-hot move to perform
  output logic [4:0] mv_indx; 	// "address" to access next move
  input logic [15:0] cmd_UART;	// cmd from UART_wrapper
  input logic cmd_rdy_UART;		  // cmd_rdy from UART_wrapper
  output logic [15:0] cmd;		  // multiplexed cmd to cmd_proc
  output logic cmd_rdy;			    // cmd_rdy signal to cmd_proc
  input logic clr_cmd_rdy;		  // from cmd_proc (goes to UART_wrapper too)
  input logic send_resp;			  // lets us know cmd_proc is done with the move command
  output logic [7:0] resp;		  // either 0xA5 (done) or 0x5A (in progress)
  
  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [2:0] {IDLE, VERT, HOLDV, HORZ, HOLDH} state_t;

  //////////////////////////////////////////////
  // Declare heading direction as enumerated //
  ////////////////////////////////////////////
  typedef enum logic signed [7:0] {NORTH = 8'h00, WEST = 8'h3F, SOUTH = 8'h7F, EAST = 8'hBF} heading_t;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  ///////////////////////// Move Count Logic ///////////////////////////////////////////
  logic tour_done;            // Asserted when the KnightsTour has been finished.
  ////////////////////////////// Move Decoding Logic ////////////////////////////////////
  logic [3:0] square_cnt;     // The number of squares the Knight must move on the board.
  heading_t heading;          // Form the direction the Knight should move based on the move.
  ////////////////////////////// Command Bus Logic ////////////////////////////////////
  logic [3:0] opcode;         // Form the opcode of the command to either move the Knight with fanfare or not.
  logic [15:0] cmd_TOUR;      // The command formed by TourCmd.
  logic cmd_rdy_TOUR;         // Formed as an output to cmd_proc whenever a command is done being processed. 
  ///////////////////////////// State Machine ////////////////////////////////////////////
  logic cmd_control;          // Usurps control of the command MUX, otherwise UART_wrapper has control.
  logic clr_index;            // Used to clear the move index counter whenever we start a new KnightsTour.
  logic inc_index;            // Used to Increment the move index counter to the next move.
  logic cap_vert;             // Used to capture the vertical component of the move.
  logic cap_horz;             // Used to capture the horizontal component of the move.
  logic fanfare_go;           // Kick off the "Charge!" fanfare on piezo when the Knight completes an L-shape.
  logic set_cmd_rdy;          // Asserted whenever a command is done being processed.   
  ////////////////////////////////////////////////////////////////////////////////////////
  
  /////////////////////////////////////////////////////////////
  // Keeps track of the number of moves the Knight has made //
  ///////////////////////////////////////////////////////////
  // Implement counter to track the current move index of the KnightsTour trace.
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      move_indx <= 5'h0;  // Reset the counter on reset.
    else if (clr_index)
      move_indx <= 5'h0;  // Clear the counter when starting the KnightsTour.
    else if (inc_index)
      move_indx <= move_indx + 1'b1;  // Increment the counter to get the next move.
  end

  // The KnightsTour has been completed after 24 moves, i.e., when move_indx is 23.
  assign tour_done = (move_indx == 5'h17);
  //////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////
  // Decode a move into horizontal and veritical components //
  ///////////////////////////////////////////////////////////
  always_comb begin
    // Moves are one hot encoded, so only one case must be true, otherwise, we don't move by default.
    unique case (1'b1) 
      // Case when move[0] is high
      // Vertical movement: 2 squares north.
      // Horizontal movement: 1 square east.
      move[0]: begin
        if (cap_vert) begin
            heading = NORTH;   // Move north.
            square_cnt = 4'h2; // Move 2 squares vertically.
        end else if (cap_horz) begin
            heading = EAST;    // Move east.
            square_cnt = 4'h1; // Move 1 square horizontally.
        end
      end

      // Case when move[1] is high
      // Vertical movement: 2 squares north.
      // Horizontal movement: 1 square west.
      move[1]: begin
        if (cap_vert) begin
            heading = NORTH;   // Move north.
            square_cnt = 4'h2; // Move 2 squares vertically.
        end else if (cap_horz) begin
            heading = WEST;    // Move west.
            square_cnt = 4'h1; // Move 1 square horizontally.
        end
      end

      // Case when move[2] is high
      // Vertical movement: 1 square north.
      // Horizontal movement: 2 squares west.
      move[2]: begin
        if (cap_vert) begin
            heading = NORTH;   // Move north.
            square_cnt = 4'h1; // Move 1 square vertically.
        end else if (cap_horz) begin
            heading = WEST;    // Move west.
            square_cnt = 4'h2; // Move 2 squares horizontally.
        end
      end

      // Case when move[3] is high
      // Vertical movement: 1 square south.
      // Horizontal movement: 2 squares west.
      move[3]: begin
        if (cap_vert) begin
            heading = SOUTH;   // Move south.
            square_cnt = 4'h1; // Move 1 square vertically.
        end else if (cap_horz) begin
            heading = WEST;    // Move west.
            square_cnt = 4'h2; // Move 2 squares horizontally.
        end
      end

      // Case when move[4] is high
      // Vertical movement: 2 squares south.
      // Horizontal movement: 1 square west.
      move[4]: begin
        if (cap_vert) begin
            heading = SOUTH;   // Move south.
            square_cnt = 4'h2; // Move 2 squares vertically.
        end else if (cap_horz) begin
            heading = WEST;    // Move west.
            square_cnt = 4'h1; // Move 1 square horizontally.
        end
      end

      // Case when move[5] is high
      // Vertical movement: 2 squares south.
      // Horizontal movement: 1 square east.
      move[5]: begin
         if (cap_vert) begin
            heading = SOUTH;   // Move south.
            square_cnt = 4'h2; // Move 2 squares vertically.
        end else if (cap_horz) begin
            heading = EAST;    // Move east.
            square_cnt = 4'h1; // Move 1 square horizontally.
        end
      end

      // Case when move[6] is high
      // Vertical movement: 1 square south.
      // Horizontal movement: 2 squares east.
      move[6]: begin
        if (cap_vert) begin
            heading = SOUTH;   // Move south.
            square_cnt = 4'h1; // Move 1 square vertically.
        end else if (cap_horz) begin
            heading = EAST;    // Move east.
            square_cnt = 4'h2; // Move 2 squares horizontally.
        end
      end

      // Case when move[7] is high
      // Vertical movement: 1 square north.
      // Horizontal movement: 2 squares east.
      move[7]: begin
        if (cap_vert) begin
            heading = NORTH;   // Move north.
            square_cnt = 4'h1; // Move 1 square vertically.
        end else if (cap_horz) begin
            heading = EAST;    // Move east.
            square_cnt = 4'h2; // Move 2 squares horizontally.
        end
      end

      default: begin // Case when none of the bits are "hot", i.e., for the very first move.
        heading = NORTH;   // By default, assume the Knight looks towards NORTH for the very first move.
        square_cnt = 4'h0; // By default, no squares to move on the very first move.
      end
    endcase
  end
  ///////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////
  // Decide whether to process UART_Wrapper or TourCmd commands //
  ///////////////////////////////////////////////////////////////
  // Form the opcode of the command to send based on whether it is a normal move, or 
  // move with fanfare.
  assign opcode = (fanfare_go) ? 4'b0101 : 4'b0100;
  
  // Form the command in TourCmd based on the opcode, heading and square count.
  assign cmd_TOUR = {opcode, heading, square_cnt};

  // We send a response of 0x5A to the Bluetooth module after each move, else 0xA5 when done with the KnightsTour.
  assign resp = (tour_done) ? 8'hA5 : 8'h5A;

  // Usurp control of the command bus when cmd_control is asserted, otherwise UART_wrapper has control.
  assign cmd = (cmd_control) ? cmd_TOUR : cmd_UART;

  // Usurp control of the command ready signal when cmd_control is asserted, otherwise UART_wrapper has control.
  assign cmd_rdy = (cmd_control) ? cmd_rdy_TOUR : cmd_rdy_UART;
  ///////////////////////////////////////////////////////////////////////////////////////////

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

  // Implements the SR flop to hold the cmd_rdy_TOUR signal until clr_cmd_rdy is asserted. 
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      cmd_rdy_TOUR <= 1'b0; // Asynchronously reset the flop.
    else if (clr_cmd_rdy)
      cmd_rdy_TOUR <= 1'b0; // Knocks down cmd_rdy_TOUR when clr_cmd_rdy is asserted.
    else if (set_cmd_rdy)
      cmd_rdy_TOUR <= 1'b1; // Asserted when move command is processed.
  end
  /////////////////////////////////////////////////////////////////////////////////////////////
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Implements the combinational state transition and output logic of the state machine.//
  ////////////////////////////////////////////////////////////////////////////////////////
  always_comb begin
    /* Default all SM outputs & nxt_state */
    nxt_state = state;  // By default, assume we are in the current state.
    cmd_control = 1'b1; // Uses commands from TourCmd by default, otherwise from UART_Wrapper.
    clr_index = 1'b0;   // By default, we are not clearing the move counter.
    inc_index = 1'b0;   // By default, we are not incrementing the move index.
    cap_vert = 1'b0;    // By default, we are not capturing the vertical position of the move.
    cap_horz = 1'b0;    // By default, we are not capturing the horizontal position of the move.
    fanfare_go = 1'b0;  // By default, we are not moving the Knight with fanfare.
    set_cmd_rdy = 1'b0; // By defualt, assume we are not done with processing the move.

    case (state)
      VERT : begin // Captures the veritcal component of the move and waits till the command has been received by the Knight.
        cap_vert = 1'b1; // Capture the vertical component of the move.
        set_cmd_rdy = 1'b1; // Assert that the command is ready to be processed by cmd_proc.
        if (clr_cmd_rdy) // Wait till the command is received by the Knight.
          nxt_state = HOLDV; // Go to the HOLDV state to hold the current command till the move is processed.
      end

      HOLDV : begin // Waits for an acknowledgement from the Knight that the vertical move has been processed.
        if(send_resp) // Once the command is acknowledged, move the Knight horizontally.
          nxt_state = HORZ; // Go to the HORZ state to capture the horizontal component of the move.
        else
          cap_vert = 1'b1; // Keep TourCmd consistent with cmd_proc while processing a move.
      end

      HORZ : begin // Captures the horizontal component of the move and waits till the command has been received by the Knight.
        cap_horz = 1'b1; // Capture the horizontal component of the move.
        fanfare_go = 1'b1; // Move with fanfare once the Knight completes the L-shape movement.
        set_cmd_rdy = 1'b1; // Assert that the command is ready to be processed by cmd_proc.
        if (clr_cmd_rdy) // Wait till the command is received by the Knight.
          nxt_state = HOLDH; // Go to the HOLDH state to hold the current command till the move is processed.
      end

      HOLDH : begin // Waits for an acknowledgement from the Knight that the horizontal move has been processed.
        if(send_resp) begin // Once the command is acknowledged, go to the next move, or go back to IDLE, if tour is done.
          if (tour_done) begin
            nxt_state = IDLE; // We completed the KnightsTour, so go back to IDLE until requested to play again.
          end else begin
            inc_index = 1'b1; // Increment the move index to the next move.
            nxt_state = VERT; // Go to the VERT state to capture the vertical component of the next move.
          end
        end else begin
          cap_horz = 1'b1; // Keep TourCmd consistent with cmd_proc while processing a move.
        end
      end

      default : begin // IDLE state - waits for start tour to be asserted
        cmd_control = 1'b0; // In the IDLE state, the command MUX is in control of UART_Wrapper.
        // If start tour is asserted, decode each move and play the KnightsTour.
        if (start_tour) begin 
          clr_index = 1'b1; // Clear the move counter to get the first move of the KnightsTour.
          nxt_state = VERT; // Go to the VERT state to capture the vertical component of the move.
        end      
      end
    endcase
  end
endmodule