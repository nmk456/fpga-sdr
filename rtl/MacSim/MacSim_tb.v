`timescale 1ns / 1ns

module MacSim_tb;

    reg clk = 0;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #10 clk = ~clk;
    end

    reg[31:0] data;
    reg eop;
    reg err;
    reg[1:0] mod;
    wire rdy;
    reg sop;
    reg wren;
    reg[7:0] counter = 0;

    wire[7:0] counter0 = counter;
    wire[7:0] counter1 = counter + 1;
    wire[7:0] counter2 = counter + 2;
    wire[7:0] counter3 = counter + 3;

    MacSim mac0 (clk, data, eop, err, mod, rdy, sop, wren);

    initial begin
        $dumpfile("MacSim_tb.vcd");
        $dumpvars(0, MacSim_tb);

        eop = 0;
        err = 0;
        mod = 0;
        sop = 0;
        wren = 0;
        data = 0;

        repeat(10) @(posedge clk);

        sop = 1;
        wren = 1;
        data = {counter0, counter1, counter2, counter3};

        @(posedge clk);

        sop = 0;

        repeat(50) begin
            counter = counter + 4;
            data = {counter0, counter1, counter2, counter3};
            @(posedge clk);
        end

        counter = counter + 4;
        data = {counter0, counter1, counter2, counter3};
        eop = 1;

        @(posedge clk);

        eop = 0;
        wren = 0;

        repeat(100) @(posedge clk);

        $finish;
    end

endmodule
