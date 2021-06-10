`timescale 1ns / 1ns

module DataController_tb;

    reg clk = 0;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #1 clk = ~clk;
    end

    DataController ctl0 (
        .clk(clk),
        .rst(1'b0)
    );

    initial begin
        $dumpfile("DataController_tb.vcd");
        $dumpvars(0, DataController_tb);

        repeat(1000) @(posedge clk);

        $finish;
    end

endmodule
