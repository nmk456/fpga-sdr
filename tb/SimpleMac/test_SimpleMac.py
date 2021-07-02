import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue
from cocotb_bus.drivers.avalon import AvalonSTPkts
from cocotbext.eth import MiiSink, MiiSource, GmiiFrame

import random
import numpy as np
import zlib
import struct

def randbytes(n):
    for _ in range(n):
        yield random.getrandbits(8)

async def send_avalonst(dut, data):
    # Set to default values
    dut.tx_data <= 0
    dut.tx_sop <= 0
    dut.tx_eop <= 0
    dut.tx_err <= 0
    dut.tx_wren <= 0

    # Wait a bit
    await RisingEdge(dut.tx_clk)
    
    # Send data
    dut.tx_wren <= 1

    i = 0

    while True:
        dut.tx_data <= data[i]

        dut.tx_eop <= (1 if (i == len(data) - 1) else 0)

        dut.tx_sop <= (1 if (i == 0) else 0)

        await RisingEdge(dut.tx_clk)

        if int(dut.tx_rdy) == 1:
            i = i + 1

        if i == len(data):
            break

    dut.tx_wren <= 0

@cocotb.test()
async def sequential_data_test(dut):
    PACKETS = 16
    # PACKETS = 1
    # PACKET_LEN = 1518
    PACKET_LEN = 64

    dut._log.info("Running test")

    cocotb.fork(Clock(dut.tx_clk, 20, units="ns").start())
    cocotb.fork(Clock(dut.eth_txclk, 40, units="ns").start())
    cocotb.fork(Clock(dut.eth_rxclk, 40, units="ns").start())

    mii_sink = MiiSink(dut.eth_txd, None, dut.eth_txen, dut.eth_txclk)
    mii_source = MiiSource(dut.eth_rxd, dut.eth_rxer, dut.eth_rxdv, dut.eth_rxclk)

    dut.rst <= 1

    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)

    dut.rst <= 0

    for i in range(PACKETS):
        test_data = list(randbytes(PACKET_LEN))
        test_crc = struct.pack('<L', zlib.crc32(bytearray(test_data))).hex()

        if len(test_crc) == 7:
            test_crc = "0" + test_crc

        cocotb.fork(send_avalonst(dut, test_data))

        dut._log.info(f"Sending packet {i}")

        mii_source.send_nowait(GmiiFrame.from_payload(test_data))

        result_data = await mii_sink.recv()
        result_payload = result_data.get_payload()

        # CRC assertions currently don't work if the first byte is 0x00, just rerun in that case to get new random data
        assert bytearray(test_data) == result_payload, f"{test_data} does not equal {result_payload}"
        assert result_data.check_fcs(), f"{result_data.get_fcs().hex()}, {test_crc} do not match"

    dut._log.info("Done test")
