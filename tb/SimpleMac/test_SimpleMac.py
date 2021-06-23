import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue
from cocotb_bus.drivers.avalon import AvalonSTPkts

import random
import numpy as np
import zlib

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

        dut.tx_eop <= 1 if i == len(data) - 1 else 0
        
        dut.tx_sop <= 1 if i == 0 else 0

        await RisingEdge(dut.tx_clk)

        if int(dut.tx_rdy) == 1:
            i = i + 1

        if i == len(data):
            break

    dut.tx_wren <= 0

async def recv_mii(dut):
    data = []
    preamble = True

    while int(dut.eth_txen) == 0:
        await RisingEdge(dut.eth_txclk)

    while True:
        incoming = hex(int(dut.eth_txd))[2:]
        if preamble and incoming == "5":
            pass
        elif preamble and incoming == "d":
            preamble = False
        else:
            data.append(incoming)

        await RisingEdge(dut.eth_txclk)

        if int(dut.eth_txen) == 0:
            break
    
    byte_data = []

    for i in range(0, len(data), 2):
        if data[i+1] == "0":
            byte_data.append(f"{data[i]}")
        else:
            byte_data.append(f"{data[i+1]}{data[i]}")

    return byte_data

@cocotb.test()
async def sequential_data_test(dut):
    dut._log.info("Running test")

    cocotb.fork(Clock(dut.tx_clk, 20, units="ns").start())
    cocotb.fork(Clock(dut.eth_txclk, 40, units="ns").start())

    dut.rst <= 1

    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)

    dut.rst <= 0

    for i in range(16):
        test_data = list(randbytes(1518))
        test_data_hex = [hex(b)[2:] for b in test_data]
        test_crc = hex(zlib.crc32(bytearray(test_data)))[2:]

        if len(test_crc) == 7:
            test_crc = "0" + test_crc

        # dut._log.info(f"Test data CRC {test_crc}")

        # dut._log.info(f"Sending {test_data_hex}")
        cocotb.fork(send_avalonst(dut, test_data))

        result_data_hex = await recv_mii(dut)

        result_crc_hex_reversed = result_data_hex[-4:]
        result_crc_hex = []

        for b in result_crc_hex_reversed:
            b = bin(int(b, 16))[2:]
            b = b[::-1]
            while len(b) < 8:
                b = b + "0"
            b = hex(int(b, 2))[2:]
            if len(b) == 1:
                b = "0" + b
            result_crc_hex.append(b)
        
        result_crc_hex = "".join(result_crc_hex)

        # dut._log.info(f"Received {result_data_hex}")
        # dut._log.info(f"Result data CRC {result_crc_hex}")

        assert test_data_hex == result_data_hex[:-4], f"{test_data_hex} does not equal {result_data_hex[:-4]}"
        assert result_crc_hex == test_crc, f"CRCs do not match: {result_crc_hex}, {test_crc}"

    dut._log.info("Done test")