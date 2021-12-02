`timescale 1ns / 1ns

module DataController (
    input clk,
    input rst,

    input eth_txclk,
    output eth_txen,
    output[3:0] eth_txd,
    output eth_rstn
);

    parameter DEST_MAC = {8'hff, 8'h0, 8'hff, 8'h0, 8'hff, 8'h0};

    wire tx_tlast, tx_tuser, tx_tready, tx_tvalid, tx_a_full, tx_a_empty;
    wire[7:0] tx_tdata;

    /* verilator lint_off PINMISSING */
    Packetizer #(
        .DEST_MAC(DEST_MAC)
    ) packetizer0 (
        .clk(clk),
        .rst(rst),

        .lvds_tdata(32'h8c63436c),
        .lvds_tready(),
        .lvds_tvalid(1'b1),

        .tx_tdata(tx_tdata),
        .tx_tlast(tx_tlast),
        .tx_tuser(tx_tuser),
        .tx_tready(tx_tready),
        .tx_tvalid(tx_tvalid)//,

        // .tx_a_full(tx_a_full),
        // .tx_a_empty(tx_a_empty)
    );

    SimpleMac mac0 (
        .rst(rst),

        .eth_txclk(eth_txclk),
        .eth_txen(eth_txen),
        .eth_txd(eth_txd),
        .eth_rstn(eth_rstn),

        .tx_clk(clk),
        .tx_tdata(tx_tdata),
        .tx_tlast(tx_tlast),
        .tx_tuser(tx_tuser),
        .tx_tready(tx_tready),
        .tx_tvalid(tx_tvalid),

        .tx_a_full(tx_a_full),
        .tx_a_empty(tx_a_empty)
    );
    /* verilator lint_on PINMISSING */

endmodule
