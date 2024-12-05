//////////////////////////////////////////////////////
// UART_tb.sv                                      //
// This testbench simulates the UART transmit and //
// receive blocks checking if data transmission. //
// was accurate.                                //
/////////////////////////////////////////////////
module UART_tb();
  
  logic clk,rst_n;// Clock and active low asynchronous reset.
  logic trmt;	 // Asserted for 1 clock to initiate transmission.
  logic [7:0] tx_data; // Byte to transmit.
  logic tx_done;	// Asserted when byte is done transmitting. Stays high till next byte transmitted. 
  logic TX;		// Serial data output.
  logic clr_rdy;	// Knocks down rdy when asserted.
  logic [7:0] rx_data; // Byte received.
  logic [7:0] expected_rx_data; // Expected byte to be received.
  logic rdy;		// Asserted when byte received. Stays high till start bit of next byte starts, or until clr_rdy asserted.
  
  /////////////////////////////////////////////////
  // Instantiate the UART_tx and UART_rx blocks //
  ///////////////////////////////////////////////
  UART_tx iTX(.clk(clk), .rst_n(rst_n), .trmt(trmt), .tx_data(tx_data), .tx_done(tx_done), .TX(TX));
  UART_rx iRX(.clk(clk), .rst_n(rst_n), .RX(TX), .clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy)); // Connect the TX of the transmitter to the RX of the receiver.

  // Test various scenarios including whether 
  // data transmitted is data received as well as
  // system signals of each DUT. 			  
  initial begin
		clk = 1'b0; // initially clock is low
		rst_n = 1'b0; // reset the machines
		tx_data = 8'h00; // initial data to transmit
		trmt = 1'b0; // trmt initially is low, i.e. inactive
		clr_rdy = 1'b0; // initially clr_rdy is low
		//// wait 1.5 clocks for reset ////
		@(posedge clk);
		@(negedge clk) begin 
			rst_n = 1'b1; // Deassert reset on a negative edge of clock.
			trmt = 1'b1; // // assert trmt to begin transmission
		end

		@(posedge clk); // Wait for a clock cycle to initialize system.
		@(negedge clk) trmt = 1'b0; // deassert trmt after one clock cycle
		
		/* TEST CASE 1 */
		repeat(28000) @(posedge clk); // Wait 28000 clock cycles, and ensure that data is transmitted to the receiver.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			expected_rx_data = 8'h00; // expect the receiver to have the same data as sent from the transmitter

			if(tx_done !== 1'b1) begin // tx_done should have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by the transmitter.");
				$stop();
			end

			if(rdy !== 1'b1) begin // rdy should have been asserted when we have received a packet of data
				$display("ERROR: A packet of data should have been received but was was not indicated by the receiver.");
				$stop();
			end

			if(rx_data !== expected_rx_data) begin // The data received should be the same as the data transmitted
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", expected_rx_data, rx_data);
				$stop();
			end
		end

		/* TEST CASE 2 */
		@(negedge clk) clr_rdy = 1'b1; // Reset the receiver status on negative edge of clock.
        @(posedge clk); // Wait for a clock cycle for clear to propagate to the output

        @(negedge clk) begin // Check if rdy is knocked down by clr_rdy.
			clr_rdy = 1'b0; // deassert clr_rdy

			if(rdy !== 1'b0) begin // rdy should have been cleared
				$display("ERROR: clr_rdy was asserted so rdy should have been 0x0 but was 0x%h", rdy);
				$stop();
			end
		end
		
		tx_data = 8'hBC; // New data to transmit
		@(negedge clk) trmt = 1'b1; // Assert the transmit signal
	
		@(posedge clk); // Wait for a clock cycle, to deassert trmt.
		@(negedge clk) trmt = 1'b0; // Deassert the transmit signal
	
		repeat(28000) @(posedge clk); // Wait 28000 clock cycles, and ensure that data is transmitted to the receiver.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			expected_rx_data = 8'hBC; // expect the receiver to have the same data as sent from the transmitter

			if(tx_done !== 1'b1) begin // tx_done should have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by the transmitter.");
				$stop();
			end

			if(rdy !== 1'b1) begin // rdy should have been asserted when we have received a packet of data
				$display("ERROR: A packet of data should have been received but was was not indicated by the receiver.");
				$stop();
			end

			if(rx_data !== expected_rx_data) begin // The data received should be the same as the data transmitted
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", expected_rx_data, rx_data);
				$stop();
			end
		end
        
		/* TEST CASE 3 */
		@(negedge clk) clr_rdy = 1'b1; // Reset the receiver status on negative edge of clock.
		@(posedge clk); // Wait for a clock cycle for clear to propagate to the output

        @(negedge clk) begin // Check if rdy is knocked down by clr_rdy.
			clr_rdy = 1'b0; // deassert clr_rdy

			if(rdy !== 1'b0) begin // rdy should have been cleared
				$display("ERROR: clr_rdy was asserted so rdy should have been 0x0 but was 0x%h", rdy);
				$stop();
			end
		end 
		
		tx_data = 8'h7F; // New data to transmit
		@(negedge clk) trmt = 1'b1; // Assert the transmit signal
	
		@(posedge clk); // Wait for a clock cycle, to deassert trmt.
		@(negedge clk) trmt = 1'b0; // Deassert the transmit signal
	
		repeat(28000) @(posedge clk); // Wait 28000 clock cycles, and ensure that data is transmitted to the receiver.
		
		// Check the received value on the negative edge of clock.
		@(negedge clk) begin
			expected_rx_data = 8'h7F; // expect the receiver to have the same data as sent from the transmitter

			if(tx_done !== 1'b1) begin // tx_done should have been asserted after the end of a transmission
				$display("ERROR: A transmission was complete but was not indicated by the transmitter.");
				$stop();
			end

			if(rdy !== 1'b1) begin // rdy should have been asserted when we have received a packet of data
				$display("ERROR: A packet of data should have been received but was was not indicated by the receiver.");
				$stop();
			end

			if(rx_data !== expected_rx_data) begin // The data received should be the same as the data transmitted
				$display("ERROR: Data received should have been: 0x%h, but actual was: 0x%h.\n", expected_rx_data, rx_data);
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