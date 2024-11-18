/////////////////////////////////////////////
// sponge.sv                               //
// Plays the last measure of the           //
// SpongeBob theme when Knight finishes a   //
// move in an L-shape.                     //
/////////////////////////////////////////////
module sponge(
    input logic clk,            // 50 MHz clock input.
    input logic rst_n,          // Asynchronous active low reset.
    input logic go,             // Signal to initiate the tune.
    output logic piezo,         // Output signal for piezo buzzer (high for sound).
    output logic piezo_n        // Complement of piezo, used for active-low buzzer operation.
);

    // Parameter to speed up simulation duration increments
    parameter FAST_SIM = 1;      // Speeds up the simulation by incrementing duration faster in simulation mode.

    ////////////////////////////////////////
    // Declare state types as enumerated //
    //////////////////////////////////////  
    typedef enum logic [3:0] {
        IDLE,     // Idle state, no music playing.
        D7,       // Note D7 (first note in melody).
        E7,       // Note E7.
        F7,       // Note F7.
        E7_2,     // Note E7 second time.
        F7_2,     // Note F7 second time.
        D7_2,     // Note D7 second time.
        A6,       // Note A6.
        D7_3      // Note D7 third time.
    } state_t;

    /////////////////////////////////////////////////
    // Declare any internal signals as type logic //
    /////////////////////////////////////////////////
    logic [14:0] note_period_cnt; // Signal to count the note period (frequency).
    logic [23:0] dur_cnt;         // Signal to count the duration of the note.    
    logic [14:0] note_period;     // Period of the current note.
    logic [23:0] note_dur;        // Duration of the current note.
    logic clr_cnt;                // Asserted whenever we move to a new note, to clear the count.
    logic note_cnt_rst;           // Asserted whenever we the note period count equals the note period.
    logic dur_done;               // Asserted whenever the duration of the note is done.
    logic [4:0] inc_amt;          // Amount to increment the duration counter by based on FAST_SIM.
    state_t state;                // Holds the current state.
    state_t nxt_state;            // Holds the next state.
    //////////////////////////////////////////////////////////////////////////

    /************ Note Period Counter ************/
    // This counter tracks the note period, counting up to the desired note period.
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            note_period_cnt <= 15'h0000;     // Reset the counter on reset.
        else if (clr_cnt)
            note_period_cnt <= 15'h0000;     // Clear the counter when clr_cnt is asserted.
        else if (note_cnt_rst)
            note_period_cnt <= 15'h0000;     // Clear the counter when note_cnt_rst is asserted.
        else
            note_period_cnt <= note_period_cnt + 1'b1; // Increment counter each clock cycle.
    end
    
    // Reset note counter when reached desired frequency.
    assign note_cnt_rst = (note_period_cnt >= note_period); 

    /************ Note Duration Counter ************/
    // This counter tracks the duration of the current note.
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            dur_cnt <= 24'h000000;          // Reset the duration counter on reset.
        else if (clr_cnt)
            dur_cnt <= 24'h000000;          // Clear the duration counter when clr_cnt is asserted.
        else
            dur_cnt <= dur_cnt + inc_amt;
    end

    // When the duration counter reaches the desired duration, it indicates the note has finished.
    assign dur_done = (dur_cnt >= note_dur);

    generate
            if (FAST_SIM)
                assign inc_amt = 5'h10; // Increment faster (by 16) in simulation mode for quicker testing.
            else
                assign inc_amt = 5'h01; // Increment normally in non-fast simulation mode.
    endgenerate

    // Piezo buzzer output: when the counter reaches half the period, the output toggles (50% duty cycle).
    assign piezo = (note_period_cnt < ({1'b0, note_period[14:1]}));
    assign piezo_n = ~piezo; // Complement of piezo signal.
    ///////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////
    // Implement State Machine Logic //
    //////////////////////////////////

    // Implements state machine register, holding current state or next state, accordingly.
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;   // Reset into the IDLE state if machine is reset.
        else
            state <= nxt_state; // Store the next state as the current state by default.
    end

    //////////////////////////////////////////////////////////////////////////////////////////
    // Implements the combinational state transition and output logic of the state machine. //
    //////////////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        /* Default all SM outputs & nxt_state */
        clr_cnt = 1'b0;           // By default, we are not clearing the period/duration counters.
        note_dur = 24'h800000;    // Default duration for the first note (D7).
        note_period = 15'h5326;   // Default frequency for the first note (D7).
        nxt_state = state;        // Default to hold the current state.

        case (state)
            // Note D7
            IDLE: begin
                note_dur = 24'h000000;
                note_period = 15'h0000;
                if (go) begin
                    nxt_state = D7;     // Start the melody from D7 when the 'go' signal is active.
                    clr_cnt = 1'b1;     // Clear the counter to start a new note.
                end
            end

            D7: begin
                if (dur_done) begin
                    nxt_state = E7;      // Move to E7 when the duration is completed.
                    clr_cnt = 1'b1;      // Clear the counter to start a new note.
                end
            end

            // Note E7
            E7: begin
                note_period = 15'h4A11;  // Frequency for E7 (2637 Hz).
                if (dur_done) begin
                    nxt_state = F7;      // Move to F7 when the duration is completed.
                    clr_cnt = 1'b1;      // Clear the counter to start a new note.
                end
            end

            // Note F7
            F7: begin
                note_period = 15'h45E7;  // Frequency for F7 (2794 Hz).
                if (dur_done) begin
                    nxt_state = E7_2;    // Move to E7 second time when the duration is completed.
                    clr_cnt = 1'b1;      // Clear the counter to start a new note.
                end
            end

            // Note E7 (second time)
            E7_2: begin
                note_dur = 24'hC00000;  // Set duration to 2^23 + 2^22 clocks.
                note_period = 15'h4A11; // Frequency for E7 second time.
                if (dur_done) begin
                    nxt_state = F7_2;    // Move to F7 second time when the duration is completed.
                    clr_cnt = 1'b1;      // Clear the counter to start a new note.
                end
            end

            // Note F7 (second time)
            F7_2: begin
                note_dur = 24'h400000;  // Set duration to 2^22 clocks.
                note_period = 15'h45E7; // Frequency for F7 second time.
                if (dur_done) begin
                    nxt_state = D7_2;    // Move to D7 second time when the duration is completed.
                    clr_cnt = 1'b1;      // Clear the counter to start a new note.
                end
            end

            // Note D7 (second time)
            D7_2: begin
                note_dur = 24'hC00000;  // Set duration to 2^23 + 2^22 clocks.
                if (dur_done) begin
                    nxt_state = A6;     // Move to A6 when the duration is completed.
                    clr_cnt = 1'b1;     // Clear the counter to start a new note.
                end
            end

            // Note A6
            A6: begin
                note_dur = 24'h400000;  // Set duration to 2^22 clocks.
                note_period = 15'h6EF9; // Frequency for A6 (2349 Hz).
                if (dur_done) begin
                    nxt_state = D7_3;   // Move to D7 third time when the duration is completed.
                    clr_cnt = 1'b1;     // Clear the counter to start a new note.
                end
            end

            // Note D7 (third time)
            D7_3: begin
                if (dur_done)
                    nxt_state = IDLE;  // Move to IDLE state when the duration is completed.
            end

            // Default case (IDLE state)
            default: begin
                nxt_state = IDLE;
            end
        endcase
    end
endmodule
