SIM ?= verilator
TOPLEVEL_LANG ?= verilog

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ns

DUT = CRC32
VERILOG_SOURCES += $(PWD)/../../rtl/$(DUT).v
TOPLEVEL = $(DUT)
MODULE = test_$(DUT)

EXTRA_ARGS += --trace-fst --trace-structs

VERILOG_SOURCES += $(PWD)/../../rtl/lfsr.v

include $(shell cocotb-config --makefiles)/Makefile.sim

waves: sim
	gtkwave.exe dump.fst $(DUT).gtkw
