module ethernet_ip (
    input  wire        clk,           // control_port_clock_connection.clk
    input  wire        reset,         //              reset_connection.reset
    input  wire [7:0]  reg_addr,      //                  control_port.address
    output wire [31:0] reg_data_out,  //                              .readdata
    input  wire        reg_rd,        //                              .read
    input  wire [31:0] reg_data_in,   //                              .writedata
    input  wire        reg_wr,        //                              .write
    output wire        reg_busy,      //                              .waitrequest
    input  wire        tx_clk,        //   pcs_mac_tx_clock_connection.clk
    input  wire        rx_clk,        //   pcs_mac_rx_clock_connection.clk
    input  wire        set_10,        //         mac_status_connection.set_10
    input  wire        set_1000,      //                              .set_1000
    output wire        eth_mode,      //                              .eth_mode
    output wire        ena_10,        //                              .ena_10
    input  wire [3:0]  m_rx_d,        //            mac_mii_connection.mii_rx_d
    input  wire        m_rx_en,       //                              .mii_rx_dv
    input  wire        m_rx_err,      //                              .mii_rx_err
    output wire [3:0]  m_tx_d,        //                              .mii_tx_d
    output wire        m_tx_en,       //                              .mii_tx_en
    output wire        m_tx_err,      //                              .mii_tx_err
    input  wire        m_rx_crs,      //                              .mii_crs
    input  wire        m_rx_col,      //                              .mii_col
    input  wire        ff_rx_clk,     //      receive_clock_connection.clk
    input  wire        ff_tx_clk,     //     transmit_clock_connection.clk
    output wire [31:0] ff_rx_data,    //                       receive.data
    output wire        ff_rx_eop,     //                              .endofpacket
    output wire [5:0]  rx_err,        //                              .error
    output wire [1:0]  ff_rx_mod,     //                              .empty
    input  wire        ff_rx_rdy,     //                              .ready
    output wire        ff_rx_sop,     //                              .startofpacket
    output wire        ff_rx_dval,    //                              .valid
    input  wire [31:0] ff_tx_data,    //                      transmit.data
    input  wire        ff_tx_eop,     //                              .endofpacket
    input  wire        ff_tx_err,     //                              .error
    input  wire [1:0]  ff_tx_mod,     //                              .empty
    output wire        ff_tx_rdy,     //                              .ready
    input  wire        ff_tx_sop,     //                              .startofpacket
    input  wire        ff_tx_wren,    //                              .valid
    output wire        mdc,           //           mac_mdio_connection.mdc
    input  wire        mdio_in,       //                              .mdio_in
    output wire        mdio_out,      //                              .mdio_out
    output wire        mdio_oen,      //                              .mdio_oen
    input  wire        ff_tx_crc_fwd, //           mac_misc_connection.ff_tx_crc_fwd
    output wire        ff_tx_septy,   //                              .ff_tx_septy
    output wire        tx_ff_uflow,   //                              .tx_ff_uflow
    output wire        ff_tx_a_full,  //                              .ff_tx_a_full
    output wire        ff_tx_a_empty, //                              .ff_tx_a_empty
    output wire [17:0] rx_err_stat,   //                              .rx_err_stat
    output wire [3:0]  rx_frm_type,   //                              .rx_frm_type
    output wire        ff_rx_dsav,    //                              .ff_rx_dsav
    output wire        ff_rx_a_full,  //                              .ff_rx_a_full
    output wire        ff_rx_a_empty  //                              .ff_rx_a_empty
);



endmodule