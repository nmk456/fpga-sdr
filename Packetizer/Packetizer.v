`timescale 1ns / 1ns

module Packetizer (
    // Clock and reset, must be same as Deserializer
    input clk,
    input reset_n,

    // Input from Deserializer
    output reg rd_en = 0,
    input[31:0] rd_data,
    input rd_dr,

    // Output to MAC
    output tx_clk,
    output reg[31:0] tx_data = 0,
    output reg tx_eop = 0,
    output reg tx_err = 0,
    output reg[1:0] tx_mod = 0,
    input tx_rdy,
    output reg tx_sop = 0,
    output reg tx_wren = 0,

    // Misc MAC signals
    output tx_crc_fwd,
    input tx_a_full,
    input tx_a_empty
);

    parameter source_mac = {8'h02, 8'h12, 8'h34, 8'h56, 8'h67, 8'h90};
    parameter dest_mac = {8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0}; // Change this

    parameter source_ip = {8'd192, 8'd168, 8'd50, 8'd50};
    parameter dest_ip = {8'd0, 8'd0, 8'd0, 8'd0}; // Change this

    parameter source_port = 16'd32179;
    parameter dest_port = 16'd32179;

    // IQ Data

    reg[31:0] IQdata = 0;
    wire[15:0] next_I = {IQdata[29:17], 3'b0};
    wire[15:0] next_Q = {IQdata[13:1], 3'b0};
    // reg IQrequest = 0;
    reg IQready = 0;

    // always @(posedge clk) begin
    //     if (rd_en) begin
    //         IQdata <= rd_data;
    //         rd_en <= 0;
    //         IQready <= 1;
    //     end else if (rd_dr & ~IQready) begin
    //         rd_en <= 1;
    //     end
    // end

    // Ethernet

    reg[9:0] tx_word = 0;
    reg[63:0] packet_counter = 0;

    reg[7:0] wait_counter = 0;

    // TODO: Checksums
    reg[15:0] ip_checksum = 0;
    reg[15:0] udp_checksum = 0;

    wire tx_rdy_int = tx_rdy & IQready;

    assign tx_clk = clk;

    always @(posedge clk) begin
        if (rd_en) begin
            IQdata <= rd_data;
            rd_en <= 0;
            IQready <= 1;
        end else if (rd_dr & ~IQready) begin
            rd_en <= 1;
        end

        if (~reset_n) begin
            tx_mod <= 2'b00;
            tx_word <= 0;

            // Cancel current frame
            tx_err <= 1;
            tx_eop <= 1;
        end else begin
            tx_err <= 0;
            tx_eop <= 0;
            tx_sop <= 0;
            tx_mod <= 0;

            if (wait_counter > 0) begin
                wait_counter <= wait_counter - 1;
                tx_wren <= 0;
            end else if (tx_rdy_int) begin
                tx_wren <= 1;
                tx_word <= tx_word + 1;
                case (tx_word)
                    10'd0: begin
                        tx_sop <= 1;
                        tx_data <= dest_mac[47:16];
                    end
                    10'd1: tx_data <= {dest_mac[15:0], source_mac[47:32]};
                    10'd2: tx_data <= source_mac[31:0];
                    10'd3: tx_data <= 32'h08004500; // EtherType, IPv4, IP header length
                    10'd4: tx_data <= {16'h05dc, packet_counter[15:0]}; // 0x05dc is IP length
                    10'd5: tx_data <= 32'h00004011; // No fragments, TTL, Protocol
                    10'd6: tx_data <= {ip_checksum, source_ip[31:16]};
                    10'd7: tx_data <= {source_ip[15:0], dest_ip[31:16]};
                    10'd8: tx_data <= {dest_ip[15:0], source_port};
                    10'd9: tx_data <= {dest_port, 16'h05c8}; // 0x05c8 is UDP length
                    10'd10: begin
                        tx_mod <= 2'b10; // Only use top 2 bytes
                        tx_data <= {udp_checksum, 16'h0000};
                    end
                    10'd11: tx_data <= {packet_counter[7:0], packet_counter[15:8], packet_counter[23:16], packet_counter[31:24]};
                    10'd12: tx_data <= {packet_counter[39:32], packet_counter[47:40], packet_counter[55:48], packet_counter[63:56]};
                    default: begin
                        tx_data <= {next_I[7:0], next_I[15:8], next_Q[7:0], next_Q[15:8]};
                        IQready <= 0;
                    end
                    10'd379: begin
                        tx_data <= {next_I[7:0], next_I[15:8], next_Q[7:0], next_Q[15:8]};
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
