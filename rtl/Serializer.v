`timescale 1ns / 1ns

module Serializer(
    input clk,
    input reset_n,

    // Data inputs
    input oe,
    input[13:0] idata_in,
    input[13:0] qdata_in,
    output reg data_ready,

    // LVDS outputs
    output txclk,
    output reg tx
);

    parameter WAIT_LEN = 64;

    localparam STATE_INIT = 2'b00;
    localparam STATE_WAIT = 2'b01;
    localparam STATE_DATAIN = 2'b10;
    localparam STATE_SEND = 2'b11;

    reg[1:0] state = 0;

    reg oe_int = 0;
    reg[31:0] data_reg = 0;
    reg[3:0] tx_counter = 0;
    reg[7:0] wait_counter = 0;

    assign txclk = oe_int ? clk : 1'b0;

    always @(*) begin
        if (oe_int) begin
            if (state == STATE_SEND) begin
                case (tx_counter)
                    4'b1111: tx = txclk ? data_reg[31] : data_reg[30];
                    4'b0000: tx = txclk ? data_reg[29] : data_reg[28];
                    4'b0001: tx = txclk ? data_reg[27] : data_reg[26];
                    4'b0010: tx = txclk ? data_reg[25] : data_reg[24];
                    4'b0011: tx = txclk ? data_reg[23] : data_reg[22];
                    4'b0100: tx = txclk ? data_reg[21] : data_reg[20];
                    4'b0101: tx = txclk ? data_reg[19] : data_reg[18];
                    4'b0110: tx = txclk ? data_reg[17] : data_reg[16];
                    4'b0111: tx = txclk ? data_reg[15] : data_reg[14];
                    4'b1000: tx = txclk ? data_reg[13] : data_reg[12];
                    4'b1001: tx = txclk ? data_reg[11] : data_reg[10];
                    4'b1010: tx = txclk ? data_reg[9] : data_reg[8];
                    4'b1011: tx = txclk ? data_reg[7] : data_reg[6];
                    4'b1100: tx = txclk ? data_reg[5] : data_reg[4];
                    4'b1101: tx = txclk ? data_reg[3] : data_reg[2];
                    4'b1110: tx = txclk ? data_reg[1] : data_reg[0];
                endcase

                if (tx_counter == 4'b1111) begin
                    data_reg = idata_in;
                end
            end else if (state == STATE_DATAIN) begin
                tx = clk ? 1'b1 : 1'b0;
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
                    data_ready <= 0;
                    oe_int <= 0;
                end
                STATE_WAIT: begin // Send zeros for a while
                    oe_int <= 1;
                    if (wait_counter == WAIT_LEN) begin
                        state <= STATE_DATAIN;
                        data_ready <= 1;
                        tx_counter <= 4'b1111;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
                STATE_DATAIN: begin // Grab data
                    state <= STATE_SEND;
                    data_ready <= 0;
                end
                STATE_SEND: begin // Send data
                    tx_counter <= tx_counter + 1;

                    if (tx_counter == 4'b1110) begin
                        state <= STATE_DATAIN;
                        data_ready <= 1;
                    end
                end
            endcase
        end
    end

endmodule
