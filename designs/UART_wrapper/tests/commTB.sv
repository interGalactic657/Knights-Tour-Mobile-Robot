//////////////////////////////////////////////////////
// commTB.sv                                       //
// This testbench simulates the UART_wrapper and  //
// RemoteComm blocks checking if data packaging  //
// and unpacking was accurate.                  //
/////////////////////////////////////////////////
module commTB();
  
	logic clk; // 50MHz system clock.
	logic rst_n; // Asynchronous active low reset.
	logic snd_cmd; // Enable the system to send a command.
	logic [15:0] cmd_sent; // The 16-bit command to send over RemoteComm.
	logic cmd_rx; // Serial data input (1-bit).
	logic cmd_tx; // Serial data output (1-bit).
	logic cmd_snt; // Asserted when a command is sent. Stays high till next command is sent.
	logic clr_cmd_rdy; // Knocks down cmd_rdy when asserted.
	logic cmd_rdy; // Asserted when 2-byte packet received. Stays high till next command starts, or until clr_cmd_rdy asserted.
	logic [15:0] cmd_received; // The expected 16-bit command to receive over UART_wrapper.

  ///////////////////////////////////////////////////////////////////
  // Instantiate CommTB as connecting RemoteComm and UART_wrapper //
  /////////////////////////////////////////////////////////////////
	// Instantiate RemoteComm. (Don't care about the response or response_rdy as we are not testing for receiving here.)
	RemoteComm iRemoteComm (
		.clk(clk), 
		.rst_n(rst_n), 
		.snd_cmd(snd_cmd), 
		.cmd(cmd_sent),
		.RX(cmd_rx), 
		.TX(cmd_tx), 
		.resp(),
		.resp_rdy(), 
		.cmd_snt(cmd_snt)
		);

	// Instantiate UART_wrapper. (Don't care about the response, trmt, or tx_done as we are not testing for transmitting here.)
	UART_wrapper iUART_wrapper(.clk(clk), .rst_n(rst_n), .clr_cmd_rdy(clr_cmd_rdy), 
	.trmt(1'b0), 
	.RX(cmd_tx), 
	.TX(cmd_rx), 
	.resp(8'h00), 
	.cmd(cmd_received), 
	.cmd_rdy(cmd_rdy), 
	.tx_done()
	);

  // Test various scenarios including whether 
  // data transmitted is data received as well as
  // system signals of each DUT. 			  
  initial begin
		clk = 1'b0; // initially clock is low
		rst_n = 1'b0; // reset the machines
		cmd_sent = 16'h14FE; // initial data to transmit over RemoteComm
		snd_cmd = 1'b0; // initially is low, i.e. inactive
		clr_cmd_rdy = 1'b0; // Initially clr_cmd_rdy is low.
		//// wait 1.5 clocks for reset ////
		@(posedge clk);
		@(negedge clk) begin 
			rst_n = 1'b1; // Deassert reset on a negative edge of clock.
			snd_cmd = 1'b1; // // assert snd_cmd and begin transmission
		end
		
		// Wait for a clock cycle to initialize system.
		@(negedge clk) begin 
			snd_cmd = 1'b0; // deassert snd_cmd after one clock cycle

			if(cmd_snt !== 1'b0) begin // cmd_snt should have been deasserted as we are beginning transmission.
				$display("ERROR: A transmission just started so cmd_snt should have been low but was not.");
				$stop();
			end
		end

		/* TEST CASE 1 */
		repeat(60000) @(posedge clk); // Wait 60000 clock cycles, and ensure that 2 bytes are transmitted.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			if(cmd_snt !== 1'b1) begin // cmd_snt hould have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by the RemoteComm.");
				$stop();
			end

			if(cmd_rdy !== 1'b1) begin // cmd_rdy should have been asserted when we have received a 2-byte packet of data.
				$display("ERROR: A 2-byte packet of data should have been received but was was not indicated by the UART_wrapper.");
				$stop();
			end

			if(cmd_sent !== cmd_received) begin // The data received should be the same as the data transmitted.
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", cmd_sent, cmd_received);
				$stop();
			end

			// Assert clr_cmd_rdy to knock down cmd_rdy.
			clr_cmd_rdy = 1'b1;
		end

		// Wait a clock cycle to check if cmd_rdy is deasserted.
		@(negedge clk) begin
			// Deassert clr_cmd_rdy.
			clr_cmd_rdy = 1'b0;

			if(cmd_rdy !== 1'b0) begin // cmd_rdy should have been deasserted as clr_cmd_rdy was asserted.
				$display("ERROR: cmd_rdy should have been knocked down by clr_cmd_rdy but was not.");
				$stop();
			end
		end


		/* TEST CASE 2 */
		cmd_sent = 16'h265D; // data to transmit over RemoteComm
		@(negedge clk) snd_cmd = 1'b1; // // assert snd_cmd and begin transmission
		
		// Deassert snd_cmd after one clock cycle.
		@(negedge clk) begin 
			snd_cmd = 1'b0; 

			if(cmd_snt !== 1'b0) begin // cmd_snt should have been deasserted as we are beginning transmission.
				$display("ERROR: A transmission just started so cmd_snt should have been low but was not.");
				$stop();
			end
		end

		repeat(30000) @(posedge clk); // Wait 30000 clock cycles, and check that cmd_snt and cmd_rdy is low. 

		// Check the values on the negative edge of clock.
		@(negedge clk) begin
			if(cmd_snt !== 1'b0) begin // cmd_snt should have been low
				$display("ERROR: A transmission was not complete but cmd_snt went high in RemoteComm.");
				$stop();
			end

			if(cmd_rdy !== 1'b0) begin // cmd_rdy should not have been asserted yet
				$display("ERROR: A packet of data is not ready yet but was indicated as ready by the UART_wrapper.");
				$stop();
			end
		end

		repeat(30000) @(posedge clk); // Wait 30000 more clock cycles, and check that data recieved is valid.

		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			if(cmd_snt !== 1'b1) begin // cmd_snt should have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by the RemoteComm.");
				$stop();
			end

			if(cmd_rdy !== 1'b1) begin // cmd_rdy should have been asserted when we have received a 2-byte packet of data.
				$display("ERROR: A 2-byte packet of data should have been received but was was not indicated by the UART_wrapper.");
				$stop();
			end

			if(cmd_sent !== cmd_received) begin // The data received should be the same as the data transmitted.
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", cmd_sent, cmd_received);
				$stop();
			end

			// Assert clr_cmd_rdy to knock down cmd_rdy.
			clr_cmd_rdy = 1'b1;
		end

		// Wait a clock cycle to check if cmd_rdy is deasserted.
		@(negedge clk) begin
			// Deassert clr_cmd_rdy.
			clr_cmd_rdy = 1'b0;

			if(cmd_rdy !== 1'b0) begin // cmd_rdy should have been deasserted as clr_cmd_rdy was asserted.
				$display("ERROR: cmd_rdy should have been knocked down by clr_cmd_rdy but was not.");
				$stop();
			end
		end

		/* TEST CASE 3 */
		cmd_sent = 16'h3967; // new data to transmit over RemoteComm
		@(negedge clk) snd_cmd = 1'b1; // begin transmission

		// Wait for a clock cycle to initialize system.
		@(negedge clk) begin 
			snd_cmd = 1'b0; // deassert snd_cmd after one clock cycle

			if(cmd_snt !== 1'b0) begin // cmd_snt should have been deasserted as we are beginning transmission.
				$display("ERROR: A transmission just started so cmd_snt should have been low but was not.");
				$stop();
			end
		end

		@(posedge cmd_snt); // Wait till 2 bytes are sent.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			if(cmd_sent !== cmd_received) begin // The data received should be the same as the data transmitted.
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", cmd_sent, cmd_received);
				$stop();
			end

			// Assert clr_cmd_rdy to knock down cmd_rdy.
			clr_cmd_rdy = 1'b1;
		end

		// Wait a clock cycle to check if cmd_rdy is deasserted.
		@(negedge clk) begin
			// Deassert clr_cmd_rdy.
			clr_cmd_rdy = 1'b0;
			
			if(cmd_rdy !== 1'b0) begin // cmd_rdy should have been deasserted as clr_cmd_rdy was asserted.
				$display("ERROR: cmd_rdy should have been knocked down by clr_cmd_rdy but was not.");
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