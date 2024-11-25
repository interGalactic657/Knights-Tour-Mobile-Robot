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
  logic [2:0] nxt_xx,nxt_yy;		// next x & y position
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
  //////////////////////////////////////////////////////////////////////////////////////////

  
  /*We need a counter to keep track of order of moves to track where on the board the knight has visited
  << 2-D array of 5-bit vectors that keep track of where on the board the knight
     has visited.  Will be reduced to 1-bit boolean after debug phase >>

  << 1-D array (of size 24) to keep track of last move taken from each move index >>


  << 1-D array (of size 24) to keep track of move_poss moves from each move index >>
  << move_try ... not sure you need this.  I had this to hold move I would try next >>
  << move number...when you have moved 24 times you are done.  Decrement when backing up >>
  << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  
  << below I am giving you an implementation of the one of the register structures you have >>
  << to infer (board[][]).  You need to implement the rest, and the controlling SM >> */
  ///////////////////////////////////////////////////
  // The board memory structure keeps track of where 
  // the knight has already visited.  Initially this 
  // should be a 5x5 array of 5-bit numbers to store
  // the move number (helpful for debug).  Later it 
  // can be reduced to a single bit (visited or not)
  ////////////////////////////////////////////////	  
  always_ff @(posedge clk)
    if (zero)
	  board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
	else if (init)
	  board[x_start][y_start] <= 5'h1;	// mark starting position
	else if (update_position)
	  board[nxt_xx][nxt_yy] <= move_num + 2'h2;	// mark as visited
	else if (backup)
	  board[xx][yy] <= 5'h0;			// mark as unvisited

   // For xx
  always_ff @(posedge clk)
    if (init)
    xx <= x_start;
  else if (update_position | go_back)
    xx <= nxt_xx;
  // else if (go_back)
  //   xx <= xx - off_x(last_move[move_num]); // TODO: Correct? Or do an assignment like nxt_xx (flop)?

  // For yy
  always_ff @(posedge clk)
    if (init)
    yy <= y_start;
  else if (update_position | go_back)
    yy <= nxt_yy;
  // else if (go_back)
  //   // yy <= yy - off_y(last_move[move_num]); // TODO: Correct? Or do an assignment like nxt_xx (flop)? 

  // For the next move to try
  always_ff @(posedge clk)
    if (calc)
    move_try <= 8'h01;
  else if (next_move)
    move_try <= {move_try[6:0], 1'b0};      
  else if (go_back)
    move_try <= {last_move[move_num][6:0], 1'b0};

  // For last move memory structure that ends up forming the solution  
  always_ff @(posedge clk)
    if (move_poss)
    last_move[move_num] <= move_try;

  // For possible moves memory structure used to calculate the possible mvoes
  // at the given position
  always_ff @(posedge clk)
    if (calc) begin
    poss_moves[move_num] <= calc_poss(xx, yy);
    calc_possible_moves <= calc_poss(xx, yy);
    end
    


  // Checks if there is another move available from the current square
  assign have_move = (move_try != 8'h80);

  // Checks if there is another move available from the previous square TODO: check if we use move_try here?
  assign prev_have_move = (last_move[move_num] != 8'h80);

  // For move number
  always_ff @(posedge clk)
    if (zero)
    move_num <= 5'h00;
  else if (update_position)
    move_num <= move_num + 1'b1;
  else if (backup)
    move_num <= move_num - 1'b1;

  // The KnightsTour has been completed after 24 moves, i.e., when move_num is 23.
  assign tour_done = (move_num == 5'h17);

  // Set reset flop for the backup to allow decrementation first TODO: Check if last else clause is correct
  always_ff @(posedge clk)
    if (backup)
    go_back <= 1'b1;
  else
    go_back <= 1'b0;   

 

  // For nxt_xx TODO: Check if control signals are correct?? Or to use an assign for this (like above)??
  always_ff @(posedge clk)
    if (calc) begin     
    nxt_xx <= xx + off_x(move_try);
    chk_off_x <= off_x(move_try); 
    end
  else if (backup) begin
    nxt_xx <= xx - off_x(last_move[move_num]);
    chk_off_x <= off_x(move_try);
  end

  // For nxt_yy TODO: Check if control signals are correct?? Or to use an assign for this (like above)??
  always_ff @(posedge clk)
    if (calc) begin
    nxt_yy <= yy + off_y(move_try);
    chk_off_y <= off_y(move_try);
    end
  else if (backup) begin
    nxt_yy <= yy - off_y(last_move[move_num]);
    chk_off_y <= off_y(move_try);
  end
  
  // Checks if the next move we want to make is possible TODO: Change to 1'h0 when done debugging and see if nxt_xx and nxt_yy are right indexes
  assign move_poss = (poss_moves[move_num] & move_try) && (board[nxt_xx][nxt_yy] == 5'h00);
  assign chk_board = board[nxt_xx][nxt_yy];

  // Move to output from this block, which is only valid after the done signal has been asserted from the SM
  assign move = last_move[indx];
  
  function logic [7:0] calc_poss(input [2:0] xpos,ypos);
  ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the move_poss moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
    //initialize the move_poss moves to 0
    // logic [7:0] poss_moves;
    logic signed [2:0] x_offsets[0:7];
    logic signed [2:0] y_offsets[0:7];
    logic signed [3:0] newx;
    logic signed [3:0] newy;
    integer i;

    // $xoff{1} = 1; $yoff{1} = 2;
    // $xoff{2} = -1; $yoff{2} = 2;
    // $xoff{4} = -2; $yoff{4} = 1;
    // $xoff{8} = -2; $yoff{8} = -1;
    // $xoff{16} = -1; $yoff{16} = -2;
    // $xoff{32} = 1; $yoff{32} = -2;
    // $xoff{64} = 2; $yoff{64} = -1;
    // $xoff{128} = 2; $yoff{128} = 1;
    
    // poss_moves = 8'b0;
    calc_poss = 8'h0;
    x_offsets = '{1, -1, -2, -2, -1, 1, 2, 2};
    y_offsets = '{2, 2, 1, -1, -2, -2, -1, 1};
    // poss_moves = 8'b0;
    
    for (i = 0; i < 8; i = i + 1) begin
      newx = xpos + x_offsets[i];
      newy = ypos + y_offsets[i];
      if ((newx >= 0 && newx < 5) && (newy >= 0 && newy < 5))
        calc_poss[i] = 1'b1;
    end
  endfunction
  
  function signed [2:0] off_x(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the x-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from xx
	/////////////////////////////////////////////////////
  unique case (try)
    8'b0000_0001: off_x = 3'b001; // 1
    8'b0000_0010: off_x = 3'b111; // -1
    8'b0000_0100: off_x = 3'b110; // -2
    8'b0000_1000: off_x = 3'b110; // -2
    8'b0001_0000: off_x = 3'b111; // -1
    8'b0010_0000: off_x = 3'b001; // 1
    8'b0100_0000: off_x = 3'b010; // 2
    8'b1000_0000: off_x = 3'b010; // 2
    default: off_x = 3'bxxx;
  endcase
  endfunction
  
  function signed [2:0] off_y(input [7:0] try);
  ///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
  unique case (try)
      8'b0000_0001: off_y = 3'b010; // 2
      8'b0000_0010: off_y = 3'b010; // 2
      8'b0000_0100: off_y = 3'b001; // 1
      8'b0000_1000: off_y = 3'b111; // -1
      8'b0001_0000: off_y = 3'b110; // -2
      8'b0010_0000: off_y = 3'b110; // -2
      8'b0100_0000: off_y = 3'b111; // -1
      8'b1000_0000: off_y = 3'b001; // 1
      default: off_y = 3'bxxx;
  endcase
  endfunction

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
    next_state = state;       // By default, assume we remain in the current state.
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
                next_state = IDLE; // Transition back to the IDLE state to start a new tour.
            end else
                next_state = POSSIBLE; // If the tour isn't complete, go back to POSSIBLE to complete other moves.
        end else if (have_move) begin // The current move was not possible, so attempt to proceed to the next move.
            next_move = 1'b1; // Proceed with the next move.
        end else begin // If no moves are possible, the Knight must backtrack.
            backup = 1'b1; // Initiate the backtracking process.
            next_state = BACKUP; // Transition to the BACKUP state to backtrack and try different paths.
        end
      end

      BACKUP: begin // Handles the situation when no valid moves are available, and the Knight needs to backtrack.
        if (prev_have_move) // Check if there was a valid move to backtrack to.
          next_state = MAKE_MOVE; // If there was a valid previous move, proceed to make the next move.
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