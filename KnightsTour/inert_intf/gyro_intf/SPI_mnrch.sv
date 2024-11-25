//////////////////////////////////////////////////
// SPI_mnrch.sv                                //
// This design will infer a SPI transceiver   //
// block.                                    //
//////////////////////////////////////////////
module SPI_mnrch(
  input logic clk,   // 50MHz system clock.
  input logic rst_n, // Asynchronous active low reset.
  input logic MISO, // Monarch In Serf Out.
  input logic snd, // A high for 1 clock period would initiate a SPI transaction.
  input logic [15:0] cmd, // Data (command) being sent to a SPI serf.
  output logic SS_n,	 // Active low Serf select.
  output logic SCLK, // Serial Clock (1/32 of System Clock).
  output logic MOSI, // Monarch Out Serf In. 
  output logic done, // Asserted when SPI transaction is complete. Should stay asserted till next wrt.
  output logic [15:0] resp // Data from SPI serf.
);

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have 3 states in total, IDLE, TRMT, BACK_PORCH.
  typedef enum logic [1:0] {IDLE, TRMT, BACK_PORCH} state_t;
    
  ///////////////////////////////////
	// Declare any internal signals //
	/////////////////////////////////
	logic [4:0] bit_cntr; // Counts the number of bits transmitted.
  logic init; // Asserted to begin transmission of data.
	logic shift; // Asserted to begin shifting at the positive edge of serf clock.
  logic [15:0] shft_reg; // Used as the 16-bit shift register to shift out data on MOSI and into from MISO.
  logic ld_SCLK; // Asserted to load initial SCLK_div register value.
  logic [4:0] SCLK_div; // The register of which the MSB is used as the serf clock signal.
  logic full; // Asserted to indicate that a transmission is complete and SS_n, SCLK brought back to IDLE state.
  logic set_done; // Asserted whenever the transmission of a 2-byte packet is finished (16-bits).
  logic done16; // Asserted whenever 2-bytes have been transmitted.
  state_t state; // Holds the current state.
	state_t nxt_state; // Holds the next state.		
  ///////////////////////////////////////////////

  // Implement the 16-bit shift register of the SPI interface.
  always_ff @(posedge clk) begin
          shft_reg <=  (init)  ? cmd                     :  // If init is asserted, parallel load in the command.
                       (shift) ? {shft_reg[14:0], MISO}  :  // Begin shifting out the data 1-bit each, starting with MSB, and shift in the MISO.
                       shft_reg; // Otherwise, recirculate the current value in the register.
  end
  
  // Whenever ld_SCLK is asserted, we load in the specific value (5'b10111) to ensure the slight delay between SS_n fall till first fall of SCLK.
  // It basically gives us the functionality of shifting data two system clocks after rise of SCLK and enabling a "back porch" (delay till IDLE state).
  // SCLK will be high when inactive, and will toggle between 0 and 1 during transmission (when ld_SCLK is not asserted) like a clock signal, every 32 system clocks.
  always_ff @(posedge clk)
      SCLK_div <= (ld_SCLK) ? 5'b10111 : SCLK_div + 1'b1;  // Continue incrementing the loaded count to generate clock signal.      
  
  // Implement counter to count number of bits shifted out on the MOSI line.
  always_ff @(posedge clk) begin
      bit_cntr <=  (init)  ? 5'h0          : // Reset to 0 initially.
                   (shift) ? bit_cntr + 1'b1  : // Increment the bit count whenever we shift a bit.
                   bit_cntr; // Otherwise hold current value.
  end

  // Implements the SR flop to keep serf select high (inactive) until snd is asserted, and back to high after transmission is complete,
  // as we don't want SS_n to glitch. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        SS_n <= 1'b1; // Asynchronously preset the serf select.
      else if (init)
        SS_n <= 1'b0; // Bring the serf select low to initiate a transaction.
      else if (set_done)
        SS_n <= 1'b1; // Bring the serf select back high, if transmission is done.
  end

  // Assert done16 whenever 16 bits have been transmitted.
  assign done16 = bit_cntr == 5'h10;
    
  // Take the MSB of SCLK_div as the serf clock signal.
  assign SCLK = SCLK_div[4];

  // We shift in data from the MISO 2 system clocks after the rise of SCLK.
  assign shift = SCLK_div == 5'b10001;

  // We are done with the transaction when SCLK_div is all ones indicating that SCLK is about to fall and go back to idle state.
  assign full = SCLK_div == 5'b11111;

  // Take the MSB of shft_reg as the MOSI signal.
  assign MOSI = shft_reg[15];

  // Treat the shift register as the response to read out, usually only least significant byte matters.
  assign resp = shft_reg;
  
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

  // Implements the SR flop to hold the done signal until snd is asserted, after transmission is complete. 
  always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        done <= 1'b0; // Asynchronously reset the flop.
      else if (init)
        done <= 1'b0; // Clear the flop synchronously, when a new transmission starts.
      else if (set_done)
        done <= 1'b1; // Synchronously preset the flop to 1, if transmission is done.
  end

  // Implements the combinational state transition and output logic of the state machine.
	always_comb begin
		/////////////////////////////////////////
		// Default all SM outputs & nxt_state //
		///////////////////////////////////////
		nxt_state = state; // By default, assume we are in the current state. 
    init = 1'b0; // By defualt, init is low.
    ld_SCLK = 1'b0; // By default, we are not loading the SCLK_div register with the specific value.
    set_done = 1'b0; // By default, we are not done transmitting data.
    
		case (state)
		  default : begin // Used as the IDLE state and checks if snd is asserted, else stay in the current state.
        if(snd) begin
			      init = 1'b1; // Assert init, to initialize the operands and begin the shifting.
            ld_SCLK = 1'b1; // Load in SCLK_div with the initial value. 
            nxt_state = TRMT; // If snd is asserted, next state is TRMT, and shifting data begins.
        end else
            ld_SCLK = 1'b1; // Load in SCLK_div with the initial value until we begin shifting. 
      end
		  TRMT : begin // Transmit the data.
		    if(done16) // Wait till 16-bits have been transmitted/received.
          nxt_state = BACK_PORCH; // Head to the BACK_PORCH state to bring SS_n and SCLK back high (inactive state).
      end
      BACK_PORCH : begin // Bring system back to inactive state.
		    if(full) begin // Wait till SCLK is about to fall the next clock cycle, to indicate were done with the transmission.
          set_done = 1'b1; // We are done transmitting, and assert done.
          ld_SCLK = 1'b1; // Load in SCLK_div with the initial value until we begin shifting. 
          nxt_state = IDLE; // Head back to the IDLE state to transmit a new packet of data.
        end
      end
		endcase
  end
			
endmodule