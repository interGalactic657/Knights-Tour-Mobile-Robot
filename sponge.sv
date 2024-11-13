module sponge(clk, rst_n, go, piezo, piezo_n);

    parameter FAST_SIM = 1;      // Speeds up incrementing of duration for faster simulation

    input logic clk, rst_n;      // 50Mhz clock and asynchronous reset
    input logic go;              // Signal that initiates tune
    output logic piezo, piezo_n; // Output music to the piezo buzzer

    // Intermediate signals
    logic [14:0] note_period_cnt; 
    logic [23:0] dur_cnt;
    logic init, note_rst, dur_done;
    logic note_period, note_dur; // Note values set by the SM

    // Counter used to set the note frequency value
    // by counting up to the desired waveform period
    always_ff @(posedge clk) begin
        if (init)
            note_period_cnt <= 15'h0000;
        else if (note_rst)
            note_period_cnt <= 15'h0000;
        else
            note_period_cnt++;

    end

endmodule