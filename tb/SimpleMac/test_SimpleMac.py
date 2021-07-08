import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue
# from cocotb_bus.drivers.avalon import AvalonSTPkts
# from cocotbext.eth import MiiSink, MiiSource, GmiiFrame
from cocotbext import eth, axi
# from cocotbext.axi import AxiStreamSink, AxiStreamSource, AxiStreamBus

import random
from cocotbext.eth.gmii import GmiiFrame
import numpy as np
import zlib
import struct

PACKETS = 16
# PACKETS = 4
PACKET_LEN = 1518
# PACKET_LEN = 64

AXI_CLOCK_PERIOD_NS = 20
MII_CLOCK_PERIOD_NS = 40


def randbytes(n):
    for _ in range(n):
        yield random.getrandbits(8)


def get_data_crc(n):
    """
    Returns random data n bytes long with CRC of that data

    Ex:
    data, crc = get_data_crc(n)
    data == [94, 140, 89, 175]
    crc == '0d1da9cf'
    """
    data = list(randbytes(n))
    crc = struct.pack('<L', zlib.crc32(bytearray(data))).hex()

    return data, crc


class TB(object):
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

        cocotb.fork(
            Clock(self.dut.tx_clk, AXI_CLOCK_PERIOD_NS, units="ns").start())
        cocotb.fork(
            Clock(self.dut.rx_clk, AXI_CLOCK_PERIOD_NS, units="ns").start())
        cocotb.fork(
            Clock(self.dut.eth_txclk, MII_CLOCK_PERIOD_NS, units="ns").start())
        cocotb.fork(
            Clock(self.dut.eth_rxclk, MII_CLOCK_PERIOD_NS, units="ns").start())

        # Tx_Mii receives data from TX interface
        self.Tx_Mii = eth.MiiSink(
            dut.eth_txd, None, dut.eth_txen, dut.eth_txclk)
        # Rx_Mii sends data to RX interface
        self.Rx_Mii = eth.MiiSource(
            dut.eth_rxd, dut.eth_rxer, dut.eth_rxdv, dut.eth_rxclk)

        # Tx_Axi sends data to TX interface
        self.Tx_Axi = axi.AxiStreamSource(
            axi.AxiStreamBus.from_prefix(dut, "tx"), dut.tx_clk, dut.rst)
        # Rx_Axi receives data from RX interface
        self.Rx_Axi = axi.AxiStreamSink(
            axi.AxiStreamBus.from_prefix(dut, "rx"), dut.rx_clk, dut.rst)

    async def tx_mii_recv(self) -> eth.GmiiFrame:
        result = await self.Tx_Mii.recv()
        return result
    
    def tx_axi_send(self, data, tuser=None):
        if type(data) == axi.AxiStreamFrame:
            self.Tx_Axi.send_nowait(data)
        else:
            self.Tx_Axi.send_nowait(axi.AxiStreamFrame(data, tuser=tuser))

    def rx_mii_send(self, data):
        if type(data) == eth.GmiiFrame:
            self.Rx_Mii.send_nowait(data)
        else:
            self.Rx_Mii.send_nowait(eth.GmiiFrame(data))

    async def rx_axi_recv(self) -> axi.AxiStreamFrame:
        result = await self.Rx_Axi.recv()
        return result

    # Cycles reset signal and waits `wait_len` cycles between asserting and deasserting rst
    async def cycle_reset(self, wait_len=3):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.eth_txclk)
        await RisingEdge(self.dut.eth_txclk)
        self.dut.rst <= 1

        for i in range(wait_len):
            await RisingEdge(self.dut.eth_txclk)

        self.dut.rst <= 0
        await RisingEdge(self.dut.eth_txclk)
        await RisingEdge(self.dut.eth_txclk)


@cocotb.test()
async def tx_test(dut):
    tb = TB(dut)

    tb.log.info("Running TX test")

    await tb.cycle_reset()

    for i in range(PACKETS):
        dut._log.info(f"Sending packet {i}")

        test_data, test_crc = get_data_crc(PACKET_LEN)

        tb.tx_axi_send(test_data)

        result_data = await tb.tx_mii_recv()

        assert bytearray(test_data) == result_data.get_payload(), "Packet payload does not match"
        assert result_data.check_fcs(), "Packet FCS is not valid"

    dut._log.info("Done TX test")

@cocotb.test()
async def rx_test(dut):
    tb = TB(dut)

    tb.log.info("Running RX test")

    await tb.cycle_reset()

    for i in range(PACKETS):
        dut._log.info(f"Sending packet {i}")

        test_data, test_crc = get_data_crc(PACKET_LEN)

        tb.rx_mii_send(GmiiFrame.from_payload(test_data))

        result_data = await tb.rx_axi_recv()

        assert bytearray(test_data) == result_data.tdata, f"{bytearray(test_data).hex()} != {result_data.tdata.hex()}"
