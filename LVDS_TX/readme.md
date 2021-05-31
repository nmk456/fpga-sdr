# LVDS Transmitter

* Mainly for testing, may be used for SDR later

## Payload Format

Only 8 bits for now, probably will eventually be expanded to 32 bits for AT86RF215

Sync pattern, then data bits

| Bit | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|-|-|-|-|-|-|-|-|-|-|-|
| Value | 1 | 0 | D7 | D6 | D5 | D4 | D3 | D2 | D1 | D0 |

## Ports

Clock must be at LVDS output frequency, ie 64 MHz for 128 mbps DDR

* input clk
* input reset_n

Data inputs

* input oe
* input[7:0] data

LVDS output

* output txclk
* output tx
