//////////////////////////////////////////////////
// UART_tx.sv                                  //
// This design will infer a UART transmitter  //
// block.                                    //
//////////////////////////////////////////////
module UART_tx(
  input logic clk,   // 50MHz system clock.
  input logic rst_n, // Asynchronous active low reset.
  input logic trmt,	 // Asserted for 1 clock to initiate transmission.
  input logic [7:0] tx_data, // Byte to transmit.
  output logic tx_done,	// Asserted when byte is done transmitting. Stays high till next byte transmitted. 
  output logic TX		// Serial data output.
);

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 2 states in total, IDLE and TRM.
  typedef enum logic {IDLE, TRM} state_t;
    
  ///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
	logic [8:0] tx_shft_reg;    // The register holding the values to be shifted out.
	logic [11:0] baud_cnt;  // Used to keep track of how many clock cycles a bit should take
                          // before next bit of data is shifted in.
  logic init; // Asserted to begin transmission of data.
	logic shift; // Asserted to begin shifting whenever baud count is reached.
  logic transmitting; // Asserted whenever we are still transmitting data along TX line.
  logic [3:0] bit_cnt; // Count to keep track of how many bits of data we shifted.
  logic set_done;     // Asserted whenever the transmission of a packet is finished (10-bits).
  state_t state;     // Holds the current state.
	state_t nxt_state; // Holds the next state.		
  ///////////////////////////////////////////////

  // Implement the shift register of the UART TX to transmit a byte of data.
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
          tx_shft_reg <= 9'h1FF; // Reset the register to all ones, indicating line is IDLE.
      else
          tx_shft_reg <= (init)  ? {tx_data, 1'b0}           :  // If init is asserted, load the data in along with the start bit.
                         (shift) ? {1'b1, tx_shft_reg[8:1]}  :  // Begin shifting out the data 1-bit each, starting with LSB.
                         tx_shft_reg; // Otherwise, recirculate the current value in the register.
  end
  
  // Implement counter to count number of clock cycles to hold the current bit on the TX line, before 
  // shifting out next bit, i.e. the baud rate of the UART.
  always_ff @(posedge clk) begin
      baud_cnt <=  (init | shift) ? 12'h000      : // Whenever init or shift is asserted, clear the register.
                   (transmitting) ? baud_cnt + 1 : // Continue incrementing the count when we are transmitting data.
                   baud_cnt; // Otherwise hold the current baud count.
  end
  
  // Implement counter to count number of bits shifted out on the TX line.
  always_ff @(posedge clk) begin
      bit_cnt <=  (init)  ? 4'h0         : // Reset to 0 initially.
                  (shift) ? bit_cnt + 1  : // Increment the bit count whenever we shift a bit.
                  bit_cnt; // Otherwise hold current value.
  end

  // Take the LSB of the shift register as the data shifted out, i.e., on the TX line.
  assign TX = tx_shft_reg[0];
    
  // We shift out data whenever we reach a baud count of 2604 clock cycles.
  assign shift = baud_cnt >= 12'd2604;
  
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

  // Implements the SR flop to hold the tx_done signal until trmt is asserted, after transmission is complete. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        tx_done <= 1'b0; // Asynchronously reset the flop.
      else if (init)
        tx_done <= 1'b0; // Clear the flop synchronously.
      else if (set_done)
        tx_done <= 1'b1; // Synchronously preset the flop to 1, if transmission is done.
  end

  // Implements the combinational state transition and output logic of the state machine.
	always_comb begin
		/////////////////////////////////////////
		// Default all SM outputs & nxt_state //
		///////////////////////////////////////
		nxt_state = state; // By default, assume we are in the current state.
    init = 1'b0; // By defualt, init is low.
    transmitting = 1'b0; // By default, assume data is not being transmitted. 
    set_done = 1'b0; // By default, rdy is not asserted.
        		
		case (state)
		  IDLE : begin // In the IDLE state, check if trmt is asserted, else stay in the current state.
        if(trmt) begin
			      nxt_state = TRM; // If go is asserted, next state is TRM, and shifting data begins.
            init = 1'b1; // Assert init, to initialize the operands and begin the shifting.
        end
      end
		  TRM : begin // Transmit the data.
		    if(bit_cnt >= 4'hA) begin
          set_done = 1'b1; // We are done transmitting, and assert done.
          nxt_state = IDLE; // Head back to the IDLE state to transmit a new byte of data.
        end else begin
          transmitting = 1'b1; // If the bit count is not 10, in decimal, we continue transmitting and stay in this state.
        end
      end
		endcase
  end
			
endmodule