//////////////////////////////////////////////////
// UART_rx.sv                                  //
// This design will infer a UART reciever     //
// block.                                    //
//////////////////////////////////////////////
module UART_rx(
  input logic clk,   // 50MHz system clock.
  input logic rst_n, // Asynchronous active low reset.
  input logic RX,	 // Serial data input.
  input logic clr_rdy,	// Knocks down rdy when asserted.
  output logic [7:0] rx_data, // Byte received.
  output logic rdy		// Asserted when byte received. Stays high till start bit of next byte starts, or until clr_rdy asserted.
);

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 2 states in total, IDLE and RCV.
  typedef enum logic {IDLE, RCV} state_t;
    
  ///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
	logic [8:0] rx_shft_reg;    // The register holding the values to be shifted in.
	logic [11:0] baud_cnt;  // Used to keep track of how many clock cycles a bit should take
                          // before next bit of data is shifted in.
  logic rx_step; // Used for double flopping RX signal.
  logic rx_stable; // The stable value of the RX signal after double flopping.
  logic start; // Asserted to begin receiving data.
	logic shift; // Asserted to shift whenever baud count is reached.
  logic receiving; // Signal from the state machine indicating that we are receiving data.
  logic [3:0] bit_cnt; // Count to keep track of how many bits of data we shifted.
  logic set_rdy;     // Asserted whenever a packet of data is received (10-bits).
  state_t state;     // Holds the current state.
	state_t nxt_state; // Holds the next state.		
  ///////////////////////////////////////////////

  // Implement the shift register of the UART RX to receive a byte of data.
  always_ff @(posedge clk) begin
      rx_shft_reg <=  (shift) ? {rx_stable, rx_shft_reg[8:1]}  :  // Begin shifting in the data 1-bit each, starting with LSB.
                      rx_shft_reg; // Otherwise, recirculate the current value in the register.
  end

  // Double flop the received bit to avoid meta-stability.
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n) begin
        rx_step <= 1'b1; // Preset the RX received value.
        rx_stable <= 1'b1; // Preset the RX stable value.
      end else begin
        rx_step <= RX; // Flop the RX to avoid metastability.
        rx_stable <= rx_step; // The stable value of the RX signal.
      end
  end

  // Implement counter to count number of clock cycles to sample the current bit on the RX line, before 
  // shifting in the next bit, i.e. at the mid cycle of the baud rate of the UART.
  always_ff @(posedge clk) begin
      baud_cnt <=  (start) ? 12'd1302         : // Whenever start or shift is asserted, start the baud count at 1302 (half clocks to count).
                   (shift) ? 12'd2604         : // Whenever we are shifting in the next bit, count a full baud cycle each time to sample at the mid value.
                   (receiving) ? baud_cnt - 1 : // Continue decrementing the count when we are receiving data.
                   baud_cnt; // Otherwise hold the current baud count.
  end
  
  // Implement counter to count number of bits shifted in on the RX line.
  always_ff @(posedge clk) begin
      bit_cnt <=  (start)  ? 4'h0         : // Reset to 0 initially.
                  (shift)  ? bit_cnt + 1  : // Increment the bit count whenever we shift in a bit.
                  bit_cnt; // Otherwise hold current value.
  end

  // Take the LSB 7-bits of the shift register as the data received, i.e., on the RX line.
  assign rx_data = rx_shft_reg[7:0];
    
  // We shift in data whenever we counted down all clock cycles for the baud rate.
  assign shift = (baud_cnt == 12'h000);
  
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

  // Implements the SR flop to hold the rdy signal until clr_rdy is asserted, after data is received. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        rdy <= 1'b0; // Asynchronously reset the flop.
      else if (start)
        rdy <= 1'b0; // Clear the flop synchronously.
      else if (clr_rdy)
        rdy <= 1'b0; // Knocks down rdy when asserted.
      else if (set_rdy)
        rdy <= 1'b1; // Synchronously preset the flop to 1, if a byte is received.
  end

  // Implements the combinational state transition and output logic of the state machine.
	always_comb begin
		/////////////////////////////////////////
		// Default all SM outputs & nxt_state //
		///////////////////////////////////////
		nxt_state = state; // By default, assume we are in the current state.
    start = 1'b0; // By defualt, init is low.
    receiving = 1'b0; // By default, assume data is not being transmitted. 
    set_rdy = 1'b0; // By default, rdy is not asserted.
        		
		case (state)
		  IDLE : begin // In the IDLE state, check if start bit is received, else stay in the current state.
        if(!rx_stable) begin
			      nxt_state = RCV; // If start bit is asserted, next state is RCV, and shifting data begins.
            start = 1'b1; // Assert start, to initialize the operands and begin the shifting.
        end
      end
		  RCV : begin // Receive the data
		    if(bit_cnt >= 4'hA) begin
          set_rdy = 1'b1; // We are done receiving data, and assert rdy.
          nxt_state = IDLE; // Head back to the IDLE state to receive a new byte of data.
        end else
          receiving = 1'b1; // If the bit count is not 10, in decimal, we continue transmitting and stay in this state.
      end
		endcase
  end
			
endmodule