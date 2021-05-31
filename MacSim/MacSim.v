`timescale 1ns / 1ns

module MacSim (
    input ff_tx_clk,
    input[31:0] ff_tx_data,
    input ff_tx_eop,
    input ff_tx_err,
    input[1:0] ff_tx_mod,
    output reg ff_tx_rdy = 1,
    input ff_tx_sop,
    input ff_tx_wren
);

    reg[7:0] bytes[2047:0];
    reg curr_packet = 0;
    reg[10:0] addr = 0;

    wire[7:0] data_0 = ff_tx_data[31:24];
    wire[7:0] data_1 = ff_tx_data[23:16];
    wire[7:0] data_2 = ff_tx_data[15:8];
    wire[7:0] data_3 = ff_tx_data[7:0];

    always @(*) begin
        if (ff_tx_sop) begin
            curr_packet = 1;
        end else begin
            curr_packet = curr_packet;
        end
    end

    always @(posedge ff_tx_clk) begin
        if (curr_packet && ff_tx_wren) begin
            case (ff_tx_mod)
                2'b00: begin
                    bytes[addr] <= data_0;
                    bytes[addr + 1] <= data_1;
                    bytes[addr + 2] <= data_2;
                    bytes[addr + 3] <= data_3;

                    addr <= addr + 4;
                end
                2'b01: begin
                    bytes[addr] <= data_0;
                    bytes[addr + 1] <= data_1;
                    bytes[addr + 2] <= data_2;

                    addr <= addr + 3;
                end
                2'b10: begin
                    bytes[addr] <= data_0;
                    bytes[addr + 1] <= data_1;

                    addr <= addr + 2;
                end
                2'b11: begin
                    bytes[addr] <= data_0;

                    addr <= addr + 1;
                end
            endcase
        end
    end

    integer i;

    initial begin
        for (i=0; i<2048; i=i+1) begin
            bytes[i] <= 0;
        end

        repeat(20) @(posedge ff_tx_clk);

        ff_tx_rdy <= 0;

        repeat(20) @(posedge ff_tx_clk);

        ff_tx_rdy <= 1;

        @(posedge ff_tx_eop);
        @(posedge ff_tx_clk);

        $writememh("Packet_hex.txt", bytes, 0, 2047);
        // $writememb("Packet_bin.txt", bytes, 0, 2047);
    end

endmodule
