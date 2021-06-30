module PacketizerSimpleMac (
    input clk_50,
    input rst,

    input eth_txclk,
    output eth_txen,
    output[3:0] eth_txd,
    output eth_rstn
);

    parameter DEST_MAC = {8'hff, 8'h0, 8'hff, 8'h0, 8'hff, 8'h0};

    wire tx_clk, tx_eop, tx_err, tx_rdy, tx_sop, tx_wren, tx_a_full, tx_a_empty;
    wire[7:0] tx_data;

    Packetizer #(
        .DEST_MAC(DEST_MAC)
    ) packetizer0 (
        .clk(clk_50),
        .rst(rst),

        .rd_en(),
        .rd_data(32'h8c63436c),
        .rd_dr(1'b1),

        .tx_clk(tx_clk),
        .tx_data(tx_data),
        .tx_eop(tx_eop),
        .tx_err(tx_err),
        .tx_rdy(tx_rdy),
        .tx_sop(tx_sop),
        .tx_wren(tx_wren),
        .tx_a_full(tx_a_full),
        .tx_a_empty(tx_a_empty)
    );

    /* verilator lint_off PINMISSING */
    SimpleMac mac0 (
        .rst(rst),

        .eth_txclk(eth_txclk),
        .eth_txen(eth_txen),
        .eth_txd(eth_txd),
        .eth_rstn(eth_rstn),

        .tx_clk(tx_clk),
        .tx_data(tx_data),
        .tx_sop(tx_sop),
        .tx_eop(tx_eop),
        .tx_err(tx_err),
        .tx_rdy(tx_rdy),
        .tx_wren(tx_wren),
        .tx_a_full(tx_a_full),
        .tx_a_empty(tx_a_empty)
    );
    /* verilator lint_on PINMISSING */

endmodule
