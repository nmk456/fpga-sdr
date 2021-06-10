# Packetizer

Status: Functional

Convert IQ data from SDR into ethernet packets to transmit

Upstream component must be able to buffer samples for a bit, packetizer contains no buffer or FIFO

TODO:
* Calculate checksums

## Input format

I and Q interfaces, each a Avalon-ST bus with 16 bit data bus

## Output format

Standard UDP packet
* Source and dest MAC, IP addresses hard coded (will be run time configurable later)
* 1464 data bytes, 32 bit/4 bytes per sample, 366 samples

## Simulation Data

Data taken from GNU Radio capture, should be several cycles of sine and cosine waves - IQdata is array of 32 bit binary words in same format as LVDS, 2928 total samples, 8 packets

## Data Rates

* Ethernet needs to be fed at 100 Mbps minimum
* Packetizer can feed 1 byte of IQ data per clock at 50 MHz = 400 Mbps
* SDR running at 4 Msps with 2x16 bits per sample (13 bits would need extra logic) = 128 MHz, not including packet overhead
    * Running at 8 bits instead of 16 would fit on 100BASE-T
