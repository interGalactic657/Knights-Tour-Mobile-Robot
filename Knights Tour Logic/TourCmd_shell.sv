module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
            clr_cmd_rdy,send_resp,resp);

  input clk,rst_n;			// 50MHz clock and asynch active low reset
  input start_tour;			// from done signal from TourLogic
  input [7:0] move;			// encoded 1-hot move to perform
  output reg [4:0] mv_indx;	// "address" to access next move
  input [15:0] cmd_UART;	// cmd from UART_wrapper
  input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  output [15:0] cmd;		// multiplexed cmd to cmd_proc
  output cmd_rdy;			// cmd_rdy signal to cmd_proc
  input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  input send_resp;			// lets us know cmd_proc is done with the move command
  output [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)
  
  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [2:0] {IDLE, VERT, HOLDV, HORZ, HOLDH} state_t;

  ////////////////////////////////////////////
  // Declare command opcodes as enumerated //
  //////////////////////////////////////////
  typedef enum logic [7:0] {NORTH = 8'h00, WEST = 8'h3F, SOUTH = 8'h7F, EAST = 8'hBF} heading_t;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////

  /* Index Counter Logic */
  logic [4:0] move_indx_cntr;
  logic tour_done;

  /* Decomposing of Move Logic */
  logic [3:0] opcode;
  heading_t heading;
  logic [3:0] num_sq;

  /* State Machine Logic */
  logic cmd_control;
  logic clr_index;
  logic inc_index;
  logic cap_vert;
  logic cap_horz;
  logic fanfare_go;
  logic set_cmd_rdy;

   

  ////////////////////////////////////////////////
  // Decode move into a cmd based on SM output //
  //////////////////////////////////////////////
  opcode = (fanfare_go) ? 4'b0101 : 4'b0100;
  
  cmd = {opcode, heading, num_sq};

  always_comb begin
    // Default values
    heading = 8'xx;
    num_sq = 4'h0;

    unique case (1'b1)
      move[0]: begin
        if (cap_vert) begin
          heading = NORTH;
          num_sq = 4'h2;
        end else if (cap_horz) begin
          heading = EAST;
          num_sq = 4'h1;
        end
      end
      move[1]: begin
        if (cap_vert) begin
          heading = NORTH;
          num_sq = 4'h2;
        end else if (cap_horz) begin
          heading = WEST;
          num_sq = 4'h1;
        end
      end
      move[2]: begin
        if (cap_vert) begin
          heading = NORTH;
          num_sq = 4'h1;
        end else if (cap_horz) begin
          heading = WEST;
          num_sq = 4'h2;
        end
      end
      move[3]: begin
        if (cap_vert) begin
          heading = SOUTH;
          num_sq = 4'h1;
        end else if (cap_horz) begin
          heading = WEST;
          num_sq = 4'h2;
        end
      end
      move[4]: begin
        if (cap_vert) begin
          heading = SOUTH;
          num_sq = 4'h2;
        end else if (cap_horz) begin
          heading = WEST;
          num_sq = 4'h1;
        end
      end
      move[5]: begin
        if (cap_vert) begin
          heading = SOUTH;
          num_sq = 4'h2;
        end else if (cap_horz) begin
          heading = EAST;
          num_sq = 4'h1;
        end
      end
      move[6]: begin
        if (cap_vert) begin
          heading = SOUTH;
          num_sq = 4'h1;
        end else if (cap_horz) begin
          heading = EAST;
          num_sq = 4'h2;
        end
      end
      move[7]: begin
        if (cap_vert) begin
          heading = NORTH;
          num_sq = 4'h1;
        end else if (cap_horz) begin
          heading = EAST;
          num_sq = 4'h2;
        end
      end
    endcase
  end





  // This counter tracks the current move index of the Knight's Tour trace.
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      move_indx_cntr <= 5'h0;       // Reset the counter on reset.
    else if (clr_index)
      move_indx_cntr <= 5'h0;       // Clear the counter when clr_cnt is asserted.
    else if (inc_index)
      move_indx_cntr <= move_indx_cntr + 1'b1;  // Increment the counter when inc_cnt 
  end

  // Tour has been completed after 24 moves
  assign tour_done = (move_indx_cntr == 5'h17);

  /////////////////////////////////////
  // SR Flop for the cmd_rdy signal //
  ///////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      cmd_rdy = 1'b0;
    else if (clr_cmd_rdy)
      cmd_rdy = 1'b0;
    else if (set_cmd_rdy)
      cmd_rdy = 1'b1;
  end

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
    cmd_control = 1'b1; // Uses TourCmd's cmd when asserted 
    clr_index = 1'b0;
    inc_index = 1'b0;
    cap_vert = 1'b0;
    cap_horz = 1'b0;
    fanfare_go = 1'b0;
    set_cmd_rdy = 1'b0;

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
        if(send_resp) // Once the command is acknowledged, go to the next move, or go back to IDLE, if tour is done.
          if (tour_done)
            nxt_state = IDLE; // We completed the KnightsTour, so go back to IDLE until requested to play again.
          else begin
            inc_index = 1'b1; // Increment the move index to the next move.
            nxt_state = VERT; // Go to the VERT state to capture the vertical component of the next move.
          end
        else
          cap_horz = 1'b1; // Keep TourCmd consistent with cmd_proc while processing a move.
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