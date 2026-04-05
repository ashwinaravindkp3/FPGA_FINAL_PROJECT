`timescale 1ns / 1ps

module top (
    input clk,
    input btnC,        // Center button to reset
    output [6:0] seg,
    output [3:0] an
);

    wire rst = btnC;
    reg start;
    wire fft_done;
    
    // Auto-trigger mechanism starting on power-up / reset
    reg [3:0] start_ctr = 0;
    always @(posedge clk) begin
        if (rst) begin
            start_ctr <= 0;
            start <= 0;
        end else if (start_ctr < 10) begin
            start_ctr <= start_ctr + 1;
            start <= 1;
        end else begin
            start <= 0;
        end
    end

    wire [3:0] read_addr;
    wire signed [15:0] read_data_re;
    wire signed [15:0] read_data_im;
    
    fft_16 my_fft (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(fft_done),
        .read_addr(read_addr),
        .read_data_re(read_data_re),
        .read_data_im(read_data_im)
    );
    
    // 1 Hz slow clock to iterate the sequence display automatically
    reg [3:0] seq_idx = 0;
    reg [26:0] slow_clk_ctr = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            slow_clk_ctr <= 0;
            seq_idx <= 0;
        end else if (fft_done) begin
            if (slow_clk_ctr == 100_000_000 - 1) begin
                slow_clk_ctr <= 0;
                seq_idx <= seq_idx + 1;
            end else begin
                slow_clk_ctr <= slow_clk_ctr + 1;
            end
        end
    end
    
    assign read_addr = seq_idx;
    
    // Approximate Magnitude calculation explicitly taking logic over multipliers.
    // Sum of Absolutes is an incredibly low-LUT approximation.
    wire [15:0] abs_re = (read_data_re[15]) ? -read_data_re : read_data_re;
    wire [15:0] abs_im = (read_data_im[15]) ? -read_data_im : read_data_im;
    wire [15:0] mag = abs_re + abs_im;
    
    // Output Format: Index Value
    // For example "1 25" -> (Index=1, Mag=25). We shift index into 1000s column!
    // Ensures display fits without needing heavy hex decoding!
    // Ex: Bin 0 size 8000 -> displays "0800" (clipped into range nicely) or "8000" if index=0
    wire [15:0] display_val;
    // Limit to 999 max on the mag so it doesn't overflow to the Index column
    wire [15:0] mag_clamped = (mag > 999) ? 999 : mag; 
    
    assign display_val = (seq_idx * 16'd1000) + mag_clamped;
    
    seven_seg_driver display (
        .clk(clk),
        .value(display_val),
        .seg(seg),
        .an(an)
    );

endmodule
