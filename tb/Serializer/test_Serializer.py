import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Timer

import random
import numpy as np

@cocotb.test()
async def trace_test(dut):
    dut._log.info("Running test")

    cocotb.fork(Clock(dut.clk, 20, units="ns").start())

    await Timer(10000, units="ns")

    dut._log.info("Done test")
