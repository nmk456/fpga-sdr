# Test Data

Processes some test data taken from GNU Radio for analysis and use in Verilog simulations

Sample rate = 1000 Hz
Test duration = 15 seconds/15000 samples

In wav files, channel 0 is real (I) component and channel 1 is imaginary (Q)

## Waveform

Frequency = 20 Hz
Amplitude = 1
Wave = sine
Phase offset = 0

# Packet Structure

* uint64 - packet number
* until size == 1472 bytes
    * float I
    * float Q

Replace float with short for 16-bit integer data

Data is little endian, LSB is stored first
