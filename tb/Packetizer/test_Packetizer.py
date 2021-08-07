import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue
from cocotbext import eth, axi

from scapy.layers.l2 import Ether
from scapy.layers.inet import UDP, IP

import random
import numpy as np
import zlib

AXI_CLOCK_PERIOD_NS = 20


class TB(object):
    def __init__(self, dut, axi_period):
        self.dut = dut
        self.log = dut._log

        cocotb.fork(Clock(self.dut.clk, axi_period, units="ns").start())
        self.axi = axi.AxiStreamSink(
            axi.AxiStreamBus.from_prefix(dut, "tx"), dut.clk, dut.rst)

    async def axi_recv(self) -> axi.AxiStreamFrame:
        result = await self.axi.recv()
        return result

    async def cycle_reset(self, wait_len=3):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1

        for i in range(wait_len):
            await RisingEdge(self.dut.clk)

        self.dut.rst <= 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


@cocotb.test()
async def sequential_data_test(dut):
    tb = TB(dut, AXI_CLOCK_PERIOD_NS)
    tb.log.info("Running test")

    dut.lvds_tdata <= 0x8c63436c
    dut.lvds_tvalid <= 1

    dut.tx_a_full <= 0
    dut.tx_a_empty <= 0

    tb.axi.pause = True
    await tb.cycle_reset()
    tb.axi.pause = False

    for i in range(4):
        axi_pkt = await tb.axi_recv()
        data = axi_pkt.tdata
        pkt = Ether(data)

        assert pkt[Ether].src == "02:12:34:56:78:90", f"{pkt[Ether].src}"
        assert pkt[Ether].type == 0x800, f"{pkt[Ether].type}"
        assert pkt[IP].src == "10.0.0.2", f"{pkt[Ether].type}"
        assert pkt[IP].proto == 0x11, f"{pkt[Ether].type}"
        assert pkt[UDP].sport == 32179, f"{pkt[Ether].type}"
        assert pkt[UDP].len == 1480, f"{pkt[Ether].type}"
        assert len(data) == 1514

    dut._log.info("Done test")
