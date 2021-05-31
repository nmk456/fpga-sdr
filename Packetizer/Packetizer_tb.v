`timescale 1ns / 1ns

module Packetizer_tb;

    reg clk = 1;

    // Clk generator 50 MHz at 1ns time unit
    always begin
        #1 clk = ~clk;
    end

    reg rstn = 1;
    wire crc_fwd;
    reg a_full = 0;
    reg a_empty = 0;

    wire rd_en;
    wire[31:0] rd_data;
    reg rd_dr = 1;

    // Avalon-ST bus
    wire tx_clk;
    wire[31:0] tx_data;
    wire tx_eop, tx_err, tx_sop, tx_wren;
    wire[1:0] tx_mod;

    // reg tx_rdy = 1;
    wire tx_rdy;
    
    Packetizer packetizer0 (
        clk,
        rstn,

        rd_en,
        rd_data,
        rd_dr,

        tx_clk, tx_data,
        tx_eop, tx_err, tx_mod, tx_rdy, tx_sop, tx_wren,

        crc_fwd, a_full, a_empty
    );

    MacSim mac0 (tx_clk, tx_data, tx_eop, tx_err, tx_mod, tx_rdy, tx_sop, tx_wren);

    initial begin
        $dumpfile("Packetizer_tb.vcd");
        $dumpvars(0, Packetizer_tb);

        repeat(20) @(posedge clk);

        while (~tx_eop) begin
            @(posedge clk);
        end

        repeat(50) @(posedge clk);

        $finish;
    end

    reg[31:0] iqdata[2927:0];
    reg[11:0] iqaddr = 0;

    assign rd_data = iqdata[iqaddr];

    initial begin
        $readmemb("IQdata.txt", iqdata);
    end

    always @(posedge clk) begin
        if (rd_en) begin
            iqaddr <= iqaddr + 1;
        end
    end

endmodule
