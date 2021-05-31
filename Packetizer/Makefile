CC = iverilog
FLAGS = -Wall -Winfloop
NAME = Packetizer
DEPS = ../MacSim/MacSim.v

sim: $(DEPS) $(NAME).v $(NAME)_tb.v
	$(CC) $(FLAGS) -o $(NAME) $(DEPS) $(NAME).v $(NAME)_tb.v
	vvp $(NAME)
	~/fpga/gtkwave/bin/gtkwave.exe $(NAME)_tb.vcd $(NAME)_tb.gtkw
