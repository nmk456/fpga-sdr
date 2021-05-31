# LVDS Receiver

* Mainly for testing, may be used for SDR later

## Payload Format

Only 8 bits for now, probably will eventually be expanded to 32 bits for AT86RF215

Sync pattern, then data bits

| Bit | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|-|-|-|-|-|-|-|-|-|-|-|
| Value | 1 | 0 | D7 | D6 | D5 | D4 | D3 | D2 | D1 | D0 |

## FIFO

8 bit wide FIFO stores incoming data to keep LVDS and FPGA clock domains separate

LVDS Side
* input wr_clk
* input[7:0] wr_data
* input wr_dr
* output wr_af (almost full)

FPGA Side
* input rd_clk
* input rd_en
* output[7:0] rd_data
* output rd_ae (almost empty)

Total capacity: 256 x 8
AF: 224
AE: 32

7/8 and 1/8 full

## Ports

Clock can be at any frequency greater than data rate/deserialization factor

* input clk
* input reset_n

Data outputs

* input rd_en
* output[7:0] rd_data
* output rd_dr (data ready is inverse of almost empty)

LVDS input

* input rxclk
* input rx

## States

* STATE_INIT - initializes all values and FIFO
* STATE_WAIT - wait for series of 0s
* STATE_RUN - capture data and store in FIFO
