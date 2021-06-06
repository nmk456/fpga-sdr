# FPGA SDR Code

Individual modules have more detailed readme files, but in summary, this project allows a AT86RF215 transceiver to be controlled over Ethernet and send/receive IQ data from GNU Radio.

## Status

| Module | Status | Testbench | Test Results |
| --- | --- | --- | --- |
| Serializer | In progress | In progress | N/A |
| Deserializer | In progress | In progress | N/A |
| Packetizer | In progress | In progress | N/A |
| Depacketizer | Not started | Not started | N/A |
| SimpleMac | In progress | In progress | N/A |
| DataController | In progress | In progress | N/A |

## Modules

### Serializer

Sends data over LVDS using packet structure defined in AT86RF215 datasheet page 24.

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
* STATE_I_SYNC - First sync word (0b10)
* STATE_I_DATA - I data
* STATE_Q_SYNC - Second sync word (0b01)
* STATE_Q_DATA - Q data

### Deserializer

### Packetizer

### Depacketizer

### SimpleMac

### DataController
