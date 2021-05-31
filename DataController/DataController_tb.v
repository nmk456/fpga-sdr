`timescale 1ns / 1ns

module DataController_tb;

    reg clk = 0;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #10 clk = ~clk;
    end



    initial begin
        $dumpfile("DataController_tb.vcd");
        $dumpvars(0, DataController_tb);

        repeat(5) @(posedge clk);

        $finish;
    end

endmodule
