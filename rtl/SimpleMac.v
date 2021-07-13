module SimpleMac (
    input rst, // active high, asynchronous

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
    input[7:0] tx_tdata,
    input tx_tlast,
    input tx_tuser,
    output tx_tready,
    input tx_tvalid,

    output tx_a_full,
    output tx_a_empty,

    // Receive interface
    input rx_clk,
    output[7:0] rx_tdata,
    output rx_tlast,
    output rx_tuser,
    input rx_tready,
    output reg rx_tvalid,

    output rx_a_full,
    output rx_a_empty,
    output rx_empty
);

    parameter ALMOST_FULL_THRESHOLD = 64;
    parameter ALMOST_EMPTY_THRESHOLD = 64;
    parameter WAIT_LEN = 24; // 24 nibbles is 96 bits, standard minimum interpacket gap

    parameter TX_FIFO_ADDR_WIDTH = 12;
    parameter RX_FIFO_ADDR_WIDTH = 12;

    /* ========== TX ========== */

    reg[TX_FIFO_ADDR_WIDTH-1:0] tx_rd_ptr = 0;
    reg[TX_FIFO_ADDR_WIDTH-1:0] tx_wr_ptr = 0;
    reg[TX_FIFO_ADDR_WIDTH-1:0] tx_wr_ptr_start = 0;
    wire[TX_FIFO_ADDR_WIDTH-1:0] tx_fifo_count = tx_wr_ptr - tx_rd_ptr;

    reg tx_wr_en;
    reg[8:0] tx_wr_data;
    wire[8:0] tx_rd_fifo_data;

    SimpleMacFifo #(
        .DATA_WIDTH(9),
        .ADDR_WIDTH(TX_FIFO_ADDR_WIDTH)
    ) tx_fifo (
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
    assign tx_tready = ~tx_a_full & ~rst;
    /* verilator lint_on WIDTH */

    reg[3:0] tx_packets_ready = 0; // Number of complete packets in FIFO
    reg tx_finished_packet = 0;
    reg tx_finished_packet_ack = 0;

    // TX FIFO write logic

    always @(posedge tx_clk or posedge rst) begin
        if (rst) begin
            tx_wr_ptr <= 0;
            tx_wr_ptr_start <= 0;
            tx_wr_en <= 0;
            tx_wr_data <= 0;
            tx_packets_ready <= 0;
        end else begin
            tx_wr_en <= 0;

            if (tx_finished_packet & ~tx_finished_packet_ack) begin
                tx_finished_packet_ack <= 1;
                tx_packets_ready <= tx_packets_ready - 1;
            end else if (~tx_finished_packet) begin
                tx_finished_packet_ack <= 0;
            end

            if (tx_tvalid & tx_tready) begin
                tx_wr_data <= {tx_tlast, tx_tdata};
                tx_wr_en <= 1;
                tx_wr_ptr <= tx_wr_ptr + 1;

                if (tx_tlast & ~tx_tuser) begin
                    // Handle increase and decrease on same cycle
                    if (tx_finished_packet & ~tx_finished_packet_ack) begin
                        tx_finished_packet_ack <= 1;
                        tx_packets_ready <= tx_packets_ready;
                    end else begin
                        tx_packets_ready <= tx_packets_ready + 1;
                    end

                    tx_wr_ptr_start <= tx_wr_ptr + 1;
                end else if (tx_tuser) begin
                    tx_wr_ptr <= tx_wr_ptr_start;
                    tx_wr_en <= 0;
                end
            end
        end
    end

    // TX FIFO read logic

    localparam STATE_IDLE = 3'b000;
    localparam STATE_PREAMBLE = 3'b001;
    localparam STATE_DATA = 3'b010;
    localparam STATE_ERROR = 3'b011;
    localparam STATE_CRC = 3'b100;

    reg[2:0] tx_state = STATE_IDLE;

    wire[7:0] tx_rd_data = tx_rd_fifo_data[7:0];
    wire tx_rd_tlast = tx_rd_fifo_data[8];

    reg tx_crc_en = 0;
    reg tx_crc_init = 0;
    wire tx_crc_rst = tx_crc_init | rst;
    wire[31:0] tx_crc_out;

    reg[15:0] tx_counter = 0; // Position within packet, increments after every half byte
    reg[7:0] tx_wait_counter = 0;
    reg[2:0] tx_crc_counter = 0;

    assign eth_rstn = ~rst;

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
            default: begin
                eth_txd = 4'b0;
                eth_txen = 1'b0;
            end
        endcase
    end

    always @(posedge eth_txclk or posedge rst) begin
        if (rst) begin
            tx_rd_ptr <= 0;
            tx_state <= STATE_IDLE;
            tx_counter <= 0;
            tx_wait_counter <= 64;
        end else begin
            tx_counter <= tx_counter + 1;

            if (tx_finished_packet_ack) begin
                tx_finished_packet <= 0;
            end

            case (tx_state)
                default: begin
                    if (tx_wait_counter > 0) begin
                        tx_wait_counter <= tx_wait_counter - 1;
                        tx_crc_init = 1;
                    end else if (tx_packets_ready > 0) begin
                        tx_counter <= 0;
                        tx_crc_init = 0;

                        tx_state <= STATE_PREAMBLE;
                        tx_rd_ptr <= tx_rd_ptr + 1;
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
                        if (tx_rd_tlast) begin
                            tx_state <= STATE_CRC;
                            tx_crc_en <= 0;
                        end
                    end else begin
                        if (~tx_rd_tlast) begin
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

    reg[RX_FIFO_ADDR_WIDTH-1:0] rx_rd_ptr = 0;
    reg[RX_FIFO_ADDR_WIDTH-1:0] rx_wr_ptr = 0;
    wire[RX_FIFO_ADDR_WIDTH-1:0] rx_fifo_count = rx_wr_ptr - rx_rd_ptr;

    reg rx_wr_en;
    reg[9:0] rx_wr_data;
    wire[9:0] rx_rd_fifo_data;

    SimpleMacFifo #(
        .DATA_WIDTH(10),
        .ADDR_WIDTH(RX_FIFO_ADDR_WIDTH)
    ) rx_fifo (
        // Write
        .data(rx_wr_data),
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
    /* verilator lint_on WIDTH */

    // RX FIFO write logic

    reg[2:0] rx_state = STATE_IDLE;

    reg[15:0] rx_counter = 0;
    reg[31:0] rx_shift_buffer = 0;

    reg rx_crc_init = 0;
    wire rx_crc_rst = rx_crc_init | rst;
    wire[31:0] rx_crc_out;

    CRC32 rx_crc32 (
        .clk(eth_rxclk),
        .rst(rx_crc_rst),
        .data_in(rx_wr_data[7:0]),
        .data_valid(rx_wr_en),
        .crc_out(rx_crc_out)
    );

    always @(posedge eth_rxclk or posedge rst) begin
        rx_wr_en <= 0;

        if (rst) begin
            rx_wr_ptr <= 0;
            rx_counter <= 0;
        end else begin
            case (rx_state)
                default: begin
                    if (eth_rxdv) begin
                        rx_state <= STATE_PREAMBLE;
                        rx_shift_buffer <= 0;
                        rx_crc_init <= 1;
                    end
                end

                STATE_PREAMBLE: begin
                    if (eth_rxd == 4'hd) begin
                        rx_state <= STATE_DATA;
                        rx_counter <= 0;
                        rx_crc_init <= 0;
                    end
                end

                STATE_DATA: begin
                    if (eth_rxdv) begin
                        rx_counter <= rx_counter + 1;

                        if (rx_counter[0]) begin
                            rx_shift_buffer[31:28] <= eth_rxd;
                            rx_shift_buffer[27:0] <= rx_shift_buffer[31:4];

                            rx_wr_en <= (rx_counter > 7) ? 1 : 0;
                        end else begin
                            rx_shift_buffer[31:28] <= eth_rxd;
                            rx_shift_buffer[27:0] <= rx_shift_buffer[31:4];

                            rx_wr_ptr <= rx_wr_ptr + ((rx_counter > 8) ? 1 : 0);
                            rx_wr_en <= 0;
                            rx_wr_data <= {2'b00, rx_shift_buffer[7:0]};
                        end

                        if (eth_rxer | &rx_fifo_count) begin
                            rx_state <= STATE_ERROR;
                            rx_wr_en <= 1;
                            rx_wr_data <= {2'b11, 8'b0};
                        end
                    end else begin
                        rx_state <= STATE_CRC;
                    end
                end

                STATE_ERROR: begin
                    rx_wr_en <= 0;
                    if (~eth_rxdv) begin
                        rx_state <= STATE_IDLE;
                        rx_wr_ptr <= rx_wr_ptr + 1;
                    end
                end

                STATE_CRC: begin
                    if (rx_wr_en) begin
                        rx_state <= STATE_IDLE;
                        rx_wr_en <= 0;
                        rx_wr_data <= 0;
                    end else begin
                        rx_wr_en <= 1;
                        rx_wr_data[8] <= 1;

                        if (rx_shift_buffer != rx_crc_out) begin
                            rx_wr_data[9] <= 1;
                        end
                    end
                end
            endcase
        end
    end

    // RX FIFO read logic

    assign rx_tdata = rx_rd_fifo_data[7:0];
    assign rx_tlast = rx_rd_fifo_data[8];
    assign rx_tuser = rx_rd_fifo_data[9];

    reg frame_active1 = 0;
    reg frame_active2 = 0;
    reg rx_done = 0;

    always @(posedge rx_clk or posedge rst) begin
        frame_active1 <= eth_rxdv;
        frame_active2 <= frame_active1;

        if (rst) begin
            rx_rd_ptr <= 0;
        end else begin
            if (rx_tready & (rx_fifo_count > 8 | (~frame_active2 & rx_fifo_count > 0))) begin
                rx_rd_ptr <= rx_rd_ptr + 1;
                rx_tvalid <= 1;
                rx_done <= 0;
            end else if (rx_tlast & ~rx_done) begin
                rx_tvalid <= 1;
                rx_done <= 1;
            end else begin
                rx_tvalid <= 0;
            end
        end
    end

endmodule
