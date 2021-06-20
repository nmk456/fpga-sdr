import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue

import random
import numpy as np
import zlib

def randbytes(n):
    for _ in range(n):
        yield random.getrandbits(8)

async def do_crc(dut, data):
    dut.rst <= 1
    dut.data_in <= 0
    dut.crc_en <= 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rst <= 0

    await RisingEdge(dut.clk)
    
    dut.crc_en <= 1

    for b in data:
        dut.data_in <= b
        await RisingEdge(dut.clk)

    dut.crc_en <= 0

    await RisingEdge(dut.clk)

    result = hex(dut.crc_out.value)[2:]

    dut._log.info(f"Result CRC32: {result}")

    return result

async def test(dut, len):
    test_data = bytearray(randbytes(len))
    crc_ref = hex(zlib.crc32(test_data))[2:]

    dut._log.info(f"Test data: {test_data.hex()}")
    dut._log.info(f"Reference CRC32: {crc_ref}")

    crc_res = await do_crc(dut, test_data)

    assert crc_res == crc_ref

@cocotb.test()
async def rand_test(dut):
    TEST_LEN = 2000

    dut._log.info("Running test")

    cocotb.fork(Clock(dut.clk, 20, units="ns").start())

    assert hex(zlib.crc32(b'123456789')) == "0xcbf43926", "zlib is not returning the correct CRC, test results will not be accurate"

    for l in [1, 5, 10, 50, 100, 500, 1000, 5000]:
        await test(dut, l)
