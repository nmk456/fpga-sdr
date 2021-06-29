SIM ?= verilator
TOPLEVEL_LANG ?= verilog

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ns

DUT = PacketizerSimpleMac
VERILOG_SOURCES += $(PWD)/$(DUT).v
TOPLEVEL = $(DUT)
MODULE = test_$(DUT)

EXTRA_ARGS += --trace-fst --trace-structs

VERILOG_SOURCES += $(PWD)/../../rtl/Packetizer.v $(PWD)/../../rtl/SimpleMac.v $(PWD)/../../rtl/lfsr.v $(PWD)/../../rtl/CRC32.v $(PWD)/../../rtl/SimpleMacFifo.v

include $(shell cocotb-config --makefiles)/Makefile.sim

waves: sim
	gtkwave.exe dump.fst $(DUT).gtkw
