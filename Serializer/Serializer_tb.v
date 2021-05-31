`timescale 1ns / 1ns

module Serializer_tb;

    reg clk = 0;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #10 clk = ~clk;
    end

    reg rst = 0;
    reg oe = 0;
    wire dr, txclk, tx;
    reg[7:0] data = 0;

    Serializer #(16) tx0(clk, rst, oe, data, dr, txclk, tx);

    initial begin
        $dumpfile("Serializer_tb.vcd");
        $dumpvars(0, Serializer_tb);

        repeat(5) @(posedge clk);

        oe <= 1;
        rst <= 1;

        repeat(100) @(posedge dr);

        $finish;
    end

    always @(posedge clk) begin
        if (dr) begin
            data <= data + 1;
        end
    end

endmodule
