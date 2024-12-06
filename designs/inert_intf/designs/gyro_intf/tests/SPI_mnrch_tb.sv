//////////////////////////////////////////////////////////
// SPI_mnrch_tb.sv                                     //
// This testbench simulates the SPI interface and     //
// checking if data transmission between the monarch //
// and the inertial sensor was accurate.            //
/////////////////////////////////////////////////////
module SPI_mnrch_tb();
  
	logic clk; // 50MHz system clock.
	logic rst_n; // Asynchronous active low reset.
	logic [15:0] cmd; // The 16-bit command to send over SPI_mnrch.
	logic snd; // Enable the system to send a command.
	logic MISO; // Monarch In Serf Out.
	logic SS_n; // Active low Serf select.
	logic SCLK; // Serial Clock (1/32 of System Clock).
	logic MOSI; // Monarch Out Serf In. 
	logic [15:0] resp; // Data from SPI serf. For inertial sensor we will only ever use bits [7:0].
	logic done; // Asserted when SPI transaction is complete. Should stay asserted till next wrt.
	logic INT; // Interrupt signal from the SPI_iNEMO generated whenever new data is ready.
	logic [15:0] expected_resp; // The expected 16-bit response to receive over the SPI interface.

	///////////////////////////////////////////////////////////////////
	// Instantiate the SPI interface along with the inertial sensor //
	/////////////////////////////////////////////////////////////////
		// Instantiate the SPI monarch.
		SPI_mnrch iSPI (
			.clk(clk), 
			.rst_n(rst_n),
			.cmd(cmd), 
			.snd(snd),
			.MISO(MISO), 
			.SS_n(SS_n),
			.SCLK(SCLK),
			.MOSI(MOSI),
			.resp(resp),
			.done(done)
			);

		// Instantiate the (SPI serf) SPI_iNEMO intertial sensor.
		SPI_iNEMO1 iNEMO(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));

	// Test various scenarios including whether 
	// data transmission and recpetion is accurate through the SPI
	// interface.		  
	initial begin
		clk = 1'b0; // initially clock is low
		rst_n = 1'b0; // reset the system
		cmd = 16'h8F00; // Read from the WHO_AM_I register (at address 0x0F) of the SPI_iNEMO1.
		snd = 1'b0; // initially we are not sending any data
		expected_resp = 16'hxx6A; // We don't care about the first byte of data received, the second byte should return 0x6A.
		//// wait 1.5 clocks for reset ////
		@(posedge clk);
		@(negedge clk) begin 
			rst_n = 1'b1; // Deassert reset on a negative edge of clock.
			snd = 1'b1; // // assert snd and begin transmission
		end
		
		// Wait for a clock cycle to initialize system.
		@(negedge clk) begin
			snd = 1'b0; // deassert snd after one clock cycle

			if(done !== 1'b0) begin // done should not be asserted as we are beginning transmission.
				$display("ERROR: A transmission just started and done should have been low but was not.");
				$stop();
			end
		end

		/* TEST CASE 1 */
		repeat(550) @(posedge clk); // Wait 16*32 clock cycles, and ensure that 2 bytes are transmitted.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			if(done !== 1'b1) begin // done should have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by SPI_mnrch.");
				$stop();
			end

			if(resp !=? expected_resp) begin // The data received should be the value in the WHO_AM_I register.
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", expected_resp, resp);
				$stop();
			end
		end

		/* TEST CASE 2 */
		cmd = 16'h0D02; // Configure the SPI_iNEMO1 to generate an interrupt on the INT pin whenever new data is ready.
		expected_resp = 16'hxxxx; // We don't care about the response from the SPI_iNEMO1 during a write.
		@(negedge clk) snd = 1'b1; // begin transmission
		// deassert snd after one clock cycle
		@(negedge clk) begin
			snd = 1'b0; 

			if(done !== 1'b0) begin // done should have been low as we are beginning transmission.
				$display("ERROR: A transmission just started and done should have been low but was not.");
				$stop();
			end
		end

		@(posedge done); // Wait till we finish writing to the interrupt register of the SPI_iNEMO.
		@(posedge clk); // Wait a clock cycle (to avoid a RACE condition).
		
		// The internal signal in SPI_iNEMO1 (NEMO_setup) should go high.
		@(negedge clk) begin
			if(iNEMO.NEMO_setup !== 1'b1) begin // The internal signal, i.e., NEMO_setup should go high after configuration.
				$display("ERROR: SPI_mnrch configured the INT output pin of the iNEMO to assert but was not indicated by the SPI_iNEMO1.");
				$stop();
			end
		end

		/* TEST CASE 3 */
		@(posedge INT); // Wait for the INT signal to go high to read data.
		cmd = 16'hA200; // Read from the ptchL register to get pitch rate low from the gyro.
		expected_resp = 16'hxx63; // We expect to receive a value of 0x63 as the second byte (don't care about the first byte).
		@(negedge clk) snd = 1'b1; // begin transmission
		@(negedge clk) snd = 1'b0; // deassert snd_cmd after one clock cycle

		// Wait till we receive data read from the ptchL register.
		@(posedge done); 
		
		// The INT signal of the SPI_iNEMO1 should go back low after reading a register.
		@(negedge clk) begin
			if(INT !== 1'b0) begin // The INT signal should go low after the reading ptchL register.
				$display("ERROR: INT signal of SPI_iNEMO1 should have gone low after reading from a register but did not.");
				$stop();
			end

			if(resp !=? expected_resp) begin // The data received should be the value in the ptchL register.
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", expected_resp, resp);
				$stop();
			end
		end

		// If we reached here, that means all test cases were successful.
		$display("YAHOO!! All tests passed.");
		$stop();
	end
	
  always
    #5 clk = ~clk; // toggle clock every 5 time units
  
endmodule