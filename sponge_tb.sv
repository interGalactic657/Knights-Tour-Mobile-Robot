module sponge_tb();

//Signals for sponge dut
logic clk;
logic rst_n;
logic go;
logic piezo;
logic piezo_n;

//Creatin dut
sponge SpongeDut(.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));

initial begin
    clk = 1'b0; //clk starts low initially
    rst_n = 1'b0; //to reset the machine

    repeat(10) @(posedge clk);

    @(negedge clk) begin
        rst_n = 1'b1;
        go = 1'b1;
    end
end

always
    #5 clk = ~clk; // toggle clock every 5 time units

endmodule