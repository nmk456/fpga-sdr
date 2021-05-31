`timescale 1ns / 1ns

module Depacketizer_tb;

    reg clk = 0;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #10 clk = ~clk;
    end



    initial begin
        $dumpfile("Depacketizer_tb.vcd");
        $dumpvars(0, Depacketizer_tb);

        repeat(5) @(posedge clk);

        $finish;
    end

endmodule
