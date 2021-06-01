`timescale 1ns / 1ns

module DataController (
    input clk,
    input rst,

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

    //                      47:40  39:32  31:24  23:16  15:8   7:0
    parameter source_mac = {8'h02, 8'h12, 8'h34, 8'h56, 8'h67, 8'h90};
    parameter dest_mac = {8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0}; // Change this

    parameter source_ip = {8'd10, 8'd0, 8'd0, 8'd2};
    parameter dest_ip = {8'd10, 8'd0, 8'd0, 8'd1};

    parameter source_port = 16'd32179;
    parameter dest_port = 16'd32179;

    // Serializer

    // Deserializer

    // Packetizer

    wire tx_clk, tx_eop, tx_err, tx_rdy, tx_sop, tx_wren;
    wire[31:0] tx_data;
    wire[1:0] tx_mod;

    wire tx_crc_fwd, tx_a_full, tx_a_empty;

    Packetizer #(
        .source_mac(source_mac),
        .dest_mac(dest_mac),
        .source_ip(source_ip),
        .dest_ip(dest_ip),
        .source_port(source_port),
        .dest_port(dest_port)
    ) packetizer0 (
        .clk(clk),
        .reset_n(~rst),

        .rd_en(),
        .rd_data({2'b10, 14'b01001001_001000, 2'b01, 14'b01010001_001000}),
        .rd_dr(1'b1),

        .tx_clk(tx_clk),
        .tx_data(tx_data),
        .tx_eop(tx_eop),
        .tx_err(tx_err),
        .tx_mod(tx_mod),
        .tx_rdy(tx_rdy),
        .tx_sop(tx_sop),
        .tx_wren(tx_wren),

        .tx_crc_fwd(tx_crc_fwd),
        .tx_a_full(tx_a_full),
        .tx_a_empty(tx_a_empty)
    );

    // Depacketizer

    // Ethernet MAC
    wire mdio_oen, mdio_out;

    assign eth_mdio = mdio_oen ? mdio_out : 1'bz;
    assign eth_pcf = 0;
    assign eth_rstn = 1;

    reg[7:0] mac_reg_addr;
    reg[31:0] mac_reg_din;
    wire[31:0] mac_reg_dout;
    reg mac_reg_rd, mac_reg_wr;
    wire mac_reg_busy;

    ethernet_ip eth0 (
        // Control port
        .clk(clk),                      // Clock
        .reset(rst),                    // Reset
        .reg_addr(mac_reg_addr),        // Register address
        .reg_data_out(mac_reg_dout),    // Data out
        .reg_rd(mac_reg_rd),            // Read request
        .reg_data_in(mac_reg_din),      // Data in
        .reg_wr(mac_reg_wr),            // Write request
        .reg_busy(mac_reg_busy),        // Wait request

        // MAC status
        .set_10(1'b0),   // Set 10 Mbps mode
        .set_1000(1'b0), // Set 1000 Mbps mode
        .eth_mode(), // 1 if in 1000 Mbps mode, else 0
        .ena_10(),   // 1 if in 10 Mbps mode, else 0

        // MII
        .tx_clk(eth_txclk),     // Transmit clock
        .m_tx_d(eth_txd),       // Transmit data
        .m_tx_en(eth_txen),     // Transmit valid
        .m_tx_err(),            // Transmit error - NC
        .rx_clk(eth_rxclk),     // Receive clock
        .m_rx_d(eth_rxd),       // Receive data
        .m_rx_en(eth_rxdv),     // Receive valid
        .m_rx_err(eth_rxer),    // Receive error
        .m_rx_crs(eth_crs),     // Carrier activity
        .m_rx_col(eth_col),     // Collision detection

        // Transmit stream interface
        .ff_tx_clk(tx_clk),    // Clock
        .ff_tx_data(tx_data),   // Data
        .ff_tx_eop(tx_eop),    // End of packet
        .ff_tx_err(tx_err),    // Error
        .ff_tx_mod(tx_mod),    // Modulo
        .ff_tx_rdy(tx_rdy),    // Data ready
        .ff_tx_sop(tx_sop),    // Start of packet
        .ff_tx_wren(tx_wren),   // Write enable

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
        .ff_tx_crc_fwd(tx_crc_fwd),    // CRC insertion (set to 0 when ff_tx_eop is 1 to automatically insert CRC)
        .ff_tx_septy(),      // Section empty
        .tx_ff_uflow(),      // Transmit underflow
        .ff_tx_a_full(tx_a_full),     // Transmit almost full
        .ff_tx_a_empty(tx_a_empty),    // Transmit almost empty
        .rx_err_stat(),      // ?
        .rx_frm_type(),      // Frame type
        .ff_rx_dsav(),       // Frame available but not yet complete
        .ff_rx_a_full(),     // Receive almost full
        .ff_rx_a_empty()    // Receive almost empty
    );

    // MAC config
    
    reg[7:0] step = 0;

    localparam CC_REG1 = 32'h00802220;
    localparam CC_REG2 = 32'h00800220;
    localparam CC_REG3 = 32'h00800223;

    always @(posedge clk) begin
        if (~mac_reg_busy) begin
            case (step)
                // Initial values
                8'd0: begin
                    mac_reg_addr <= 0;
                    mac_reg_din <= 0;
                    mac_reg_rd <= 0;
                    mac_reg_wr <= 0;

                    step <= step + 1;
                end

                // MDIO address
                8'd1: begin
                    mac_reg_addr <= 8'h0f;
                    mac_reg_wr <= 1;
                    mac_reg_din <= {27'b0, 5'h01};

                    step <= step + 1;
                end

                // Disable TX/RX
                8'd2: begin
                    mac_reg_addr <= 8'h02;
                    mac_reg_wr <= 1;
                    mac_reg_din <= CC_REG1;

                    step <= step + 1;
                end
                8'd3: begin
                    mac_reg_wr <= 0;
                    mac_reg_rd <= 1;

                    if (mac_reg_dout == CC_REG1) begin
                        step <= step + 1;
                        mac_reg_rd <= 0;
                    end
                end

                // MAC address
                8'd4: begin
                    mac_reg_addr <= 8'h03;
                    mac_reg_wr <= 1;
                    mac_reg_din <= {source_mac[23:16], source_mac[31:24], source_mac[39:32], source_mac[47:40]};

                    step <= step + 1;
                end
                8'd5: begin
                    mac_reg_addr <= 8'h04;
                    mac_reg_din <= {16'b0, source_mac[7:0], source_mac[15:8]};

                    step <= step + 1;
                end

                // Reset
                8'd6: begin
                    mac_reg_addr <= 8'h02;
                    mac_reg_wr <= 1;
                    mac_reg_din <= CC_REG1;

                    step <= step + 1;
                end
                8'd7: begin
                    mac_reg_wr <= 0;
                    mac_reg_rd <= 1;

                    if (mac_reg_dout == CC_REG2) begin
                        step <= step + 1;
                        mac_reg_rd <= 0;
                    end
                end

                // Enable TX/RX
                8'd8: begin
                    mac_reg_wr <= 1;
                    mac_reg_addr <= 2'h02;
                    mac_reg_din <= CC_REG3;

                    step <= step + 1;
                end

                8'd9: begin
                    mac_reg_wr <= 0;
                    mac_reg_rd <= 1;

                    if (mac_reg_dout == CC_REG3) begin
                        step <= step + 1;
                        mac_reg_rd <= 0;
                    end
                end

                default: begin
                    mac_reg_addr <= 0;
                    mac_reg_din <= 0;
                    mac_reg_rd <= 0;
                    mac_reg_wr <= 0;
                end
            endcase
        end
    end

endmodule
