module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						// initiate calculation of solution
  input [4:0] indx;				// used to specify index of move to read out
  output logic done;			// pulses high for 1 clock when solution complete
  output [7:0] move;			// the onehot encoded move addressed by indx (1 of 24 moves)
  //signal to zero the board
  logic zero;
  //signal to initialize the board
  logic not_visited;
  //signal to indicate if the next move is possible
  logic move_poss;
  //signal to indicate that we want to make the next move
  logic update_position;
  // signal to start initliazation of the board?
  logic init;
  // signal to backup if there are no other possible move and we need to go back
  logic backup;
  // signal to calculate move_poss moves from current position
  logic calc;
  //signal to try the next move
  logic nxt_move;
  //signal to indicate that we are done
  logic move_done;
  //signal to go back to a previous move and check for other possible moves. SR Flopped as a function of backup
  logic go_back;
  // signal to validate if the previous move has other possible moves
  logic prev_have_move;
  // signal to indicate that we have more moves to try
  logic have_move;

  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  
  << some internal registers to consider: >>
  << These match the variables used in knightsTourSM.pl >>
  reg [4:0] board[0:4][0:4];				// keeps track if position visited
  reg [7:0] last_move[0:23];		// last move tried from this spot
  reg [7:0] poss_moves[0:23];		// stores move_poss moves from this position as 8-bit one hot
  reg [7:0] move_try;				// one hot encoding of move we will try next
  reg [4:0] move_num;				// keeps track of move we are on
  reg [2:0] xx,yy;					// current x & y position  
  logic [2:0] nxt_xx,nxt_yy;			// next x & y position

  //Creating the states for the state machine
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    POSSIBLE,
    MAKE_MOVE,
    BACKUP
  } state_t;

  state_t state, next_state;

  //Sequential logic for the state machine 
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;   // Reset into the IDLE state if machine is reset.
        else
            state <= nxt_state; // Store the next state as the current state by default.
    end

    //Combinational logic for the state machine
    always_comb begin
        // Default all SM outputs & nxt_state
        nxt_state = state;        
        zero = 1'b0;
        init = 1'b0;
        calc = 1'b0;
        nxt_move = 1'b0;
        done = 1'b0;
        update_position = 1'b0;
        backup = 1'b0;

        case (state)
            IDLE: begin
              if (go) begin
                next_state = INIT;
                zero = 1'b1;
              end
            end
            INIT: begin
              next_state = POSSIBLE;
              init = 1'b1;
            end
            POSSIBLE: begin
              next_state = MAKE_MOVE;
              calc = 1'b1;
            end
            MAKE_MOVE: begin
              if (move_poss & move_done) begin
                next_state = IDLE;
                update_position = 1'b1;
                done = 1'b1;
              end
              else if (move_poss & !move_done) begin
                next_state = POSSIBLE;
                update_position = 1'b1;
              end
              else if (!move_poss & have_move) begin
                next_state = MAKE_MOVE;
                nxt_move = 1'b1;
              end
              else if (!move_poss & !have_move) begin
                next_state = BACKUP;
                backup = 1'b1;
              end
            end
            BACKUP: begin
              if(prev_have_move) begin
              next_state = MAKE_MOVE;
              end
              
              else begin
              next_state = BACKUP;
              backup = 1'b1;
              end
            
            end
            default: next_state = IDLE;
        endcase
    end
  
  
  //We need a counter to keep track of order of moves to track where on the board the knight has visited
  << 2-D array of 5-bit vectors that keep track of where on the board the knight
     has visited.  Will be reduced to 1-bit boolean after debug phase >>

  << 1-D array (of size 24) to keep track of last move taken from each move index >>


  << 1-D array (of size 24) to keep track of move_poss moves from each move index >>
  << move_try ... not sure you need this.  I had this to hold move I would try next >>
  << move number...when you have moved 24 times you are done.  Decrement when backing up >>
  << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  
  << below I am giving you an implementation of the one of the register structures you have >>
  << to infer (board[][]).  You need to implement the rest, and the controlling SM >>
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
	  board[nxt_xx][nxt_yy] <= move_num + 2;	// mark as visited
	else if (backup)
	  board[xx][yy] <= 5'h0;			// mark as unvisited

  // For last move memory structure that ends up forming the solution  
  always_ff @(posedge clk)
    if (move_poss)
    last_move[move_num] <= move_try;

  // For possible moves memory structure used to calculate the possible mvoes
  // at the given position
  always_ff @(posedge clk)
    if (calc)
    poss_moves[move_num] <= calc_poss(xx, yy);

  // For the next move to try
  always_ff @(posedge clk)
    if (calc)
    move_try <= 8'h01;
  else if (have_move)
    move_try <= {move_try[6:0], 1'b0};      
  else if (go_back)
    move_try <= {last_move[move_num][6:0], 1'b0};

  // For move number
  always_ff @(posedge clk)
    if (zero)
    move_num <= 5'h00;
  else if (update_position)
    move_num <= move_num + 1;
  else if (backup)
    move_num <= move_num - 1;

  // For xx
  always_ff @(posedge clk) 


  //We can create a set reset flop for the move count to prevent race conditions 
  
  function [7:0] calc_poss(input [2:0] xpos,ypos);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the move_poss moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
    //initialize the move_poss moves to 0
    logic [7:0] poss_moves;
    poss_moves = 8'b0;
    // $xoff{1} = 1; $yoff{1} = 2;
    // $xoff{2} = -1; $yoff{2} = 2;
    // $xoff{4} = -2; $yoff{4} = 1;
    // $xoff{8} = -2; $yoff{8} = -1;
    // $xoff{16} = -1; $yoff{16} = -2;
    // $xoff{32} = 1; $yoff{32} = -2;
    // $xoff{64} = 2; $yoff{64} = -1;
    // $xoff{128} = 2; $yoff{128} = 1;
    
    logic signed [2:0] x_offsets[8] = '{1, -1, -2, -2, -1, 1, 2, 2};
    logic signed [2:0] y_offsets[8] = '{2, 2, 1, -1, -2, -2, -1, 1};
    poss_moves = 8'b0;
    
    for (int i = 0; i < 8; i++) begin
      logic signed [3:0] newx = xpos + x_offsets[i];
      logic signed [3:0] newy = ypos + y_offsets[i];
      if (newx >= 0 && newx < 5 && newy >= 0 && newy < 5)
        poss_moves[i] = 1;
    end
    return poss_moves;
  
  endfunction
  
  function signed [2:0] off_x(input [7:0] try);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a the x-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from xx
	/////////////////////////////////////////////////////
  case (try)
    8'b0000_0001: return 1;
    8'b0000_0010: return -1;
    8'b0000_0100: return -2;
    8'b0000_1000: return -2;
    8'b0001_0000: return -1;
    8'b0010_0000: return 1;
    8'b0100_0000: return 2;
    8'b1000_0000: return 2;
    default: return 0;
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
  case (try)
    8'b0000_0001: return 2;
    8'b0000_0010: return 2;
    8'b0000_0100: return 1;
    8'b0000_1000: return -1;
    8'b0001_0000: return -2;
    8'b0010_0000: return -2;
    8'b0100_0000: return -1;
    8'b1000_0000: return 1;
    default: return 0;
  endcase
  endfunction
  
endmodule