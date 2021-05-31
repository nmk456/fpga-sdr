`timescale 1ns / 1ns

module DataController (
    input eth_col,
    input eth_crs,
    output eth_mdc,
    inout eth_mdio,
    output eth_pcf,
    output eth_rstn,
    input eth_rxclk,
    input eth_rxdv,
    input eth_rxer,
    input[3:0] eth_rxd,
    input eth_txclk,
    output eth_txen,
    output[3:0] eth_txd
);

    // Serializer

    // Deserializer

    // Packetizer

    // Depacketizer

    // Ethernet MAC
    wire mdio_oen, mdio_out;

    assign eth_mdio = mdio_oen ? mdio_out : 1'bz;
    assign eth_pcf = 0;
    assign eth_rstn = 1;

    ethernet_ip eth0 (
        // Control port
        .clk(),             // Clock
        .reset(),           // Reset
        .reg_addr(),        // Register address
        .reg_data_out(),    // Data out
        .reg_rd(),          // Read request
        .reg_data_in(),     // Data in
        .reg_wr(),          // Write request
        .reg_busy(),        // Wait request

        // MAC status
        .set_10(1'b0),   // Set 10 Mbps mode
        .set_1000(1'b0), // Set 1000 Mbps mode
        .eth_mode(), // 1 if in 1000 Mbps mode, else 0
        .ena_10(),   // 1 if in 10 Mbps mode, else 0

        // MII
        .tx_clk(eth_txclk),     // Transmit clock
        .m_tx_d(eth_txd),       // Transmit data
        .m_tx_en(eth_txen),     // Transmit valid
        .m_tx_err(),            // Transmit error
        .rx_clk(eth_rxclk),     // Receive clock
        .m_rx_d(eth_rxd),       // Receive data
        .m_rx_en(eth_rxdv),     // Receive valid
        .m_rx_err(eth_rxer),    // Receive error
        .m_rx_crs(eth_crs),     // Carrier activity
        .m_rx_col(eth_col),     // Collision detection

        // Transmit stream interface
        .ff_tx_clk(),    // Clock
        .ff_tx_data(),   // Data
        .ff_tx_eop(),    // End of packet
        .ff_tx_err(),    // Error
        .ff_tx_mod(),    // Modulo
        .ff_tx_rdy(),    // Data ready
        .ff_tx_sop(),    // Start of packet
        .ff_tx_wren(),   // Write enable

        // Receive stream interface
        .ff_rx_clk(),    // Clock
        .ff_rx_data(),   // Data
        .ff_rx_eop(),    // End of packet
        .rx_err(),       // Error
        .ff_rx_mod(),    // Modulo
        .ff_rx_rdy(),    // Data ready
        .ff_rx_sop(),    // Start of packet
        .ff_rx_dval(),   // Data valid

        // PHY management - done
        .mdc(eth_mdc),      // Clock
        .mdio_in(eth_mdio),  // Data in
        .mdio_out(mdio_out), // Data out
        .mdio_oen(mdio_oen), // Output enable

        // Misc signals
        .ff_tx_crc_fwd(),    // CRC insertion (set to 0 when ff_tx_eop is 1 to automatically insert CRC)
        .ff_tx_septy(),      // Section empty
        .tx_ff_uflow(),      // Transmit underflow
        .ff_tx_a_full(),     // Transmit almost full
        .ff_tx_a_empty(),    // Transmit almost empty
        .rx_err_stat(),      // ?
        .rx_frm_type(),      // Frame type
        .ff_rx_dsav(),       // Frame available but not yet complete
        .ff_rx_a_full(),     // Receive almost full
        .ff_rx_a_empty()    // Receive almost empty
    );

endmodule
