module SimpleMac (
    input rst, // active high and registered to tx_clk

    // MII interface
    input eth_txclk,
    output reg eth_txen,
    output reg[3:0] eth_txd,
    input eth_rxclk,
    input eth_rxdv,
    input eth_rxer,
    input[3:0] eth_rxd,
    input eth_col,
    input eth_crs,
    output eth_pcf,
    output eth_rstn,

    // Transmit interface
    input tx_clk,
    input[7:0] tx_data,
    input tx_sop,
    input tx_eop,
    input tx_err,
    output tx_rdy,
    input tx_wren,

    output tx_a_full,
    output tx_a_empty,

    // Receive interface - TODO
    input rx_clk,
    output[7:0] rx_data,
    output rx_sop,
    output rx_eop,
    output rx_err,
    input rx_rdy,
    output rx_wren,

    output rx_a_full,
    output rx_a_empty,
    output rx_empty
);

    parameter ALMOST_FULL_THRESHOLD = 64;
    parameter ALMOST_EMPTY_THRESHOLD = 64;
    parameter WAIT_LEN = 24; // 24 nibbles is 96 bits, standard minimum interpacket gap

    // 2048 byte deep FIFO
    // FIFO stores 8 data bits, sop, eop, and err signals
    // single entry = {eop, sop, data}, 10 bits wide

    /* ========== TX ========== */

    reg[11:0] tx_rd_ptr = 0;
    reg[11:0] tx_wr_ptr = 0;
    wire[11:0] tx_fifo_count = tx_wr_ptr - tx_rd_ptr;

    reg tx_wr_en;
    reg[9:0] tx_wr_data;
    wire[9:0] tx_rd_fifo_data;

    SimpleMacFifo tx_fifo (
        // Write
        .data(tx_wr_data),
        .write_addr(tx_wr_ptr),
        .we(tx_wr_en),
        .write_clock(tx_clk),

        // Read
        .q(tx_rd_fifo_data),
        .read_addr(tx_rd_ptr),
        .read_clock(eth_txclk)
    );

    /* verilator lint_off WIDTH */
    assign tx_a_full = tx_fifo_count > 4096 - ALMOST_FULL_THRESHOLD;
    assign tx_a_empty = tx_fifo_count < ALMOST_EMPTY_THRESHOLD;
    assign tx_rdy = ~tx_a_full & ~tx_rst_int & ~rst;
    /* verilator lint_on WIDTH */

    reg[3:0] tx_packets_ready = 0; // Number of complete packets in FIFO
    reg tx_finished_packet = 0;
    reg tx_finished_packet_ack = 0;
    reg tx_rst_int = 0;
    reg tx_rst_ack = 0;

    // TX FIFO write logic

    always @(posedge tx_clk) begin
        tx_wr_en <= 0;

        if (tx_finished_packet & ~tx_finished_packet_ack) begin
            tx_finished_packet_ack <= 1;
            tx_packets_ready <= tx_packets_ready - 1;
        end else if (~tx_finished_packet) begin
            tx_finished_packet_ack <= 0;
        end

        if (rst | tx_rst_int) begin
            if (~tx_rst_int) begin
                tx_rst_int <= 1;
            end else if (tx_rst_ack) begin
                tx_rst_int <= 0;
            end
            tx_wr_ptr <= 0;
            tx_wr_en <= 0;
            tx_wr_data <= 0;
            tx_packets_ready <= 0;
        end else if (tx_wren & tx_rdy) begin
            tx_wr_data <= {tx_eop, tx_sop, tx_data};
            tx_wr_en <= 1;
            tx_wr_ptr <= tx_wr_ptr + 1;

            if (tx_eop) begin
                tx_packets_ready <= tx_packets_ready + 1;
            end
        end
    end

    // TX FIFO read logic

    localparam STATE_IDLE = 2'b00;
    localparam STATE_PREAMBLE = 2'b01;
    localparam STATE_DATA = 2'b10;
    localparam STATE_CRC = 2'b11;

    reg[1:0] tx_state = STATE_IDLE;

    wire[7:0] tx_rd_data = tx_rd_fifo_data[7:0];
    wire tx_rd_sop = tx_rd_fifo_data[8];
    wire tx_rd_eop = tx_rd_fifo_data[9];

    reg tx_crc_en = 0;
    reg tx_crc_init = 0;
    wire tx_crc_rst = tx_crc_init | tx_rst_int;
    wire[31:0] tx_crc_out;

    reg[15:0] tx_counter = 0; // Position within packet, increments after every half byte
    reg[7:0] tx_wait_counter = 0;
    reg[2:0] tx_crc_counter = 0;

    assign eth_rstn = ~tx_rst_int;

    CRC32 tx_crc32 (
        .clk(eth_txclk),
        .rst(tx_crc_rst),
        .data_in(tx_rd_data),
        .data_valid(tx_crc_en),
        .crc_out(tx_crc_out)
    );

    always @(*) begin
        case (tx_state)
            // Send preamble of 55...55D
            STATE_PREAMBLE: begin
                eth_txen = 1'b1;

                if (tx_counter < 16'h00f) begin
                    eth_txd = 4'h5;
                end else begin
                    eth_txd = 4'hd;
                end
            end

            // Send packet data
            STATE_DATA: begin
                eth_txen = 1'b1;

                if (tx_counter[0]) begin
                    eth_txd = tx_rd_data[7:4];
                end else begin
                    eth_txd = tx_rd_data[3:0];
                end
            end

            // Send CRC
            STATE_CRC: begin
                eth_txen = 1'b1;

                eth_txd = {
                    tx_crc_out[4*tx_crc_counter + 3],
                    tx_crc_out[4*tx_crc_counter + 2],
                    tx_crc_out[4*tx_crc_counter + 1],
                    tx_crc_out[4*tx_crc_counter + 0]
                };
            end

            // Idle
            STATE_IDLE: begin
                eth_txd = 4'b0;
                eth_txen = 1'b0;
            end
        endcase
    end

    always @(posedge eth_txclk) begin
        if (tx_rst_int) begin
            tx_rst_ack <= 1;
            tx_rd_ptr <= 0;
            tx_state <= STATE_IDLE;
            tx_counter <= 0;
            tx_wait_counter <= 64;
        end else begin
            tx_rst_ack <= 0;
            tx_counter <= tx_counter + 1;

            if (tx_finished_packet_ack) begin
                tx_finished_packet <= 0;
            end

            case (tx_state)
                STATE_IDLE: begin
                    if (tx_wait_counter > 0) begin
                        tx_wait_counter <= tx_wait_counter - 1;
                        tx_crc_init = 1;
                    end else if (tx_packets_ready > 0) begin
                        tx_counter <= 0;
                        tx_crc_init = 0;

                        if (tx_rd_sop) begin
                            tx_state <= STATE_PREAMBLE;
                        end else begin
                            tx_rd_ptr <= tx_rd_ptr + 1;
                            tx_wait_counter <= 2; // This gives the fifo a cycle to work
                        end
                    end
                end

                STATE_PREAMBLE: begin
                    if (tx_counter == 16'hf) begin
                        tx_state <= STATE_DATA;
                        tx_crc_en <= 1;
                    end
                end

                STATE_DATA: begin
                    if (tx_counter[0]) begin
                        tx_crc_en <= 1; // Calculate CRC on every other cycle

                        // End transmission
                        if (tx_rd_eop) begin
                            tx_state <= STATE_CRC;
                            tx_crc_en <= 0;
                        end
                    end else begin
                        if (~tx_rd_eop) begin
                            tx_rd_ptr <= tx_rd_ptr + 1; // Increment read pointer
                        end

                        tx_crc_en <= 0;
                    end
                end

                STATE_CRC: begin
                    tx_crc_counter <= tx_crc_counter + 1;

                    if (tx_crc_counter == 3'h7) begin
                        tx_state <= STATE_IDLE;
                        tx_wait_counter <= WAIT_LEN;
                        tx_finished_packet <= 1;
                    end
                end
            endcase
        end
    end

    /* ========== RX ========== */

    reg[11:0] rx_rd_ptr = 0;
    reg[11:0] rx_wr_ptr = 0;
    wire[11:0] rx_fifo_count = rx_wr_ptr - rx_rd_ptr;

    reg rx_wr_en;
    reg[9:0] rx_wr_data;
    wire[9:0] rx_rd_fifo_data;

    SimpleMacFifo rx_fifo (
        // Write
        .data(),
        .write_addr(rx_wr_ptr),
        .we(rx_wr_en),
        .write_clock(eth_rxclk),

        // Read
        .q(rx_rd_fifo_data),
        .read_addr(rx_rd_ptr),
        .read_clock(rx_clk)
    );

    /* verilator lint_off WIDTH */
    assign rx_a_full = rx_fifo_count > 4096 - ALMOST_FULL_THRESHOLD;
    assign rx_a_empty = rx_fifo_count < ALMOST_EMPTY_THRESHOLD;
    assign rx_empty = rx_fifo_count == 0;
    // assign rx_rdy = ~tx_a_full & ~tx_rst_int & ~rst;
    /* verilator lint_on WIDTH */

    reg[3:0] rx_packets_ready = 0; // Number of complete packets in FIFO
    // reg rx_finished_packet = 0;
    // reg rx_finished_packet_ack = 0;
    // reg rx_rst_int = 0;
    // reg rx_rst_ack = 0;

    // RX FIFO write logic

    reg[1:0] rx_state = STATE_IDLE;

    always @(posedge eth_rxclk or posedge rst) begin
        rx_wr_en <= 0;

        if (rst) begin
            // rx_rst_ack <= 1;
            // rx_wr_ptr <= 0;
        end else begin
            case (rx_state)
                STATE_IDLE: begin
                    // if (eth_rxdv)
                end

                STATE_PREAMBLE: begin
                    
                end

                STATE_DATA: begin
                    
                end

                STATE_CRC: begin
                    
                end
            endcase
        end
    end

    // RX FIFO read logic

endmodule
