`timescale 1ns / 1ps

module seven_seg_driver (
    input clk,                     // 100 MHz clock (Basys3)
    input [15:0] value,            // Number to display (0–9999 or hex)
    output reg [6:0] seg,          // Segments (a–g)
    output reg [3:0] an            // Anodes
);

// Clock divider for multiplexing (~1kHz refresh)
reg [19:0] clk_div = 0;
always @(posedge clk)
    clk_div <= clk_div + 1;

wire [1:0] sel = clk_div[19:18];   // selects digit

// Efficient Double-Dabble extraction (LUT reduction)
wire [3:0] d0, d1, d2, d3;
bin2bcd bcd_conv(
    .bin(value),
    .d0(d0),
    .d1(d1),
    .d2(d2),
    .d3(d3)
);

reg [3:0] digit;

// Digit selection (multiplexing)
always @(*) begin
    case(sel)
        2'b00: begin an = 4'b1110; digit = d0; end
        2'b01: begin an = 4'b1101; digit = d1; end
        2'b10: begin an = 4'b1011; digit = d2; end
        2'b11: begin an = 4'b0111; digit = d3; end
    endcase
end

// 7-segment decoder (active LOW)
always @(*) begin
    case(digit)
        4'd0: seg = 7'b1000000;
        4'd1: seg = 7'b1111001;
        4'd2: seg = 7'b0100100;
        4'd3: seg = 7'b0110000;
        4'd4: seg = 7'b0011001;
        4'd5: seg = 7'b0010010;
        4'd6: seg = 7'b0000010;
        4'd7: seg = 7'b1111000;
        4'd8: seg = 7'b0000000;
        4'd9: seg = 7'b0010000;
        default: seg = 7'b1111111;
    endcase
end

endmodule
