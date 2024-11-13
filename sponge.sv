module sponge(clk, rst_n, go, piezo, piezo_n);

    parameter FAST_SIM = 1;      // Speeds up incrementing of duration for faster simulation

    input logic clk, rst_n;      // 50Mhz clock and asynchronous reset
    input logic go;              // Signal that initiates tune
    output logic piezo, piezo_n; // Output music to the piezo buzzer

    // Intermediate signals
    logic [14:0] note_period_cnt; 
    logic [23:0] dur_cnt;
    logic init, note_cnt_rst, dur_done;
    
    // Note values set by the SM
    logic [14:0] note_period;
    logic [23:0] note_dur;

    // Counter used to set the note frequency value
    // by counting up to the desired waveform period
    always_ff @(posedge clk) begin
        if (init)
            note_period_cnt <= 15'h0000;
        else if (note_cnt_rst)
            note_period_cnt <= 15'h0000;
        else
            note_period_cnt++;
    end

    assign note_rst = (note_period_cnt == note_period); // Reset note counter when reached desired frequency
    assign piezo = (not_period_cnt < (note_period / 2)); // When note count has reached half of desired note period,
                                                         // zero the output (50% duty cycle)

    // Counter used to set the note duration value
    // by counting up to the desired note 
    always_ff @(posedge clk) begin
        if (init)
            dur_cnt <= 24'h000000;
        else
            dur_cnt++;
    end

    assign dur_done = (dur_cnt == note_dur); // Indicate desired duration has been accomplished

    // State types for the state machine
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
    state_t state, nxt_state;

    // Sequential logic for the state machine
    always_ff @(posedge clk, negedge rst_n) begin
      if(!rst_n) 
        state <= IDLE; // Reset into the idle state if machine is reset.
      else
        state <= nxt_state; // Store the next state as the current state by default.
    end

    // Combinational logic for the state machine
    always_comb
    begin 
        case (state)
            // Default all SM outputs & nxt_state
            init = 1'b0;
            note_dur = 24'h800000;  // Duration of first note (D7, 2^23 clocks)
            note_period = 15'h5326; // Frequency of first note (D7, 2349Hz)
            nxt_state = state;
            
            D7: begin
                if (dur_done) begin
                    nxt_state = E7;
                    init = 1'b1;
                end
            end

            E7: begin
                note_period = 15'h4A11; // Freq = 2637Hz
                if (dur_done) begin
                    nxt_state = F7;
                    init = 1'b1;
                end
            end

            F7: begin
                note_period = 15'h45E7; // Freq = 2794Hz
                if (dur_done) begin
                    nxt_state = E7_2;
                    init = 1'b1;
                end
            end

            E7_2: begin
                note_dur = 24'hC00000;  // Duration = 2^23 + 2^22 clocks
                note_period = 15'h4A11; // Freq = 2637Hz
                if (dur_done) begin
                    nxt_state = F7_2;
                    init = 1'b1;
                end
            end

            F7_2: begin
                note_dur = 24'h400000;  // Duration = 2^22 clocks
                note_period = 14'h45E7; // Freq = 2794Hz
                if (dur_done) begin
                    nxt_state = D7_2;
                    init = 1'b1;
                end
            end

            D7_2: begin
                note_dur = 24'hC00000; // Duration = 2^23 + 2^22 clocks
                if (dur_done) begin
                    nxt_state = A6;
                    init = 1'b1;
                end
            end

            A6: begin
                note_dur = 24'h400000;  // Duration = 2^22 clocks
                note_period = 15'h6EF9; // Freq = 2349Hz
                if (dur_done) begin
                    nxt_state = D7_3;
                    init = 1'b1;
                end
            end

            D7_3: begin
                if (dur_done)
                    nxt_state = IDLE;
            end

            // Default Case = IDLE //
            default: begin
                note_dur = 24'h000000; 
                note_period = 15'h0000; // TODO: Figure out how to turn off the sound (or if this works)
                if (go) begin
                    nxt_state = D7;
                    init = 1'b1;
                end
            end
        endcase 
    end

endmodule