# Ethernet Notes

Random notes on Ethernet and how it's used in this project

## Deca Strap Options

* PHY address - 0x01
    * COL, RXD[3:0] set to internal pullup/down - 0b00001
* Auto-negotiation - 10Base-T half/full duplex, 100Base-TX half/full duplex
    * LED_LINK (AN_EN) - external pullup - 1
    * LED_SPEED (AN1) - external pullup - 1
    * LED_ACT (AN0) - external pullup - 1
* Clock output - clock output disabled
    * CLK_OUT_EN - external pulldown - 0
* Fiber enable - disabled
    * RX_ER (FX_EN_Z) - internal pullup - 1
* LED configuration - default
* MII mode select - default, MII

## MII Interface

* Data on TXD[3:0] is transmitted when TXEN is high
* Least significant nibble is transmitted first for a given byte
    * Ex: 0x1c transmitted as 0xc first and 0x1 second
* Need to transmit preamble and SOF signals first

## Intel Ethernet IP

* On 32 bit data bus, highest byte is transmitted first

Store and forward mode is not available on small mac config

### Register Initialization

**Register initialization values taken from user guide**

Set MDIO address - Writing to 0x80-0x9f will be same as writing to MDIO registers on PHY

Disable TX and RX in command config register

Read command config to ensure TX and RX are disabled

MAC address config

MAC functions
* Misc Command_config options
* Software reset

Enable TX/RX

## Overview

Ethernet Frame

* Destination MAC address
* Source MAC address
* Length or type
* **Payload**
* CRC

IP Frame

* Verison - 4 for IPv4
* IHL - Header length in 32 bit words, minimum of 5
* DSCP - 0 standard
* ECN - 0 standard
* Total length - size of header and data
* Identification - Arbitrary unique value, needs to increment by 1 each packet
* Flags - 000 standard
* Fragment offset - 0 standard
* TTL - Number of hops to get to dest
* Protocol - 0x11 for UDP
* Header checksum
    * To calculate, add up all other 16 bit words in IP header, take carry and add it back into sum, then invert the sum
    * Sum of entire header plus checksum (with carry bits added back in) should be zero
* Source IP address
* Dest IP address

UDP Frame
* Source port
* Dest port
* Length of header+data
* Checksum - optional, 0x0000 if unused

* Data

## Byte Structure

* 0x0000 - Dest MAC MSB
* 0x0001 - Dest MAC x4
* 0x0005 - Dest MAC LSB
* 0x0006 - Source MAC MSB
* 0x0007 - Source MAC x4
* 0x000b - Source MAC LSB
* 0x000c - EtherType MSB - 0x08
* 0x000d - EtherType LSB - 0x00
* 0x000e - IPv4 Version/IHL - 0x45
* 0x000f - DSCP/ECN - 0x00
* 0x0010 - Length MSB - 0x05
* 0x0011 - Length LSB - 0xdc
* 0x0012 - ID MSB
* 0x0013 - ID LSB
* 0x0014 - Flags/Fragment offset MSB - 0x00
* 0x0015 - Fragment offset LSB - 0x00
* 0x0016 - TTL - 0x40
* 0x0017 - Protocol - 0x11
* 0x0018 - IP Checksum MSB
* 0x0019 - IP Checksum LSB
* 0x001a - Source IP MSB
* 0x001b - Source IP x2
* 0x001d - Source IP LSB
* 0x001e - Dest IP MSB
* 0x001f - Dest IP x2
* 0x0021 - Dest IP LSB
* 0x0022 - Source UDP port MSB
* 0x0023 - Source UDP port LSB
* 0x0024 - Dest UDP port MSB
* 0x0025 - Dest UDP port LSB
* 0x0026 - Length MSB - 0x05
* 0x0027 - Length LSB - 0xc8
* 0x0028 - UDP Checksum MSB
* 0x0029 - UDP Checksum LSB
* 0x002a - SDR packet number LSB
* 0x002b - SDR packet number x6
* 0x0031 - SDR packet number MSB
* 0x0032 - I0 LSB
* 0x0033 - I0 MSB
* 0x0034 - Q0 LSB
* 0x0035 - Q0 MSB
* 0x0036 - I1 LSB
* 0x0037 - I1 MSB
* 0x0038 - Q1 LSB
* 0x0039 - Q1 MSB

...

* 0x05e6 - I365 LSB
* 0x05e7 - I365 MSB
* 0x05e8 - Q365 LSB
* 0x05e9 - Q365 MSB
* 0x05ea - CRC MSB
* 0x05eb - CRC x2
* 0x05ed - CRC LSB

# Sources

https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/ug/ug_ethernet.pdf

http://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2001_w/interfacing/ethernet_mii/eth_mii.html

https://en.wikipedia.org/wiki/Ethernet_frame

https://en.wikipedia.org/wiki/IPv4#Packet_structure

https://en.wikipedia.org/wiki/User_Datagram_Protocol#UDP_datagram_structure
