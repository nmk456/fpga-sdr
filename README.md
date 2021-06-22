# FPGA SDR Code

Individual modules have more detailed readme files, but in summary, this project allows a AT86RF215 transceiver to be controlled over Ethernet and send/receive IQ data from GNU Radio.

## Status

| Module | Status | Testbench | Test Results |
| --- | --- | --- | --- |
| Serializer | Functional | Functional | Passing |
| Deserializer | In progress | In progress | N/A |
| Packetizer | In progress | In progress | N/A |
| Depacketizer | Not started | Not started | N/A |
| SimpleMac | In progress | In progress | N/A |
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

Sends and receives packets over ethernet with Avalon-ST bus. Stores data in a 4096 entry deep FIFO, enough to store 2 packets.

FIFO memory format (10 bits wide): {tx_eop, tx_sop, tx_data[7:0]}

#### CRC32

This module compute the CRC to be inserted at the end of the ethernet frame. The module is based on a parametrizable module from [Alex Forencich](https://github.com/alexforencich/verilog-ethernet). A simple testbench generates some random data and compares the resulting CRC to one generated with a known good library.

### DataController
