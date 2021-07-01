# FPGA SDR Code

Individual modules have more detailed readme files, but in summary, this project allows a AT86RF215 transceiver to be controlled over Ethernet and send/receive IQ data from GNU Radio.

## Status

| Module | Status | Testbench | Test Results |
| --- | --- | --- | --- |
| Serializer | Functional | Functional | Passing |
| Deserializer | In progress | In progress | N/A |
| Packetizer | In progress | In progress | N/A |
| Depacketizer | Not started | Not started | N/A |
| SimpleMac | TX Functional | TX Functional | Passing |
| DataController | In progress | In progress | N/A |

## Modules

### Serializer

Sends data over LVDS using word structure defined in AT86RF215 datasheet page 24. Data input is captured when both data_valid and data_ready are asserted.

DDR functionality relies on generated Intel IP, so a non-synthesizable equivalent is used for simulation. It might actually be synthesizable in this specific case, but using the generated IP will almost definitely work better.

TODO: Verify reset behavior.

#### Ports

| Name | Direction | Description |
| --- | --- | --- |
| clk | input | 64 MHz clock input |
| rst | input | Synchronous reset, active high |
| idata_in | input | 14 bit I data |
| qdata_in | input | 14 bit Q data |
| data_valid | input | Data valid |
| data_ready | output | Data ready |
| txclk | output | LVDS clock |
| tx | output | LVDS data |

#### States

* STATE_INIT - only active after reset, initializes values to default
* STATE_WAIT - wait period at transmission start
* STATE_I_DATA - I data
* STATE_Q_DATA - Q data

#### Timing Diagram

![Serializer Timing Diagram](./docs/LVDS32TX_Timing.svg)

### Deserializer

Receives data over LVDS using word structure defined in AT86RF215 datasheet page 24. Contains a 256 word deep FIFO to cross from LVDS clock domain into FPGA clock domain.

DDR functionality relies on generated Intel IP, so a non-synthesizable equivalent is used for simulation.

### Packetizer

### Depacketizer

### SimpleMac

Sends and receives packets over ethernet with Avalon-ST bus. Currently, only TX is implemented. Stores data in a 4096 entry deep FIFO, enough to store 2 packets. The MAC transmits the data packets received over the Avalon-ST bus, with the ethernet preamble added to the beginning and the FCS added to the end. The testbench transmits random data over the Avalon-ST bus and checks to see if the same data is sent over the MII interface. It also verifies the FCS that is inserted at the end of the packet.

FIFO memory format (10 bits wide): {tx_eop, tx_sop, tx_data[7:0]}

#### Ports

| Name | Direction | Description |
| --- | --- | --- |
| rst | input | Synchronous reset to tx_clk, active high |
| eth_txclk | input | MII TX Clock (25 MHz) |
| eth_txen | output | MII TX Enable |
| eth_txd | output | MII TX Data (4 bits) |
| eth_rxclk | input | MII RX Clock |
| eth_rxdv | input | MII RX Data Valid |
| eth_rxer | input | MII RX Error |
| eth_rxd | input | MII RX Data (4 bits) |
| eth_col | input | MII Collision Detect |
| eth_crs | input | MII Carrier Sense |
| eth_pcf | output | MII PHY Control Frame Enable |
| eth_rstn | output | MII Reset, active low |
| tx_clk | input | Avalon-ST TX Clock |
| tx_data | input | Avalon-ST TX Data |
| tx_sop | input | Avalon-ST TX Start of Packet |
| tx_eop | input | Avalon-ST TX End of Packet |
| tx_err | input | Avalon-ST TX Error |
| tx_rdy | output | Avalon-ST TX Data Ready |
| tx_wren | input | Avalon-ST TX Write Enable |
| tx_a_full | output | Avalon-ST TX Almost Full |
| tx_a_empty | output | Avalon-ST TX Almost Empty |

#### Timing Diagram

![SimpleMac Timing Diagram](./docs/SimpleMac_Timing.svg)

#### CRC32

This module compute the CRC to be inserted at the end of the ethernet frame. The module is based on a parametrizable module from [Alex Forencich](https://github.com/alexforencich/verilog-ethernet). A simple testbench generates some random data and compares the resulting CRC to one generated with a known good library.

### DataController
