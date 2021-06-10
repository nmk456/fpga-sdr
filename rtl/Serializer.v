`timescale 1ns / 1ns

module Serializer(
    input clk,
    input rst,

    // Data inputs
    input[13:0] idata_in,
    input[13:0] qdata_in,
    input data_valid,
    output reg data_ready = 0,

    // LVDS outputs
    output txclk,
    output reg tx
);

    parameter WAIT_LEN = 8'd64;

    localparam STATE_INIT = 2'b00;
    localparam STATE_WAIT = 2'b01;
    localparam STATE_I_DATA = 2'b10;
    localparam STATE_Q_DATA = 2'b11;

    reg[1:0] state = STATE_INIT;

    reg[13:0] idata_reg = 0;
    reg[13:0] idata_next = 0;
    reg[13:0] qdata_reg = 0;
    reg[13:0] qdata_next = 0;
    wire[13:0] send_data;
    reg[2:0] tx_counter = 0;
    reg[7:0] wait_counter = 0;
    // reg have_next = 0;

    assign txclk = clk;
    assign send_data = (state == STATE_I_DATA) ? idata_reg : qdata_reg;

    always @(*) begin
        if (state == STATE_I_DATA || state == STATE_Q_DATA) begin
            case (tx_counter)
                3'b000: if (state == STATE_I_DATA) begin
                    tx = txclk ? 1'b1 : 1'b0;
                end else begin
                    tx = txclk ? 1'b0 : 1'b1;
                end
                3'b001: tx = txclk ? send_data[13] : send_data[12];
                3'b010: tx = txclk ? send_data[11] : send_data[10];
                3'b011: tx = txclk ? send_data[9] : send_data[8];
                3'b100: tx = txclk ? send_data[7] : send_data[6];
                3'b101: tx = txclk ? send_data[5] : send_data[4];
                3'b110: tx = txclk ? send_data[3] : send_data[2];
                3'b111: tx = txclk ? send_data[1] : send_data[0];
            endcase
        end else begin
            tx = 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_INIT;
        end else begin
            case (state)
                STATE_INIT: begin // Set to initial values
                    state <= STATE_WAIT;
                    wait_counter <= 0;
                    data_ready <= 1;
                    // have_next <= 0;
                end
                STATE_WAIT: begin // Send zeros for a while
                    if (wait_counter == WAIT_LEN) begin
                        state <= STATE_I_DATA;
                        data_ready <= 1'b1;
                        tx_counter <= 3'b0000;
                        idata_reg <= idata_next;
                        qdata_reg <= qdata_next;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end
                default: begin // STATE_I_DATA or STATE_Q_DATA
                    tx_counter <= tx_counter + 1;
                end
            endcase

            if (data_ready && data_valid) begin
                idata_next <= idata_in;
                qdata_next <= qdata_in;

                data_ready <= 1'b0;
            end

            if (tx_counter == 3'b111) begin
                if (state == STATE_I_DATA) begin
                    state <= STATE_Q_DATA;
                end else if (state == STATE_Q_DATA) begin
                    state <= STATE_I_DATA;

                    data_ready <= 1'b1;

                    idata_reg <= idata_next;
                    qdata_reg <= qdata_next;
                end
            end
        end
    end

endmodule
