module cmd_proc(clk,rst_n,cmd,cmd_rdy,clr_cmd_rdy,send_resp,strt_cal,
                cal_done,heading,heading_rdy,lftIR,cntrIR,rghtIR,error,
                frwrd,moving,tour_go,fanfare_go);
                
  parameter FAST_SIM = 1;              // speeds up incrementing of frwrd register for faster simulation
                
  input clk,rst_n;                     // 50MHz clock and asynch active low reset

  input [15:0] cmd;                    // command from BLE
  input cmd_rdy;                       // command ready
  output logic clr_cmd_rdy;            // mark command as consumed
  output logic send_resp;              // command finished, send_response via UART_wrapper/BT

  output logic strt_cal;               // initiate calibration of gyro
  input cal_done;                      // calibration of gyro done
  input signed [11:0] heading;         // heading from gyro
  input heading_rdy;                   // pulses high 1 clk for valid heading reading

  output logic moving;                 // asserted when moving (allows yaw integration)

  output reg signed [11:0] error;      // error to PID (heading - desired_heading)
  output reg [9:0] frwrd;              // forward speed register
  
  input lftIR;                         // nudge error +
  input cntrIR;                        // center IR reading (have I passed a line)
  input rghtIR;                        // nudge error -

  output logic tour_go;                // pulse to initiate TourCmd block
  output logic fanfare_go;             // kick off the "Charge!" fanfare on piezo

  ////////////////////////////////////////
  // Declare state types as enumerated //
  //////////////////////////////////////
  // We have ? states
  typedef enum logic [1:0] {IDLE, ???} state_t;

  // Declare state signals
  state_t state, nxt_state;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////


  //////////////////////////////////////
  // Count the squares as the Knight //
  // passes reflectve bands         //
  ///////////////////////////////////
  // Implement counter to count number of bits shifted out on the MOSI line.
  always_ff @(posedge clk) begin
      bit_cntr <=  (init)  ? 5'h0          : // Reset to 0 initially.
                   (shift) ? bit_cntr + 1  : // Increment the bit count whenever we shift a bit.
                   bit_cntr; // Otherwise hold current value.
  end

  ///////////////////////////////////////////////
  // Determine if cntrlIR is on a rising edge //
  /////////////////////////////////////////////


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

  // Implements the combinational state transition and output logic of the state machine.
  always_comb begin
  /////////////////////////////////////////
  // Default all SM outputs & nxt_state //
  ///////////////////////////////////////
    case (state)
      default : begin 
        
      end
      ???? : begin 
        
      end
      ???? : begin
        
      end
    endcase
  end
endmodule