import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer, Event
# from cocotb.binary import BinaryValue
from cocotbext import eth, axi

from scapy.all import Ether, IP, UDP

import random
# import numpy as np
# import zlib
import itertools


AXI_CLOCK_PERIOD_NS = 20
PACKETS = 16
TIMEOUT_LEN = 20000


def randbytes(n, bits=8):
    for _ in range(n):
        yield random.getrandbits(bits)


def randIQ(n, bits=13):
    """
    Returns list contains 32 bit ints in the same format as the AT86RF215

    n is number of samples, each sample contains I and Q data
    """
    for _ in range(n):
        iq = list(randbytes(2, bits))
        yield (0b10 << 30) | (iq[0] << 17) | (0b01 << 14) | (iq[1] << 1), iq


def twos_comp(val, bits):  # From https://stackoverflow.com/a/9147327
    if (val & (1 << (bits - 1))) != 0:
        val = val - (1 << bits)
    return val


class TB(object):
    def __init__(self, dut, axi_period, delays=0):
        self.dut = dut
        self.log = dut._log
        self.timeout = Event()

        cocotb.fork(self.timeout_wait(self.timeout))

        cocotb.fork(Clock(self.dut.clk, axi_period, units="ns").start())
        self.axi_out = axi.AxiStreamSink(
            axi.AxiStreamBus.from_prefix(dut, "tx"), dut.clk, dut.rst)
        self.axi_in = axi.AxiStreamSource(
            axi.AxiStreamBus.from_prefix(dut, "lvds"), dut.clk, dut.rst)

        if delays == 1:
            self.axi_in.set_pause_generator(itertools.cycle([0, 1, 1, 1, 1, 1, 1, 1]))
        elif delays == 2:
            self.axi_out.set_pause_generator(itertools.cycle([0, 1, 1, 1, 1, 1, 1, 1]))

    async def axi_recv(self) -> axi.AxiStreamFrame:
        result = await self.axi_out.recv()
        return result

    def lvds_send(self, data):
        self.axi_in.send_nowait(axi.AxiStreamFrame(tdata=data))

    async def cycle_reset(self, wait_len=3):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        self.dut.rst <= 1

        for i in range(wait_len):
            await RisingEdge(self.dut.clk)

        self.dut.rst <= 0
        # await RisingEdge(self.dut.clk)
        # await RisingEdge(self.dut.clk)
        # await RisingEdge(self.dut.clk)

    async def timeout_wait(self, event: Event):
        timer = TIMEOUT_LEN

        while True:
            await RisingEdge(self.dut.clk)

            timer -= 1

            if event.is_set():
                timer = TIMEOUT_LEN
                event.clear()

            assert timer > 0, "Timeout"


async def sequential_data_test(dut, delays):
    random.seed("D$3EFjTy4Wmpop#u") # For repeatability
    tb = TB(dut, AXI_CLOCK_PERIOD_NS, delays)
    tb.log.info("Running test")

    dut.tx_a_full <= 0
    dut.tx_a_empty <= 0

    await tb.cycle_reset()

    for i in range(PACKETS):
        tb.timeout.set()
        tb.log.info(f"Sending packet {i}")

        formatted_data = []
        raw_data = []
        for x in randIQ(366):
            formatted_data.append(x[0])
            raw_data.append(x[1])

        tb.lvds_send(formatted_data)

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

        iq_data = bytes(pkt[UDP].payload)[8:]

        for j in range(366):
            sample = iq_data[j*4:(j+1)*4]
            i_raw = int(sample[0] | sample[1] << 8)
            q_raw = int(sample[2] | sample[3] << 8)
            i_data = twos_comp(i_raw, 16)
            q_data = twos_comp(q_raw, 16)

            try:
                assert i_data == twos_comp(raw_data[j][0], 13), f"Packet {i}, sample {j}"
                assert q_data == twos_comp(raw_data[j][1], 13), f"Packet {i}, sample {j}"
            except AssertionError as e:
                raise e

    dut._log.info("Done test")

@cocotb.test()
async def no_bottleneck_test(dut):
    await sequential_data_test(dut, 0)

@cocotb.test()
async def input_bottleneck_test(dut):
    await sequential_data_test(dut, 1)

# @cocotb.test() # Descoped output bottleneck functionality for now
async def output_bottleneck_test(dut):
    await sequential_data_test(dut, 2)
