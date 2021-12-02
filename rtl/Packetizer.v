`timescale 1ns / 1ns

module Packetizer (
    // Clock and reset, must be same as Deserializer
    input clk,
    input rst,

    // Input from Deserializer
    input[31:0] lvds_tdata,
    output reg lvds_tready = 0,
    input lvds_tvalid,

    // Output to MAC
    output reg[7:0] tx_tdata = 0,
    output reg tx_tlast = 0,
    output reg tx_tuser = 0,
    input tx_tready,
    output reg tx_tvalid = 0,

    // Misc MAC signals
    input tx_a_full,
    input tx_a_empty
);

    parameter SOURCE_MAC = {8'h02, 8'h12, 8'h34, 8'h56, 8'h78, 8'h90};
    parameter DEST_MAC = {8'hab, 8'hcd, 8'hef, 8'hfe, 8'hdc, 8'hba}; // Change this

    parameter SOURCE_IP = {8'd10, 8'd0, 8'd0, 8'd2};
    parameter DEST_IP = {8'd10, 8'd0, 8'd0, 8'd1}; // Change this

    parameter SOURCE_PORT = 16'd32179;
    parameter DEST_PORT = 16'd32179;

    localparam NUM_SAMPLES = 366; // Number of IQ samples
    localparam IQ_LEN = NUM_SAMPLES * 4; // Length of IQ data in bytes
    localparam DATA_LEN = IQ_LEN + 8; // Length of UDP payload in bytes
    localparam UDP_LEN = DATA_LEN + 8; // Length of UDP packet in bytes
    localparam IP_LEN = UDP_LEN + 20; // Length of IP packet in bytes
    localparam PACKET_LEN = IP_LEN + 14; // Length of entire packet in bytes

    // IQ Data

    reg[31:0] iq_buffer = 0, iq_buffer_p1 = 0;
    wire[15:0] next_I = {{3{iq_buffer[29]}}, iq_buffer[29:17]};
    wire[15:0] next_Q = {{3{iq_buffer[13]}}, iq_buffer[13:1]};
    // reg IQready = 0;
    // reg first_run = 0;
    reg new_sample = 0, new_sample_last = 0;
    reg waited = 0;

    // Ethernet

    reg[15:0] tx_word = 0;
    reg[63:0] packet_counter = 0;

    // reg[7:0] wait_counter = 0;

    // TODO: Checksums
    reg[15:0] ip_checksum = 0;
    reg[15:0] udp_checksum = 0;

    always @(*) begin
        /* verilator lint_off CASEINCOMPLETE */
        case (tx_word)
            16'h0000: tx_tdata = DEST_MAC[47:40];
            16'h0001: tx_tdata = DEST_MAC[39:32];
            16'h0002: tx_tdata = DEST_MAC[31:24];       // Destination MAC
            16'h0003: tx_tdata = DEST_MAC[23:16];
            16'h0004: tx_tdata = DEST_MAC[15:8];
            16'h0005: tx_tdata = DEST_MAC[7:0];
            16'h0006: tx_tdata = SOURCE_MAC[47:40];     // Source MAC
            16'h0007: tx_tdata = SOURCE_MAC[39:32];
            16'h0008: tx_tdata = SOURCE_MAC[31:24];
            16'h0009: tx_tdata = SOURCE_MAC[23:16];
            16'h000a: tx_tdata = SOURCE_MAC[15:8];
            16'h000b: tx_tdata = SOURCE_MAC[7:0];
            16'h000c: tx_tdata = 8'h08;                 // Ethertype
            16'h000d: tx_tdata = 8'h00;
            16'h000e: tx_tdata = 8'h45;                 // IPv4
            16'h000f: tx_tdata = 8'h00;                 // DSCP/ECN 
            // 16'h0010: tx_tdata = 8'h05;                 // IP length
            // 16'h0011: tx_tdata = 8'hdc;
            16'h0010: tx_tdata = IP_LEN[15:8];          // IP length
            16'h0011: tx_tdata = IP_LEN[7:0];
            16'h0012: tx_tdata = packet_counter[15:8];  // Packet ID
            16'h0013: tx_tdata = packet_counter[7:0];
            16'h0014: tx_tdata = 8'h00;                 // Fragment offset
            16'h0015: tx_tdata = 8'h00;
            16'h0016: tx_tdata = 8'h40;                 // TTL
            16'h0017: tx_tdata = 8'h11;                 // Protocol: UDP
            16'h0018: tx_tdata = ip_checksum[15:8];     // IP checksum
            16'h0019: tx_tdata = ip_checksum[7:0];
            16'h001a: tx_tdata = SOURCE_IP[31:24];      // Source IP
            16'h001b: tx_tdata = SOURCE_IP[23:16];
            16'h001c: tx_tdata = SOURCE_IP[15:8];
            16'h001d: tx_tdata = SOURCE_IP[7:0];
            16'h001e: tx_tdata = DEST_IP[31:24];        // Destination IP
            16'h001f: tx_tdata = DEST_IP[23:16];
            16'h0020: tx_tdata = DEST_IP[15:8];
            16'h0021: tx_tdata = DEST_IP[7:0];
            16'h0022: tx_tdata = SOURCE_PORT[15:8];     // Source port
            16'h0023: tx_tdata = SOURCE_PORT[7:0];
            16'h0024: tx_tdata = DEST_PORT[15:8];       // DEstination port
            16'h0025: tx_tdata = DEST_PORT[7:0];
            // 16'h0026: tx_tdata = 8'h05;                 // UDP length
            // 16'h0027: tx_tdata = 8'hc8;
            16'h0026: tx_tdata = UDP_LEN[15:8];         // UDP length
            16'h0027: tx_tdata = UDP_LEN[7:0];
            16'h0028: tx_tdata = udp_checksum[15:8];    // UDP checksum
            16'h0029: tx_tdata = udp_checksum[7:0];
            16'h002a: tx_tdata = packet_counter[7:0];   // Packet ID for GNU Radio
            16'h002b: tx_tdata = packet_counter[15:8];
            16'h002c: tx_tdata = packet_counter[23:16];
            16'h002d: tx_tdata = packet_counter[31:24];
            16'h002e: tx_tdata = packet_counter[39:32];
            16'h002f: tx_tdata = packet_counter[47:40];
            16'h0030: tx_tdata = packet_counter[55:48];
            16'h0031: tx_tdata = packet_counter[63:56];
            default: begin                              // IQ data
                case (tx_word[1:0])
                    2'b10: tx_tdata = next_I[7:0];
                    2'b11: tx_tdata = next_I[15:8];
                    2'b00: tx_tdata = next_Q[7:0];
                    2'b01: tx_tdata = next_Q[15:8];
                endcase
            end
        endcase
        /* verilator lint_off CASEINCOMPLETE */
    end

    always @(posedge clk) begin
        if (rst) begin
            tx_word <= 0;
            packet_counter <= 0;
            lvds_tready <= 0;
            tx_tvalid <= 0;
            waited <= 0;

            // Cancel current frame
            // tx_tuser <= 1;
            // tx_tlast <= 1;
        end else begin
//             tx_tvalid <= 1;

//             if (tx_tuser) begin
//                 tx_tuser <= 0;
//                 tx_tlast <= 0;
//             end

//             if (lvds_tready && lvds_tvalid && ((tx_word != 16'h0033) || packet_counter != 64'b0)) begin
//                 lvds_tready <= 0;
//                 iq_buffer <= lvds_tdata;
//                 new_sample <= 1;
//             end

//             if (tx_tready) begin
//                 // Either increment tx_word or set tx_tvalid to low
//                 if (~new_sample && (tx_word[1:0] == 2'b01) &&
//                 (tx_word > 16'h0031) && (tx_word != 16'h05e9))
//                     tx_tvalid <= 0;
//                 else
//                     tx_word <= tx_word + 1;
//             end

//             // if (new_sample) begin
//             //     new_sample <= 0;
//             // end
// //             if (new_sample && (tx_word[1:0] == 2'b01) && (tx_word > 16'h0031) && (tx_word != 16'h05e9)) begin
// //                 new_sample <= 0;
// // iq_buffer <= lvds_tdata;
// //             end

//             case (tx_word)
//                 16'h0001: begin
//                     // Prime iq_buffer at startup
//                     // if (~lvds_tready) begin
//                     //     lvds_tready <= 1;
//                     // end
//                 end
//                 // 16'h0003: iq_buffer <= lvds_tdata;
//                 default: begin
//                     if ((tx_word >= 16'h0031)) begin
//                         // iq_buffer <= lvds_tdata;
//                         // lvds_tready <= 1;
//                         // new_sample <= 0;
//                         if ((tx_word[1:0] == 2'b01) && new_sample && tx_tready) begin
//                             // iq_buffer <= lvds_tdata;
//                             // lvds_tready <= 1;
//                             new_sample <= 0;
//                         end else if ((tx_word[1:0] == 2'b10) && ~new_sample && ~lvds_tready) begin
//                             lvds_tready <= 1;
//                         end
//                     end

//                     if ((tx_word == 16'h05e8) && tx_tready) begin
//                         tx_tlast <= 1;
//                     end

//                 end
//                 16'h05e9: begin // Last
//                     if (tx_tready) begin
//                         // IQready <= 0;
//                         tx_tlast <= 0;
//                         // tx_tvalid <= 0; // Leaving this commented out might cause issues
//                         tx_word <= 0;
//                         packet_counter <= packet_counter + 1;
//                         // wait_counter <= 16;
//                         // first_run <= 0;
//                     end
//                 end
//             endcase

            tx_tvalid <= 1;
            new_sample_last <= new_sample;

            // Either increment tx_word or set tx_tvalid to low
            if (tx_tready && tx_tvalid) begin
                tx_word <= tx_word + 1;

                // Prime buffer on first run
                if ((packet_counter == 64'b0) && (tx_word == 16'h002e)) begin
                    lvds_tready <= 1;
                end
            end

            if (lvds_tready && lvds_tvalid) begin
                iq_buffer_p1 <= lvds_tdata;
                lvds_tready <= 0;
                new_sample <= 1;
            end

            // Finalize packet
            if (tx_word == 16'h05e9) begin
                if (tx_tready) begin
                    tx_tlast <= 0;
                    tx_word <= 0;
                    packet_counter <= packet_counter + 1;
                end
            end else if (tx_word >= 16'h0030) begin
                // Prepare last word
                if (tx_word == 16'h05e8) begin
                    tx_tlast <= 1;
                end

                // Handle sample processing
                case (tx_word[1:0])
                    2'b01: begin
                        if (new_sample) begin
                            iq_buffer <= iq_buffer_p1;
                            new_sample <= 0;

                            if (waited) begin
                                tx_tvalid <= 0;
                                waited <= 0;
                                tx_word <= tx_word + 1;
                            end
                        end else begin
                            tx_tvalid <= 0;
                            if (~new_sample_last) begin
                                if (tx_tready) begin
                                    tx_word <= tx_word;
                                    waited <= 1;
                                end
                            end else begin
                                // tx_word <= tx_word + 1;
                            end
                        end
                    end

                    2'b10: begin
                        if (~new_sample && ~lvds_tready) begin
                            lvds_tready <= 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
