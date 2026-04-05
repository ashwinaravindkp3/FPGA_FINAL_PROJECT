`timescale 1ns / 1ps

module bin2bcd(
    input [15:0] bin,
    output reg [3:0] d0,
    output reg [3:0] d1,
    output reg [3:0] d2,
    output reg [3:0] d3
);
    // Double Dabble Algorithm (Shift and Add 3)
    // Extemely low LUT usage compared to massive division (%) operators!
    integer i;
    always @(*) begin
        d3 = 0; d2 = 0; d1 = 0; d0 = 0;
        for (i = 15; i >= 0; i = i - 1) begin
            if (d3 >= 5) d3 = d3 + 3;
            if (d2 >= 5) d2 = d2 + 3;
            if (d1 >= 5) d1 = d1 + 3;
            if (d0 >= 5) d0 = d0 + 3;
            
            d3 = {d3[2:0], d2[3]};
            d2 = {d2[2:0], d1[3]};
            d1 = {d1[2:0], d0[3]};
            d0 = {d0[2:0], bin[i]};
        end
    end
endmodule
