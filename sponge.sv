module sponge(clk, rst_n, go, piezo, piezo_n);

    parameter FAST_SIM = 1;      // Speeds up incrementing of duration for faster simulation

    input logic clk, rst_n;      // 50Mhz clock and asynchronous reset
    input logic go;              // Signal that initiates tune
    output logic piezo, piezo_n; // Output music to the piezo buzzer

    // Intermediate signals
    logic [14:0] note_period_cnt; 
    logic [23:0] dur_cnt;
    logic init, note_rst_n, dur_done;
    
    // Note values set by the SM
    logic [15:0] note_period;
    logic [23:0] note_dur;

    //state types for the state machine
    typedef enum logic [3:0] {
        IDLE,
        D7,
        E7,
        F7,
        E7_2,
        F7_2,
        D7_2,
        A6,
        D7_3,
    } state_t;

    state_t state, next_state;

    //Sequential logic for the state machine
    always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n)
        begin
        state <= IDLE; // Reset into the idle state if machine is reset.
        end
      else
        begin
        state <= nxt_state; // Store the next state as the current state by default.
        end
    end

    // Combinational logic for the state machine
    always_comb
    begin 
        case (state)
            // Default all SM outputs & nxt_state
            note_rst_n = 1'b1;
            piezo = 1'b0;
            piezo_n = 1'b1;
            dur_done = 1'b0;
            note_dur = 24'h800000;
            next_state = state;
            
            IDLE: begin
                if (go)
                    begin
                        next_state = D7;
                        init = 1'b1;
                        note_rst_n = 1'b0;
                    end
            end

            D7: begin
                note_dur = 24'h800000;
                if (dur_done)
                    begin
                    next_state = E7;
                    note_rst_n = 1'b0;
                    end
            end
            E7: begin
                note_dur = 24'h800000;
                if (dur_done)
                    begin
                    next_state = F7;
                    note_rst_n = 1'b0;
                    end
            end
            F7: begin
                note_dur = 24'h800000;
                if (dur_done)
                    begin
                    next_state = E7_2;
                    note_rst_n = 1'b0;
                    end
            end
            E7_2: begin
                note_dur = 24'hC00000;
                if (dur_done)
                    begin
                    next_state = F7_2;
                    note_rst_n = 1'b0;
                    end
            end

            F7_2: begin
                note_dur = 24'h400000;
                if (dur_done)
                    begin
                    next_state = D7_2;
                    note_rst_n = 1'b0;
                    end
            end

            D7_2: begin
                note_dur = 24'hC00000;
                if (dur_done)
                    next_state = A6;
                    note_rst_n = 1'b0;
          
            end
            A6: begin
                note_dur = 24'h400000;
                if (dur_done)
                    next_state = D7_3;
                    note_rst_n = 1'b0;
            end
            D7_3: begin
                note_dur = 24'h800000;
                if (dur_done)
                    next_state = IDLE;
                    note_rst_n = 1'b0;
            end
            default: begin
                next_state = IDLE;
            end
        endcase 
    end

    // Counter used to set the note frequency value
    // by counting up to the desired waveform period
    always_ff @(posedge clk or negedge note_rst_n) begin
        if (init)
            note_period_cnt <= 15'h0000;
        else if (note_rst_n)
            note_period_cnt <= 15'h0000;
        else
            note_period_cnt++;

    end

endmodule