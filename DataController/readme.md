# Packetizer

Convert IQ data from SDR into ethernet packets to transmit

Upstream component must be able to buffer samples for a bit, packetizer container no buffer or FIFO

## Input format

I and Q interfaces, each a Avalon-ST bus with 16 bit data bus

## Output format

Standard UDP packet
* Source and dest MAC, IP addresses hard coded (will be run time configurable later)
* 1472 data bytes, 32 bit/4 bytes per sample, 368 samples