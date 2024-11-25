module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				      // 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						          // initiate calculation of solution
  input [4:0] indx;				      // used to specify index of move to read out
  output logic done;			      // pulses high for 1 clock when solution complete
  output [7:0] move;			      // the onehot encoded move addressed by indx (1 of 24 moves)
  
  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  typedef enum logic [2:0] {IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP} state_t;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  ///////////////////////// Board Position Signals ///////////////////////////////////////////
  logic [4:0] board[0:4][0:4];	// keeps track if position visited
  logic [7:0] last_move[0:23];  // last move tried from this spot
  logic [7:0] poss_moves[0:23];	// stores move_poss moves from this position as 8-bit one hot
  logic [7:0] move_try;				  // one hot encoding of move we will try next
  logic [4:0] move_num;				  // keeps track of move we are on
  logic [2:0] xx,yy;					  // current x & y position  
  logic [2:0] nxt_xx_inc,nxt_yy_inc, nxt_xx_dec, nxt_yy_dec;		// next x & y position
  ////////////////////////////// Movement Logic //////////////////////////////////////////////
  logic move_poss;      // Indicates if the next move is possible.
  logic have_move;      // Indicates that we have more moves to try in the tour.
  logic go_back;        // Used to go back to a previous move and check for other possible moves.
  logic prev_have_move; // Used to validate if the previous move has other possible moves.
  logic tour_done;      // Asserted when the KnightsTour has been finished.
  ///////////////////////////// State Machine ///////////////////////////////////////////////
  logic zero;             // Used to clear the board.
  logic init;             // Used to initliaze the board and set registers.
  logic update_position;  // Used to update the current position of the Knight.
  logic calc;             // Used to calculate all possible moves from the current position.
  logic next_move;        // Used to try the next move from the current position.
  logic backup;           // Used to backup if there are no other possible moves.
  state_t state;          // Holds the current state.
  state_t nxt_state;      // Holds the next state.
  ////////////////////////////// Debugging Logic ///////////////////////////////////////////
  logic [7:0] calc_possible_moves;
  logic [4:0] chk_board;
  logic [2:0] chk_off_x;
  logic [2:0] chk_off_y;   
  logic chk_poss;
  //////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////// Functions ////////////////////////////////////////////////
  //////////////////////////////////////////////////////
	// Returns a packed byte of all the move_poss      //
  // (at least in bound) moves given coordinates of //
  // the Knight.                                   //
	//////////////////////////////////////////////////
  function logic [7:0] calc_poss(input [2:0] xpos,ypos);
    begin
      //initialize the move_poss moves to 0
      logic [7:0] poss_moves;
      logic [7:0] xposs_moves;
      logic [7:0] yposs_moves;

      // $xoff{1} = 1; $yoff{1} = 2;
      // $xoff{2} = -1; $yoff{2} = 2;
      // $xoff{4} = -2; $yoff{4} = 1;
      // $xoff{8} = -2; $yoff{8} = -1;
      // $xoff{16} = -1; $yoff{16} = -2;
      // $xoff{32} = 1; $yoff{32} = -2;
      // $xoff{64} = 2; $yoff{64} = -1;
      // $xoff{128} = 2; $yoff{128} = 1;
      
      unique case(xpos)
        3'h0: xposs_moves = 8'b1110_0001;
        3'h1: xposs_moves = 8'b1111_0011;
        3'h2: xposs_moves = 8'b1111_1111;
        3'h3: xposs_moves = 8'b0011_1111;
        3'h4: xposs_moves = 8'b0001_1110;
        default: xposs_moves = 8'hxx;
      endcase

      unique case(ypos)
        3'h0: yposs_moves = 8'b1000_0111;
        3'h1: yposs_moves = 8'b1100_1111;
        3'h2: yposs_moves = 8'b1111_1111;
        3'h3: yposs_moves = 8'b1111_1100;
        3'h4: yposs_moves = 8'b0111_1000;
        default: yposs_moves = 8'hxx;
      endcase

      poss_moves = xposs_moves & yposs_moves;
     
      $display("poss_moves: %b", poss_moves);

      return poss_moves;
    end
  endfunction

  //////////////////////////////////////////////////
	// Returns the x-offset for the Knight to move //
  // given the encoding of the move to try.     //
	///////////////////////////////////////////////
  function signed [2:0] off_x(input [7:0] try);
    unique case (try) // Computes the offset based on the try.
      8'b0000_0001: off_x = 3'b001; // 1
      8'b0000_0010: off_x = 3'b111; // -1
      8'b0000_0100: off_x = 3'b110; // -2
      8'b0000_1000: off_x = 3'b110; // -2
      8'b0001_0000: off_x = 3'b111; // -1
      8'b0010_0000: off_x = 3'b001; // 1
      8'b0100_0000: off_x = 3'b010; // 2
      8'b1000_0000: off_x = 3'b010; // 2
      default: off_x = 3'bxxx; // We don't care when it doesn't match, for optimized area.
    endcase
  endfunction
  
  //////////////////////////////////////////////////
	// Returns the y-offset for the Knight to move //
  // given the encoding of the move to try.     //
	///////////////////////////////////////////////
  function signed [2:0] off_y(input [7:0] try);
    unique case (try) // Computes the offset based on the try.
      8'b0000_0001: off_y = 3'b010; // 2
      8'b0000_0010: off_y = 3'b010; // 2
      8'b0000_0100: off_y = 3'b001; // 1
      8'b0000_1000: off_y = 3'b111; // -1
      8'b0001_0000: off_y = 3'b110; // -2
      8'b0010_0000: off_y = 3'b110; // -2
      8'b0100_0000: off_y = 3'b111; // -1
      8'b1000_0000: off_y = 3'b001; // 1
      default: off_y = 3'bxxx; // We don't care when it doesn't match, for optimized area.
    endcase
  endfunction
  ///////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////
  // Keeps track of the state of the board while finding a solution //
  ///////////////////////////////////////////////////////////////////
  // Implements register to keep track of the state of the board while finding a solution
  // for the KnightsTour.	  
  always_ff @(posedge clk)
    if (zero) // Initialize the board to be 0s.
	    board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
	  else if (init) // Mark the starting position on the board.
	    board[x_start][y_start] <= 5'h1;
	  else if (update_position) // Mark the position as visisited with the current move number.
	    board[nxt_xx_inc][nxt_yy_inc] <= move_num + 2'h2;	
	  else if (backup) // Mark the current square as unvisited.
	    board[xx][yy] <= 5'h0;

   // Stores the current x position of the Knight on the board.
  always_ff @(posedge clk)
    if (init)
      xx <= x_start; // Initialize the starting x-position.
    else if (update_position)
      xx <= nxt_xx_inc; // Update the current position based on whether we need to update it or go back.
    else if (backup)
      xx <= nxt_xx_dec;

  // Stores the current y position of the Knight on the board.
  always_ff @(posedge clk)
    if (init)
      yy <= y_start; // Initialize the starting y-position.
    else if (update_position)
      yy <= nxt_yy_inc; // Update the current position based on whether we need to update it or go back.
    else if (backup)
      yy <= nxt_yy_dec;
  
  // Computes the new x position based on the move to try or backs up one move.
  assign nxt_xx_inc = xx + off_x(move_try);

  // Computes the new y position based on the move to try or backs up one move.                
  assign nxt_yy_inc = yy + off_y(move_try); 

  assign nxt_xx_dec = xx - off_x(last_move[move_num - 1]);

  assign nxt_yy_dec = yy - off_y(last_move[move_num - 1]);        
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////
  // Computes all possible moves from the current position  //
  ///////////////////////////////////////////////////////////
  // Implements the possible moves to try as one-hot encoded signals
  always_ff @(posedge clk)
    if (calc)
      move_try <= 8'h01; // Initially the first move to try is the LSB move.
    else if (next_move)
      move_try <= {move_try[6:0], 1'b0}; // For every other move, go to successive bits.  
    else if (backup) // Go back to the last move and compute a new move from there.
      move_try <= {last_move[move_num - 1][6:0], 1'b0};

  // Implement counter to track the current move index of the KnightsTour trace.
  always_ff @(posedge clk)
    if (zero)
      move_num <= 5'h0; // Reset the counter on zero.
    else if (update_position)
      move_num <= move_num + 1'b1; // Increment the counter when updating the position of the Knight on the board.
    else if (backup)
      move_num <= move_num - 1'b1; // Decrement the counter when going back.

  // Calculates all possible moves from a given position.
  always_ff @(posedge clk) begin
    if (calc) begin
      poss_moves[move_num] <= calc_poss(xx, yy); // Stores all possible moves from that location.
      calc_possible_moves <= calc_poss(xx, yy);
    end
  end
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////
  // Checks if we have more moves to try or go back to a previous move //
  //////////////////////////////////////////////////////////////////////
  // Checks if there is another move available from the current square.
  assign have_move = (move_try != 8'h80);

  // Checks if there is another move available from the previous square.
  assign prev_have_move = (last_move[move_num] != 8'h80);

  // Checks if the next move we want to make is possible TODO: Change to 1'h0 when done debugging and see if nxt_xx and nxt_yy are right indexes.
  assign move_poss = (poss_moves[move_num] & move_try) && (board[nxt_xx_inc][nxt_yy_inc] == 5'h00);
  assign chk_board = (board[nxt_xx_inc][nxt_yy_inc]);
  assign chk_poss = (poss_moves[move_num] & move_try);
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////
  // Forms the solution to the KnightsTour and returns moves as requested  //
  //////////////////////////////////////////////////////////////////////////
  // Stores the solution to the KnightsTour after it is found.
  always_ff @(posedge clk)
    if (move_poss)
      last_move[move_num] <= move_try; // Store the move in the register if the move was possible.

  // Return the move to TourCmd to replay the trace. It is only valid after the solution has been found.
  assign move = last_move[indx];

  // The KnightsTour has been completed after 24 moves, i.e., when move_num is 23.
  assign tour_done = (move_num == 5'h17);
  ////////////////////////////////////////////////////////////////////////////////

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
    nxt_state = state;        // By default, assume we remain in the current state.
    zero = 1'b0;              // By default, we are not clearing the board.
    init = 1'b0;              // By default, the initialization is not triggered.
    calc = 1'b0;              // By default, we are not calculating possible moves from a given square.
    update_position = 1'b0;   // By default, the Knight's position is not being updated.
    next_move = 1'b0;         // By default, we are not proceeding with the next move.
    backup = 1'b0;            // By default, we are not backtracking from the current position.
    done = 1'b0;              // By default, the KnightsTour is not done.

    case (state)
      INIT: begin // Prepares the board and sets up the starting position.
        init = 1'b1; // Assert the init signal to initialize the board and necessary registers.
        nxt_state = POSSIBLE; // Transition to the POSSIBLE state to calculate potential moves.
      end

      POSSIBLE: begin // Calculates all possible moves for the Knight from the current position.
        calc = 1'b1; // Triggers the calculation of possible moves for the Knight.
        nxt_state = MAKE_MOVE; // Transition to MAKE_MOVE state to select and execute one of the possible moves.
      end

      MAKE_MOVE: begin // Attempts to execute a move from the possible moves.
        if (move_poss) begin // Check if a valid move is possible.
            update_position = 1'b1; // Update the knight's position on the board.
            if (tour_done) begin // Check if the KnightsTour has been successfully completed.
                done = 1'b1; // Set the done signal to indicate the tour is finished.
                nxt_state = IDLE; // Transition back to the IDLE state to start a new tour.
            end else
                nxt_state = POSSIBLE; // If the tour isn't complete, go back to POSSIBLE to complete other moves.
        end else if (have_move) begin // The current move was not possible, so attempt to proceed to the next move.
            next_move = 1'b1; // Proceed with the next move.
        end else begin // If no moves are possible, the Knight must backtrack.
            backup = 1'b1; // Initiate the backtracking process.
            nxt_state = BACKUP; // Transition to the BACKUP state to backtrack and try different paths.
        end
      end

      BACKUP: begin // Handles the situation when no valid moves are available, and the Knight needs to backtrack.
        if (prev_have_move) // Check if there was a valid move to backtrack to.
          nxt_state = MAKE_MOVE; // If there was a valid previous move, proceed to make the next move.
        else
          backup = 1'b1; // If no previous valid move exists to backtrack to, keep backtracking.
      end

      default: begin // IDLE state - waits for the 'go' signal to begin initialization.
        if (go) begin
          zero = 1'b1; // Assert the zero signal to reset the board state. 
          nxt_state = INIT; // Transition to the INIT state to start initializing the board and registers.
        end
      end
    endcase
  end
  
endmodule