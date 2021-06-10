import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer
from cocotb.binary import BinaryValue

import random
import numpy as np


# Generates random binary data string with length l
def rand_bin(l):
    return "".join([str(random.randint(0, 1)) for i in range(l)])


# Sends data with random intervals of waiting before asserting data_valid
async def send_data(dut, idata, qdata):
    samples = len(idata)

    dut._log.debug(f"Sending I, Q: {idata[0]}, {qdata[0]}")

    dut.idata_in.value = BinaryValue(idata[0])
    dut.qdata_in.value = BinaryValue(qdata[0])
    dut.data_valid.value = 1

    await RisingEdge(dut.clk)

    while True:
        if dut.data_ready.value == dut.data_valid.value:
            break
        else:
            await RisingEdge(dut.clk)

    for i in range(1, samples):
        dut._log.debug(f"Sending I, Q: {idata[i]}, {qdata[i]}")
        dut.idata_in.value = BinaryValue(idata[i])
        dut.qdata_in.value = BinaryValue(qdata[i])

        await RisingEdge(dut.clk)

        while True:
            if dut.data_ready.value == dut.data_valid.value:
                break
            else:
                await RisingEdge(dut.clk)


# Parses data send from tx pin
async def receive_data(dut, num):
    await Edge(dut.tx)  # Wait for start of transmission

    data = []

    for i in range(num):
        word = ""
        for i in range(32):
            word += dut.tx.value.binstr
            await Edge(dut.txclk)

        data.append(word)
        dut._log.debug(f"Received: {word}")

    return data


@cocotb.test()
async def trace_test(dut):
    NUM_SAMPLES = 10

    dut._log.info("Running test")

    dut.rst <= 0

    cocotb.fork(Clock(dut.clk, 20, units="ns").start())

    idata = [rand_bin(14) for i in range(NUM_SAMPLES)]
    qdata = [rand_bin(14) for i in range(NUM_SAMPLES)]

    cocotb.fork(send_data(dut, idata, qdata))

    result = await receive_data(dut, NUM_SAMPLES)

    for i in range(NUM_SAMPLES):
        iref = idata[i]
        qref = qdata[i]

        ires = result[i][2:16]
        qres = result[i][18:]

        dut._log.info(f"Checking sample {i}, {iref}, {qref}, {result[i]}")

        assert result[i][0:2] == "10", f"{result[i][0:2]} does not match sync word 10"
        assert result[i][16:18] == "01", f"{result[i][16:18]} does not match sync word 01"

        assert iref == ires, f"Received I data {ires} does not match sent data {iref}"
        assert qref == qres, f"Received Q data {qres} does not match sent data {qref}"

    dut._log.info("Done test")
