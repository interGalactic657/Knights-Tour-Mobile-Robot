//////////////////////////////////////////////////
// UART_wrapper.sv                             //
// This design packages 2 bytes recieved      //
// from the UART as a 16-bit                 //
// command.                                 //
/////////////////////////////////////////////
module UART_wrapper(
  input logic clk,   // 50MHz system clock.
  input logic rst_n, // Asynchronous active low reset.
  input logic clr_cmd_rdy,	// Knocks down cmd_rdy when asserted.
  input logic trmt,	 // Asserted for 1 clock to initiate transmission.
  input logic [7:0] resp,	 // Response of the Knight to the command.
  input logic RX,	 // Serial data input (1-bit).
  output logic TX,		// Serial data output (1-bit).
  output logic [15:0] cmd, // The (2-byte) command received to be relayed to the Knight.
  output logic cmd_rdy,		// Asserted when 2-byte packet received. Stays high till start bit of next command starts, or until clr_cmd_rdy asserted.
  output logic tx_done	// Asserted when command is done transmitting. Stays high till next byte transmitted. 
);

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 2 states in total, HIGH, LOW.
  typedef enum logic {HIGH, LOW} state_t;
    
  ///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
  logic byte_rdy; // Indicates that a byte is received.
  logic clr_rx_rdy;  // Knocks down rdy when asserted.
  logic capture_high; // Used to store the high byte of the command when received.
  logic [7:0] rx_data; // The data received from the UART.
  logic [7:0] high_byte; // The high byte of the command.
  logic set_cmd_rdy; // Asserted whenever 2 bytes of a command is received.   
  state_t state;     // Holds the current state.
	state_t nxt_state; // Holds the next state.	  
  ///////////////////////////////////////////////

  ////////////////////////////////////////
  // Instantiate the UART transceiver  //
  //////////////////////////////////////
  UART iUART(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(resp), .RX(RX), .clr_rx_rdy(clr_rx_rdy), 
            .TX(TX), .rx_rdy(byte_rdy), .tx_done(tx_done), .rx_data(rx_data));

  // Stores the high byte of the command.
  always_ff @(posedge clk) begin
      // Stores the high byte as received on the rx line otherwise, 
      // recirculates current value.
      high_byte <= (capture_high) ? rx_data : high_byte;  
  end

  // Package the command into high and low bytes as received into a 16-bit command.
  assign cmd = {high_byte, rx_data};
  
  ////////////////////////////////////
	// Implement State Machine Logic //
	//////////////////////////////////

  // Implements state machine register, holding current state or next state, accordingly.
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        state <= HIGH; // Reset into the HIGH state if machine is reset.
      else
        state <= nxt_state; // Store the next state as the current state by default.
  end

  // Implements the SR flop to hold the cmd_rdy signal until it receives a new byte, or when clr_cmd_rdy is asserted. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        cmd_rdy <= 1'b0; // Asynchronously reset the flop.
      else if (capture_high | clr_cmd_rdy)
        cmd_rdy <= 1'b0; // Knocks down cmd_rdy when clr_cmd_rdy is asserted, or when a new byte is received.
      else if (set_cmd_rdy)
        cmd_rdy <= 1'b1; // Asserted when a 16-bit command is received.
  end

  // Implements the combinational state transition and output logic of the state machine.
	always_comb begin
		/////////////////////////////////////////
		// Default all SM outputs & nxt_state //
		///////////////////////////////////////
		nxt_state = state; // By default, assume we are in the current state.
    clr_rx_rdy = 1'b0; // By defualt, clr_rx_rdy is low.
    set_cmd_rdy = 1'b0; // By defualt, assume we are not done receiving both bytes.
    capture_high = 1'b0; // By default, recirculate value in flop when high byte is not received.
        		
		case (state)
		  default : begin // As a default, used as the HIGH state, to avoid spurious events.
        if(byte_rdy) begin
            capture_high = 1'b1; // If a byte is recieved, capture the high byte. 
            clr_rx_rdy = 1'b1; // Clear the rx_dy signal of the UART, indicating data was received.
            nxt_state = LOW; // Next proceed to capture the low byte.
        end
      end
		  LOW : begin // Receive the low byte.
		    if(byte_rdy) begin
          set_cmd_rdy = 1'b1; // We have received the 16-bit command so assert cmd_rdy.
          clr_rx_rdy = 1'b1; // Clear the rx_dy signal of the UART, indicating data was received.
          nxt_state = HIGH; // Head back to the HIGH state to receive a new byte of data.
        end
      end
		endcase
  end
			
endmodule