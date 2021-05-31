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
    * SDR runs at 4 Msps
    * ~132 Mb/s, sample rate will have to be reduced to fit on 100BASE-TX

## Simulation Data

Data taken from GNU Radio capture, should be several cycles of sine and cosine waves - IQdata is array of 32 bit binary words in same format as LVDS, 2928 total samples, 8 packets
