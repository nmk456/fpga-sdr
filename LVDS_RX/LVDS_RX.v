`timescale 1ns / 1ns

module LVDS_TX(
    input clk,
    input reset_n,

    // Data inputs
    input rd_en,
    output[7:0] rd_data,
    output rd_dr,

    // LVDS outputs
    input rxclk,
    input rx
);

    parameter ZERO_LEN = 10;

    reg[7:0] mem[255:0];

    reg[7:0] wr_addr = 0;
    reg[7:0] rd_addr = 0;

    wire[7:0] data_count;
    wire almost_full, almost_empty;

    // Output FIFO

    assign data_count = wr_addr - rd_addr;
    assign almost_full = data_count >= 224;
    assign almost_empty = data_count <= 32;

    always @(posedge clk) begin
        if (~reset_n) begin
            rd_addr <= 0;
        end
    end

    // Deserializer

    localparam STATE_INIT = 0;
    localparam STATE_ZEROS = 1;
    localparam STATE_WAIT = 2;
    localparam STATE_RUN = 3;

    reg[1:0] state = 0;

    reg[7:0] zero_counter;

    wire[1:0] in_data;

    always @(*) begin
        
    end

    always @(posedge rxclk) begin
        if (~reset_n) begin
            state <= STATE_INIT;
        end else begin
            case (state)
                STATE_INIT: begin
                    wr_addr <= 0;
                    zero_counter <= 0;
                    state <= STATE_ZEROS;
                end
                STATE_ZEROS: begin
                    if (in_data == 2'b00) begin
                        zero_counter <= zero_counter + 2;
                    end else if (zero_counter >= ZERO_LEN) begin
                        state <= STATE_WAIT;
                    end else begin
                        zero_counter <= 0;
                    end
                end
                STATE_WAIT:
                STATE_RUN:
            endcase
        end
    end

    // Generated Altera GPIO IP megafunction
    DDR_in ddr_in0 (
        .inclock(rxclk),
        .dout(in_data),
        .pad_in(rx)
    );

endmodule
