// Created from Quartus Prime Verilog Template

module SimpleMacFifo (
    input [(DATA_WIDTH-1):0] data,
    input [(ADDR_WIDTH-1):0] read_addr, write_addr,
    input we, read_clock, write_clock,
    output reg [(DATA_WIDTH-1):0] q = 0
);

    parameter DATA_WIDTH=10;
    parameter ADDR_WIDTH=12;

    // Declare the RAM variable
    reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
    
    always @(posedge write_clock) begin
        // Write
        if (we)
            ram[write_addr] <= data;
    end
    
    always @(posedge read_clock)begin
        // Read 
        q <= ram[read_addr];
    end

endmodule
