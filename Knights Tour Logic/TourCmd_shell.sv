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
  typedef enum logic [3:0] {NORTH = 8'h00, WEST = 8'h3F, SOUTH = 8'h7F, EAST = 8'hBF} heading_t;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////

  /* Decomposing of Move Logic */
  logic [3:0] opcode;
  heading_t heading;
  logic [3:0] num_sq;

  /* State Machine Logic */
  logic cmd_control;
  logic clr_cnt;
  logic inc_cnt;
  logic get_vert;
  logic get_horz;
  logic fanfare;

   
  


  ////////////////////////////////////////////////
  // Decode move into a cmd based on SM output //
  //////////////////////////////////////////////


  heading = (get_horz) ? (move >= 8'h20 || move == 8'h01) ? 8'hBF :
                                                            8'h3F :
            (get_vert) ? () : ();
  opcode = (fanfare) ? 4'b0101 : 4'b0100;
  
  cmd = {opcode, heading, num_sq};

 always_comb begin
  heading = 8'xx; // Default values
  num_sq = 4'h0;

  unique case (1'b1)
    move[0]: begin
      if (get_vert) begin
        heading = NORTH;
        num_sq = 4'h2;
      end else if (get_horz) begin
        heading = EAST;
        num_sq = 4'h1;
      end
    end
    move[1]: begin
      if (get_vert) begin
        heading = NORTH;
        num_sq = 4'h2;
      end else if (get_horz) begin
        heading = WEST;
        num_sq = 4'h1;
      end
    end
    move[2]: begin
      if (get_vert) begin
        heading = NORTH;
        num_sq = 4'h1;
      end else if (get_horz) begin
        heading = WEST;
        num_sq = 4'h2;
      end
    end
    move[3]: begin
      if (get_vert) begin
        heading = SOUTH;
        num_sq = 4'h1;
      end else if (get_horz) begin
        heading = WEST;
        num_sq = 4'h2;
      end
    end
    move[4]: begin
      if (get_vert) begin
        heading = SOUTH;
        num_sq = 4'h2;
      end else if (get_horz) begin
        heading = WEST;
        num_sq = 4'h1;
      end
    end
    move[5]: begin
      if (get_vert) begin
        heading = SOUTH;
        num_sq = 4'h2;
      end else if (get_horz) begin
        heading = EAST;
        num_sq = 4'h1;
      end
    end
    move[6]: begin
      if (get_vert) begin
        heading = SOUTH;
        num_sq = 4'h1;
      end else if (get_horz) begin
        heading = EAST;
        num_sq = 4'h2;
      end
    end
    move[7]: begin
      if (get_vert) begin
        heading = NORTH;
        num_sq = 4'h1;
      end else if (get_horz) begin
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
    else if (clr_cnt)
      move_indx_cntr <= 5'h0;       // Clear the counter when clr_cnt is asserted.
    else if (note_cnt_rst)
      note_period_cnt <= 15'h0000;  // Clear the counter when note_cnt_rst to generate proper frequency of PWM.
    else
      note_period_cnt <= note_period_cnt + 1'b1; // Increment counter each clock cycle.
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
    clr_cnt = 1'b0;
    inc_cnt = 1'b0;
    get_horz = 1'b0;
    get_vert = 1'b0;
    fanfare = 1'b0;

    case (state)
      
      
      
      
      default : begin // IDLE state - waits for a command
        if (start_tour) begin
          clr_cnt = 1'b1;
          nxt_state = VERT;
        end else 
          cmd_control = 1'b0; // Use UART cmd's during IDLE
      end


  end
endmodule