import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ClockCycles, Event
from cocotb.binary import BinaryValue
from cocotb_bus.drivers.avalon import AvalonSTPkts
from cocotbext.eth import MiiSink

import random
import numpy as np
import zlib

from scapy.all import Ether, IP, UDP


def randbytes(n):
    for _ in range(n):
        yield random.getrandbits(8)


async def timeout_wait(dut, event: Event):
    TIMEOUT_LEN = 5000

    timer = TIMEOUT_LEN

    while True:
        await RisingEdge(dut.eth_txclk)

        timer -= 1

        if event.is_set():
            timer = TIMEOUT_LEN

        assert timer > 0, "Timeout"


@cocotb.test()
async def sequential_data_test(dut):
    PACKETS = 16

    dut._log.info("Running test")

    cocotb.fork(Clock(dut.clk, 16, units="ns").start())
    cocotb.fork(Clock(dut.eth_txclk, 40, units="ns").start())

    mii_sink = MiiSink(dut.eth_txd, None, dut.eth_txen, dut.eth_txclk)

    timeout = Event()
    cocotb.fork(timeout_wait(dut, timeout))

    dut.rst <= 1

    await RisingEdge(dut.eth_txclk)
    await RisingEdge(dut.eth_txclk)
    await RisingEdge(dut.eth_txclk)
    await RisingEdge(dut.eth_txclk)
    await RisingEdge(dut.eth_txclk)

    dut.rst <= 0

    for i in range(PACKETS):
        dut._log.info(f"Receiving packet {i}")
        data = await mii_sink.recv()

        timeout.set()
        await RisingEdge(dut.eth_txclk)
        timeout.clear()

        assert data.check_fcs(), f"{data.get_fcs().hex()}"
        assert data.error is None
        assert len(data.get_payload()
                   ) == 1514, f"Payload length is {len(data.get_payload())}"

        pkt = Ether(data.get_payload())

        assert pkt[Ether].src == "02:12:34:56:78:90"
        assert pkt[Ether].type == 0x800, f"Ether type is {pkt[Ether].type}"
        assert pkt[IP].src == "10.0.0.2"
        assert pkt[IP].proto == 0x11
        assert pkt[UDP].sport == 32179
        assert pkt[UDP].len == 1480
        assert bytes(pkt[UDP].payload)[8:] == bytearray(
            [0x63, 0x8c, 0x6c, 0x43]*366), f"{len(pkt[UDP].payload[8:])}"
