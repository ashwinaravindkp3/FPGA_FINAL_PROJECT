`timescale 1ns / 1ps

module butterfly_nodsp (
    input clk,
    input signed [15:0] a_re,
    input signed [15:0] a_im,
    input signed [15:0] b_re,
    input signed [15:0] b_im,
    input signed [15:0] w_re,
    input signed [15:0] w_im,
    output reg signed [15:0] y1_re,
    output reg signed [15:0] y1_im,
    output reg signed [15:0] y2_re,
    output reg signed [15:0] y2_im,
    input rst
);

    reg signed [15:0] a_re_r, a_im_r, b_re_r, b_im_r, w_re_r, w_im_r;
    always @(posedge clk) begin
        if (rst) begin
            a_re_r <= 0; a_im_r <= 0;
            b_re_r <= 0; b_im_r <= 0;
            w_re_r <= 0; w_im_r <= 0;
        end else begin
            a_re_r <= a_re; a_im_r <= a_im;
            b_re_r <= b_re; b_im_r <= b_im;
            w_re_r <= w_re; w_im_r <= w_im;
        end
    end

    // Stage 1: Multiplication (DSP M-register)
    (* use_dsp = "yes" *) reg signed [31:0] p1, p2, p3, p4;
    always @(posedge clk) begin
        if (rst) begin
            p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0;
        end else begin
            p1 <= b_re_r * w_re_r;
            p2 <= b_im_r * w_im_r;
            p3 <= b_re_r * w_im_r;
            p4 <= b_im_r * w_re_r;
        end
    end
    
    // Stage 2: Subtraction/Addition (Accumulator pushed to Fabric LUTs to solve Hold timing race)
    reg signed [31:0] bw_re_full, bw_im_full;
    always @(posedge clk) begin
        if (rst) begin
            bw_re_full <= 0; bw_im_full <= 0;
        end else begin
            bw_re_full <= p1 - p2;
            bw_im_full <= p3 + p4;
        end
    end
    
    reg signed [15:0] a_re_d1, a_im_d1;
    reg signed [15:0] a_re_d2, a_im_d2;
    always @(posedge clk) begin
        if (rst) begin
            a_re_d1 <= 0; a_im_d1 <= 0;
            a_re_d2 <= 0; a_im_d2 <= 0;
        end else begin
            a_re_d1 <= a_re_r; a_im_d1 <= a_im_r;
            a_re_d2 <= a_re_d1; a_im_d2 <= a_im_d1;
        end
    end
    
    // Stage 3: Pipelined Saturation (Breaks massive LUT combinational paths)
    reg signed [15:0] bw_re_sat, bw_im_sat;
    reg signed [15:0] a_re_d3, a_im_d3;
    
    always @(posedge clk) begin
        if (rst) begin
            bw_re_sat <= 0; bw_im_sat <= 0;
            a_re_d3 <= 0; a_im_d3 <= 0;
        end else begin
            // Compact pipelined inline saturation checking
            if (bw_re_full[31:15] > 32'h0000_0000) bw_re_sat <= 16'h7FFF;
            else if (bw_re_full[31:15] < 32'hFFFF_FFFF) bw_re_sat <= 16'h8000;
            else bw_re_sat <= bw_re_full[30:15];
            
            if (bw_im_full[31:15] > 32'h0000_0000) bw_im_sat <= 16'h7FFF;
            else if (bw_im_full[31:15] < 32'hFFFF_FFFF) bw_im_sat <= 16'h8000;
            else bw_im_sat <= bw_im_full[30:15];
            
            a_re_d3 <= a_re_d2;
            a_im_d3 <= a_im_d2;
        end
    end
    
    // Stage 4: DELIBERATELY no DSP constraint here to drop DSP allocation
    wire signed [15:0] sum_re = a_re_d3 + bw_re_sat;
    wire signed [15:0] sum_im = a_im_d3 + bw_im_sat;
    wire signed [15:0] diff_re = a_re_d3 - bw_re_sat;
    wire signed [15:0] diff_im = a_im_d3 - bw_im_sat;

    always @(posedge clk) begin
        if (rst) begin
            y1_re <= 0; y1_im <= 0;
            y2_re <= 0; y2_im <= 0;
        end else begin
            y1_re <= sum_re;
            y1_im <= sum_im;
            y2_re <= diff_re;
            y2_im <= diff_im;
        end
    end
endmodule
