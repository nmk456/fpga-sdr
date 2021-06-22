module CRC32(
    input clk,
    input rst,
    input [7:0] data_in,
    input data_valid,
    output [31:0] crc_out
);

    reg[31:0] crc_q = 32'hffffffff;
    reg[31:0] crc_c;

    assign crc_out = ~crc_q;

    lfsr #(
        .LFSR_WIDTH(32),
        .LFSR_POLY(32'h04c11db7),
        .LFSR_CONFIG("GALOIS"),
        .LFSR_FEED_FORWARD(0),
        .REVERSE(1),
        .DATA_WIDTH(8),
        .STYLE("AUTO")
    ) eth_crc32 (
        .data_in(data_in),
        .state_in(crc_q),
        .data_out(),
        .state_out(crc_c)
    );

    always @(posedge clk) begin
        if(rst) begin
            crc_q <= {32{1'b1}};
        end else begin
            crc_q <= data_valid ? crc_c : crc_q;
        end
    end
endmodule
