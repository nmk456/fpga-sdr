module SimpleMac (
    input rst, // active high and registered to tx_clk

    // MII interface
    input eth_txclk,
    output eth_txen,
    output reg[3:0] eth_txd
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
    output tx_a_empty

    // Receive interface - TODO
);

    parameter ALMOST_FULL_THRESHOLD = 64;
    parameter ALMOST_EMPTY_THRESHOLD = 64;

    // 2048 byte deep FIFO
    // FIFO stores 8 data bits, sop, eop, and err signals
    // single entry = {err, eop, sop, data}, 11 bits wide

    reg[10:0] fifo_mem[2047:0];
    reg[10:0] rd_ptr = 0;
    reg[10:0] wr_ptr = 0;
    reg[10:0] fifo_count = wr_ptr - rd_ptr;

    assign tx_a_full = fifo_count > 2048 - ALMOST_FULL_THRESHOLD;
    assign tx_a_empty = fifo_count < ALMOST_EMPTY_THRESHOLD;
    assign tx_rdy = ~tx_a_full;

    integer i;
    initial begin
        for (i = 0; i<2048; i=i+1) begin
            fifo_mem[i] = 0;
        end
    end

    reg[3:0] packets_ready; // Number of complete packets in FIFO

    // Write logic

    always @(posedge tx_clk) begin
        if (tx_rdy) begin
            fifo_mem[wr_ptr] <= {tx_err, tx_eop, tx_sop, tx_data};
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read logic

    wire[7:0] read_data = fifo_mem[rd_ptr][7:0]; // Current data
    wire read_sop = fifo_mem[rd_ptr][8]; // Current sop value
    wire read_eop = fifo_mem[rd_ptr][9]; // Current eop value
    wire[3:0] tx_high = read_data[7:4]; // High nibble
    wire[3:0] tx_low = read_data[3:0]; // Low nibble
    reg byte_pos = 0; // Sending high or low byte
    reg preamble = 1; // Sending preamble
    reg[3:0] preamble_counter = 15;

    // assign eth_txd = byte_pos ? tx_high : tx_low;

    always @(*) begin
        if (preamble)
            if (preamble_counter == 0)
                eth_txd = 4'hb;
            else
                eth_txd = 4'ha;
        else
            if (byte_pos)
                eth_txd = tx_high;
            else
                eth_txd = tx_low;
    end

    always @(posedge eth_txclk) begin
        if (packets_ready > 0) begin
            if (preamble) begin // Preamble
                if (preamble_counter == 0) begin
                    eth_txd <= 4'hb;
                    eth_txen <= 1;
                end else begin
                    eth_txd <= 4'ha;
                    eth_txen <= 1;
                end

                preamble_counter <= preamble_counter - 1;
            end else begin // Packet
                byte_pos <= ~byte_pos;

                if (byte_pos) begin
                    eth_txd <= tx_high;
                    rd_ptr <= rd_ptr + 1;
                end else begin
                    eth_txd <= tx_low;
                end
            end
        end
    end

endmodule
