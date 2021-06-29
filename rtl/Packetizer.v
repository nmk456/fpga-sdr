`timescale 1ns / 1ns

module Packetizer (
    // Clock and reset, must be same as Deserializer
    input clk,
    input rst,

    // Input from Deserializer
    output reg rd_en = 0,
    input[31:0] rd_data,
    input rd_dr,

    // Output to MAC
    output tx_clk,
    output reg[7:0] tx_data = 0,
    output reg tx_eop = 0,
    output reg tx_err = 0,
    // output reg[1:0] tx_mod = 0,
    input tx_rdy,
    output reg tx_sop = 0,
    output reg tx_wren = 0,

    // Misc MAC signals
    input tx_a_full,
    input tx_a_empty
);

    parameter SOURCE_MAC = {8'h02, 8'h12, 8'h34, 8'h56, 8'h78, 8'h90};
    parameter DEST_MAC = {8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0}; // Change this

    parameter SOURCE_IP = {8'd10, 8'd0, 8'd0, 8'd2};
    parameter DEST_IP = {8'd10, 8'd0, 8'd0, 8'd1}; // Change this

    parameter SOURCE_PORT = 16'd32179;
    parameter DEST_PORT = 16'd32179;

    // IQ Data

    reg[31:0] IQdata = 0;
    wire[15:0] next_I = IQdata[31:16];
    wire[15:0] next_Q = IQdata[15:0];
    reg IQready = 0;

    // Ethernet

    reg[15:0] tx_word = 0;
    reg[63:0] packet_counter = 0;

    reg[7:0] wait_counter = 0;

    // TODO: Checksums
    reg[15:0] ip_checksum = 0;
    reg[15:0] udp_checksum = 0;

    assign tx_clk = clk;

    always @(posedge clk) begin
        if (rd_en & rd_dr) begin
            IQdata <= rd_data;
            rd_en <= 0;
            IQready <= 1;
        end else if (rd_dr & ~IQready) begin
            rd_en <= 1;
        end

        if (rst) begin
            tx_word <= 0;

            // Cancel current frame
            tx_err <= 1;
            tx_eop <= 1;
        end else begin
            // tx_err <= 0;
            // tx_eop <= 0;
            // tx_sop <= 0;

            if (wait_counter > 0) begin
                if (tx_rdy & tx_eop) begin
                    tx_eop <= 0;
                    tx_wren <= 0;
                end else if (~tx_eop) begin
                    wait_counter <= wait_counter - 1;
                end
                // wait_counter <= wait_counter - 1;
                // if (tx_rdy & tx_wren & tx_eop) begin
                //     tx_wren <= 0;
                // end
                // tx_wren <= 0;
            end else if (tx_rdy & (IQready | tx_word < 16'h0032) & ~tx_a_full) begin
                tx_err <= 0;
                tx_eop <= 0;
                tx_sop <= 0;
                tx_wren <= 1;
                tx_word <= tx_word + 1;
                case (tx_word)
                    16'h0000: begin
                        tx_sop <= 1;
                        tx_data <= DEST_MAC[47:40];
                    end
                    16'h0001: tx_data <= DEST_MAC[39:32];
                    16'h0002: tx_data <= DEST_MAC[31:24];
                    16'h0003: tx_data <= DEST_MAC[23:16];
                    16'h0004: tx_data <= DEST_MAC[15:8];
                    16'h0005: tx_data <= DEST_MAC[7:0];
                    16'h0006: tx_data <= SOURCE_MAC[47:40];
                    16'h0007: tx_data <= SOURCE_MAC[39:32];
                    16'h0008: tx_data <= SOURCE_MAC[31:24];
                    16'h0009: tx_data <= SOURCE_MAC[23:16];
                    16'h000a: tx_data <= SOURCE_MAC[15:8];
                    16'h000b: tx_data <= SOURCE_MAC[7:0];
                    16'h000c: tx_data <= 8'h08;
                    16'h000d: tx_data <= 8'h00;
                    16'h000e: tx_data <= 8'h45;
                    16'h000f: tx_data <= 8'h00;
                    16'h0010: tx_data <= 8'h05;
                    16'h0011: tx_data <= 8'hdc;
                    16'h0012: tx_data <= packet_counter[15:8];
                    16'h0013: tx_data <= packet_counter[7:0];
                    16'h0014: tx_data <= 8'h00;
                    16'h0015: tx_data <= 8'h00;
                    16'h0016: tx_data <= 8'h40;
                    16'h0017: tx_data <= 8'h11;
                    16'h0018: tx_data <= ip_checksum[15:8];
                    16'h0019: tx_data <= ip_checksum[7:0];
                    16'h001a: tx_data <= SOURCE_IP[31:24];
                    16'h001b: tx_data <= SOURCE_IP[23:16];
                    16'h001c: tx_data <= SOURCE_IP[15:8];
                    16'h001d: tx_data <= SOURCE_IP[7:0];
                    16'h001e: tx_data <= DEST_IP[31:24];
                    16'h001f: tx_data <= DEST_IP[23:16];
                    16'h0020: tx_data <= DEST_IP[15:8];
                    16'h0021: tx_data <= DEST_IP[7:0];
                    16'h0022: tx_data <= SOURCE_PORT[15:8];
                    16'h0023: tx_data <= SOURCE_PORT[7:0];
                    16'h0024: tx_data <= DEST_PORT[15:8];
                    16'h0025: tx_data <= DEST_PORT[7:0];
                    16'h0026: tx_data <= 8'h05;
                    16'h0027: tx_data <= 8'hc8;
                    16'h0028: tx_data <= udp_checksum[15:8];
                    16'h0029: tx_data <= udp_checksum[7:0];
                    16'h002a: tx_data <= packet_counter[7:0];
                    16'h002b: tx_data <= packet_counter[15:8];
                    16'h002c: tx_data <= packet_counter[23:16];
                    16'h002d: tx_data <= packet_counter[31:24];
                    16'h002e: tx_data <= packet_counter[39:32];
                    16'h002f: tx_data <= packet_counter[47:40];
                    16'h0030: tx_data <= packet_counter[55:48];
                    16'h0031: tx_data <= packet_counter[63:56];
                    default: begin
                        case (tx_word[1:0])
                            2'b10: tx_data <= next_I[7:0];
                            2'b11: tx_data <= next_I[15:8];
                            2'b00: tx_data <= next_Q[7:0];
                            2'b01: begin
                                tx_data <= next_Q[15:8];
                                IQready <= 0;
                            end
                        endcase
                    end
                    16'h05e9: begin
                        tx_data <= next_Q[15:8];
                        IQready <= 0;
                        tx_eop <= 1;
                        tx_word <= 0;
                        packet_counter <= packet_counter + 1;
                        wait_counter <= 16;
                    end
                endcase
            end else begin
                tx_wren <= 0;
            end
        end
    end

endmodule
