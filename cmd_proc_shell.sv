module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
				frwrd,moving,tour_go,fanfare_go);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input [15:0] cmd;					// command from BLE
  input cmd_rdy;					// command ready
  output logic clr_cmd_rdy;			// mark command as consumed
  output logic send_resp;			// command finished, send_response via UART_wrapper/BT
  output logic strt_cal;			// initiate calibration of gyro
  input cal_done;					// calibration of gyro done
  input signed [11:0] heading;		// heading from gyro
  input heading_rdy;				// pulses high 1 clk for valid heading reading
  input lftIR;						// nudge error +
  input cntrIR;						// center IR reading (have I passed a line)
  input rghtIR;						// nudge error -
  output reg signed [11:0] error;	// error to PID (heading - desired_heading)
  output reg [9:0] frwrd;			// forward speed register
  output logic moving;				// asserted when moving (allows yaw integration)
  output logic tour_go;				// pulse to initiate TourCmd block
  output logic fanfare_go;			// kick off the "Charge!" fanfare on piezo

  <<< Your implementation here >>>
  
endmodule
  