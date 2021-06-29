import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue
from cocotb_bus.drivers.avalon import AvalonSTPkts

import random
import numpy as np
import zlib

from scapy.all import Ether, IP, UDP

def randbytes(n):
    for _ in range(n):
        yield random.getrandbits(8)

@cocotb.test()
async def sequential_data_test(dut):
    dut._log.info("Running test")

    cocotb.fork(Clock(dut.clk, 20, units="ns").start())

    dut.rst <= 1

    dut.rd_dr <= 1
    dut.rd_data <= 0x8c63436c

    dut.tx_rdy <= 1
    dut.tx_a_full <= 0
    dut.tx_a_empty <= 0

    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)

    dut.rst <= 0

    while int(dut.tx_sop) == 0:
        await RisingEdge(dut.tx_clk)
    
    data = []

    while int(dut.tx_eop) == 0:
        if int(dut.tx_wren):
            data.append(int(dut.tx_data))

        await RisingEdge(dut.tx_clk)
    
    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)

    data = bytearray(data)
    pkt = Ether(data)
    # pkt.show()

    assert pkt[Ether].src == "02:12:34:56:78:90"
    assert pkt[Ether].type == 0x800, f"Ether type is {pkt[Ether].type}"
    assert pkt[IP].src == "10.0.0.2"
    assert pkt[IP].proto == 0x11
    assert pkt[UDP].sport == 32179
    assert pkt[UDP].len == 1480

    dut._log.info("Done test")
