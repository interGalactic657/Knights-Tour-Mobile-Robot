////////////////////////////////////////////////
// RemoteComm.sv                             //
// This design unwraps a 16-bit command     //
// recieved and sends it as two            //
// 8-bit bytes over UART.                 //
///////////////////////////////////////////
module RemoteComm(
  input logic clk,   // 50MHz system clock.
  input logic rst_n, // Asynchronous active low reset.
  input logic snd_cmd, // Enable the system to send a command.
  input logic [15:0] cmd, // The 16-bit command to split into 2 bytes.
  input logic RX,	 // Serial data input (1-bit).
  output logic TX,	// Serial data output (1-bit).
  output logic [7:0] resp,	 // Response of the Knight to the command.
  output logic resp_rdy,	 // Asserted when a response is received from the Knight.
  output logic cmd_snt		// Asserted when a command is sent. Stays high till next command is sent.
);
  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 3 states in total, IDLE, HIGH, LOW.
  typedef enum logic [1:0] {IDLE, HIGH, LOW} state_t;

  ///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
  logic sel_high; // Used to send the high byte of the command when snd_cmd is asserted.
  logic tx_done; // Asserted when byte is done transmitting. Stays high till next byte transmitted. 
  logic trmt; // Transmission enable signal.
  logic [7:0] low_byte; // The low byte of the command that is received.
  logic [7:0] byte_sent; // The byte sent over the UART.
  logic set_cmd_snt; // Asserted whenever the 2 bytes of the 16-bit command are sent.
  state_t state; // Holds the current state.
	state_t nxt_state; // Holds the next state.	
  ///////////////////////////////////////////////

  ////////////////////////////////////////
  // Instantiate the UART transceiver  //
  //////////////////////////////////////
  UART iUART(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(byte_sent), .RX(RX), .clr_rx_rdy(1'b0), 
            .TX(TX), .rx_rdy(resp_rdy), .tx_done(tx_done), .rx_data(resp));
  

  // Store the low byte of the 16-bit command when snd_cmd is asserted.
  always_ff @(posedge clk) begin
      if (snd_cmd)
        low_byte <= cmd[7:0];
  end

  // Select the high byte to send when sel_high is asserted otherwise send the low_byte.
  assign byte_sent = (sel_high) ? cmd[15:8] : low_byte;

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

  // Implements the SR flop to hold the cmd_snt signal until snd_cmd is asserted, after data is sent. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        cmd_snt <= 1'b0; // Asynchronously reset the flop.
      else if (snd_cmd)
        cmd_snt <= 1'b0; // Knocks down cmd_snt when asserted.
      else if (set_cmd_snt)
        cmd_snt <= 1'b1; // Asserted when a command is sent.
  end

  // Implements the combinational state transition and output logic of the state machine.
	always_comb begin
		/////////////////////////////////////////
		// Default all SM outputs & nxt_state //
		///////////////////////////////////////
		nxt_state = state; // By default, assume we are in the current state.
    sel_high = 1'b0; // By default, sel_high is low.
    trmt = 1'b0; // By default, assume data is not being transmitted. 
    set_cmd_snt = 1'b0; // By default, command is not sent.
        		
		case (state)
		  default : begin // Used as the IDLE state, as the default.
        if(snd_cmd) begin
            sel_high = 1'b1; // Assert sel_high to select the high byte to send over the UART.
            trmt = 1'b1; // Assert trmt, to transmit the data.
            nxt_state = HIGH; // If snd_cmd asserted, next state is HIGH, and we send out the high byte first.
        end
      end
		  HIGH : begin // Send the HIGH byte of the command.
		    if(tx_done) begin // Wait till the high byte is sent to send the next byte.
          trmt = 1'b1; // Assert trmt, to transmit the data.
          nxt_state = LOW; // Head to the LOW state.
        end
      end
      LOW : begin // Send the LOW byte of the command.
		    if(tx_done) begin // Wait till the low byte is sent to assert cmd_snt.
          set_cmd_snt = 1'b1; // We are done sending data, and assert cmd_snt.
          nxt_state = IDLE; // Head back to the IDLE state to send a new packet of data.
        end
      end
		endcase
  end

endmodule