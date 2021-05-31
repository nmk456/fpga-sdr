`timescale 1ns / 1ns

module LVDS_TX(
    input clk,
    input reset_n,

    // Data inputs
    input oe,
    input[7:0] data_in,
    output reg data_ready,

    // LVDS outputs
    output txclk,
    output reg tx
);

    parameter WAIT_LEN = 100;

    localparam STATE_INIT = 2'b00;
    localparam STATE_WAIT = 2'b01;
    localparam STATE_DATAIN = 2'b10;
    localparam STATE_SEND = 2'b11;

    reg[1:0] state = 0;

    reg oe_int = 0;
    // reg[1:0] to_send = 0;
    reg[7:0] data_reg = 0;
    reg[1:0] tx_counter = 0;
    reg[7:0] wait_counter = 0;

    assign txclk = oe_int ? clk : 1'b0;
    // assign tx = ~oe_int ? 1'b0 : clk ? to_send[0] : to_send[1];

    always @(*) begin
        if (oe_int) begin
            if (state == STATE_SEND) begin
                case (tx_counter)
                    2'b11: tx = txclk ? data_reg[7] : data_reg[6];
                    2'b00: tx = txclk ? data_reg[5] : data_reg[4];
                    2'b01: tx = txclk ? data_reg[3] : data_reg[2];
                    2'b10: tx = txclk ? data_reg[1] : data_reg[0];
                endcase

                if (tx_counter == 2'b11) begin
                    data_reg <= data_in;
                end
            end else if (state == STATE_DATAIN) begin
                tx = clk ? 1'b1 : 1'b0;
                // data_reg <= data_in;
            end else begin
                tx = 0;
            end
        end else begin
            tx = 0;
        end
    end

    always @(posedge clk) begin
        if (~reset_n) begin
            state <= STATE_INIT;
        end else begin
            case (state)
                STATE_INIT: begin // Set to initial values
                    state <= STATE_WAIT;
                    wait_counter <= 0;
                    // to_send <= 0;
                    // data_reg <= 0;
                    data_ready <= 0;
                    oe_int <= 0;
                end
                STATE_WAIT: begin // Send zeros for a while
                    oe_int <= 1;
                    if (wait_counter == WAIT_LEN) begin
                        state <= STATE_DATAIN;
                        data_ready <= 1;
                        // to_send <= 2'b10; // Set up sync bits
                        tx_counter <= 2'b11;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
                STATE_DATAIN: begin // Grab data
                    // if (data_ready) begin
                        state <= STATE_SEND;
                        data_ready <= 0;
                        // data_reg <= data_in;
                    // end
                end
                STATE_SEND: begin // Send data
                    tx_counter <= tx_counter + 1;

                    // if (tx_counter == 2'b01) begin
                        // data_ready <= 1;
                    // end
                    if (tx_counter == 2'b10) begin
                        state <= STATE_DATAIN;
                        data_ready <= 1;
                    end
                end
            endcase
        end
    end

endmodule
