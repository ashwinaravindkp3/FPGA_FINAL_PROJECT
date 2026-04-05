`timescale 1ns / 1ps

module radix2_2_butterfly (
    input clk,
    input signed [15:0] a_re,
    input signed [15:0] a_im,
    input signed [15:0] b_re,
    input signed [15:0] b_im,
    input signed [15:0] c_re,
    input signed [15:0] c_im,
    input signed [15:0] d_re,
    input signed [15:0] d_im,
    
    input signed [15:0] w0_re,
    input signed [15:0] w0_im,
    input signed [15:0] w1_re,
    input signed [15:0] w1_im,
    input signed [15:0] w2_re,
    input signed [15:0] w2_im,
    input signed [15:0] w3_re,
    input signed [15:0] w3_im,

    output reg signed [15:0] y1_re,
    output reg signed [15:0] y1_im,
    output reg signed [15:0] y2_re,
    output reg signed [15:0] y2_im,
    output reg signed [15:0] y3_re,
    output reg signed [15:0] y3_im,
    output reg signed [15:0] y4_re,
    output reg signed [15:0] y4_im,
    input rst
);

    // Radix-2^2 is based on Decimation in Frequency (DIF).
    // Additions happen FIRST, then the twiddle multiplications happen LAST.

    // Stage 0: Registers
    reg signed [15:0] a_re_r, a_im_r;
    reg signed [15:0] b_re_r, b_im_r;
    reg signed [15:0] c_re_r, c_im_r;
    reg signed [15:0] d_re_r, d_im_r;
    
    reg signed [15:0] w0_re_r, w0_im_r;
    reg signed [15:0] w1_re_r, w1_im_r;
    reg signed [15:0] w2_re_r, w2_im_r;
    reg signed [15:0] w3_re_r, w3_im_r;

    always @(posedge clk) begin
        if (rst) begin
            a_re_r <= 0; a_im_r <= 0; b_re_r <= 0; b_im_r <= 0;
            c_re_r <= 0; c_im_r <= 0; d_re_r <= 0; d_im_r <= 0;
            w0_re_r <= 0; w0_im_r <= 0; w1_re_r <= 0; w1_im_r <= 0;
            w2_re_r <= 0; w2_im_r <= 0; w3_re_r <= 0; w3_im_r <= 0;
        end else begin
            a_re_r <= a_re; a_im_r <= a_im;
            b_re_r <= b_re; b_im_r <= b_im;
            c_re_r <= c_re; c_im_r <= c_im;
            d_re_r <= d_re; d_im_r <= d_im;
            
            w0_re_r <= w0_re; w0_im_r <= w0_im;
            w1_re_r <= w1_re; w1_im_r <= w1_im;
            w2_re_r <= w2_re; w2_im_r <= w2_im;
            w3_re_r <= w3_re; w3_im_r <= w3_im;
        end
    end

    // Stage 1: BF2 Type I (First Radix-2 structures)
    (* use_dsp = "yes" *) reg signed [15:0] E1_re, E1_im;
    (* use_dsp = "yes" *) reg signed [15:0] E2_re, E2_im;
    (* use_dsp = "yes" *) reg signed [15:0] E3_re, E3_im;
    (* use_dsp = "yes" *) reg signed [15:0] E4_re, E4_im;

    always @(posedge clk) begin
        if (rst) begin
            E1_re <= 0; E1_im <= 0; E2_re <= 0; E2_im <= 0;
            E3_re <= 0; E3_im <= 0; E4_re <= 0; E4_im <= 0;
        end else begin
            E1_re <= a_re_r + c_re_r;
            E1_im <= a_im_r + c_im_r;
            E2_re <= a_re_r - c_re_r;
            E2_im <= a_im_r - c_im_r;
            
            E3_re <= b_re_r + d_re_r;
            E3_im <= b_im_r + d_im_r;
            E4_re <= b_re_r - d_re_r;
            E4_im <= b_im_r - d_im_r;
        end
    end

    // Need to delay twiddles to match pipeline
    reg signed [15:0] w0_re_d1, w0_im_d1, w1_re_d1, w1_im_d1;
    reg signed [15:0] w2_re_d1, w2_im_d1, w3_re_d1, w3_im_d1;
    always @(posedge clk) begin
        if (rst) begin
            w0_re_d1 <= 0; w0_im_d1 <= 0; w1_re_d1 <= 0; w1_im_d1 <= 0;
            w2_re_d1 <= 0; w2_im_d1 <= 0; w3_re_d1 <= 0; w3_im_d1 <= 0;
        end else begin
            w0_re_d1 <= w0_re_r; w0_im_d1 <= w0_im_r;
            w1_re_d1 <= w1_re_r; w1_im_d1 <= w1_im_r;
            w2_re_d1 <= w2_re_r; w2_im_d1 <= w2_im_r;
            w3_re_d1 <= w3_re_r; w3_im_d1 <= w3_im_r;
        end
    end

    // Stage 2: BF2 Type II (Second Radix-2 + trivial -j mults)
    (* use_dsp = "yes" *) reg signed [15:0] Z1_re, Z1_im;
    (* use_dsp = "yes" *) reg signed [15:0] Z2_re, Z2_im;
    (* use_dsp = "yes" *) reg signed [15:0] Z3_re, Z3_im;
    (* use_dsp = "yes" *) reg signed [15:0] Z4_re, Z4_im;

    always @(posedge clk) begin
        if (rst) begin
            Z1_re <= 0; Z1_im <= 0; Z2_re <= 0; Z2_im <= 0;
            Z3_re <= 0; Z3_im <= 0; Z4_re <= 0; Z4_im <= 0;
        end else begin
            Z1_re <= E1_re + E3_re;
            Z1_im <= E1_im + E3_im;
            
            Z3_re <= E1_re - E3_re;
            Z3_im <= E1_im - E3_im;
            
            // Z2 = E2 - j*E4 = (E2_re + E4_im) + j(E2_im - E4_re)
            Z2_re <= E2_re + E4_im;
            Z2_im <= E2_im - E4_re;
            
            // Z4 = E2 + j*E4 = (E2_re - E4_im) + j(E2_im + E4_re)
            Z4_re <= E2_re - E4_im;
            Z4_im <= E2_im + E4_re;
        end
    end

    // Delay twiddles again
    reg signed [15:0] w0_re_d2, w0_im_d2, w1_re_d2, w1_im_d2;
    reg signed [15:0] w2_re_d2, w2_im_d2, w3_re_d2, w3_im_d2;
    always @(posedge clk) begin
        if (rst) begin
            w0_re_d2 <= 0; w0_im_d2 <= 0; w1_re_d2 <= 0; w1_im_d2 <= 0;
            w2_re_d2 <= 0; w2_im_d2 <= 0; w3_re_d2 <= 0; w3_im_d2 <= 0;
        end else begin
            w0_re_d2 <= w0_re_d1; w0_im_d2 <= w0_im_d1;
            w1_re_d2 <= w1_re_d1; w1_im_d2 <= w1_im_d1;
            w2_re_d2 <= w2_re_d1; w2_im_d2 <= w2_im_d1;
            w3_re_d2 <= w3_re_d1; w3_im_d2 <= w3_im_d1;
        end
    end

    // Stage 3: Multiplications (DSP M-Reg)
    (* use_dsp = "yes" *) reg signed [31:0] p1_1, p1_2, p1_3, p1_4;
    (* use_dsp = "yes" *) reg signed [31:0] p2_1, p2_2, p2_3, p2_4;
    (* use_dsp = "yes" *) reg signed [31:0] p3_1, p3_2, p3_3, p3_4;
    (* use_dsp = "yes" *) reg signed [31:0] p4_1, p4_2, p4_3, p4_4;

    always @(posedge clk) begin
        if (rst) begin
            p1_1 <= 0; p1_2 <= 0; p1_3 <= 0; p1_4 <= 0;
            p2_1 <= 0; p2_2 <= 0; p2_3 <= 0; p2_4 <= 0;
            p3_1 <= 0; p3_2 <= 0; p3_3 <= 0; p3_4 <= 0;
            p4_1 <= 0; p4_2 <= 0; p4_3 <= 0; p4_4 <= 0;
        end else begin
            p1_1 <= Z1_re * w0_re_d2; p1_2 <= Z1_im * w0_im_d2;
            p1_3 <= Z1_re * w0_im_d2; p1_4 <= Z1_im * w0_re_d2;

            p2_1 <= Z2_re * w1_re_d2; p2_2 <= Z2_im * w1_im_d2;
            p2_3 <= Z2_re * w1_im_d2; p2_4 <= Z2_im * w1_re_d2;

            p3_1 <= Z3_re * w2_re_d2; p3_2 <= Z3_im * w2_im_d2;
            p3_3 <= Z3_re * w2_im_d2; p3_4 <= Z3_im * w2_re_d2;

            p4_1 <= Z4_re * w3_re_d2; p4_2 <= Z4_im * w3_im_d2;
            p4_3 <= Z4_re * w3_im_d2; p4_4 <= Z4_im * w3_re_d2;
        end
    end

    // Stage 4: Add/Sub for Complex Multiplication (DSP P-Reg)
    (* use_dsp = "yes" *) reg signed [31:0] y1_re_full, y1_im_full;
    (* use_dsp = "yes" *) reg signed [31:0] y2_re_full, y2_im_full;
    (* use_dsp = "yes" *) reg signed [31:0] y3_re_full, y3_im_full;
    (* use_dsp = "yes" *) reg signed [31:0] y4_re_full, y4_im_full;

    always @(posedge clk) begin
        if (rst) begin
            y1_re_full <= 0; y1_im_full <= 0;
            y2_re_full <= 0; y2_im_full <= 0;
            y3_re_full <= 0; y3_im_full <= 0;
            y4_re_full <= 0; y4_im_full <= 0;
        end else begin
            y1_re_full <= p1_1 - p1_2;
            y1_im_full <= p1_3 + p1_4;

            y2_re_full <= p2_1 - p2_2;
            y2_im_full <= p2_3 + p2_4;

            y3_re_full <= p3_1 - p3_2;
            y3_im_full <= p3_3 + p3_4;

            y4_re_full <= p4_1 - p4_2;
            y4_im_full <= p4_3 + p4_4;
        end
    end

    // Saturation logic macro for Q15 shifted outputs
    function signed [15:0] saturate_q15;
        input signed [31:0] val;
        begin
            if (val[31:15] > 32'h0000_0000) begin
                saturate_q15 = 16'h7FFF; // Pos limit
            end else if (val[31:15] < 32'hFFFF_FFFF) begin
                saturate_q15 = 16'h8000; // Neg limit
            end else begin
                saturate_q15 = val[30:15];
            end
        end
    endfunction

    // Stage 5: Saturate back to 16 bits (Q15 format shift) and register
    always @(posedge clk) begin
        if (rst) begin
            y1_re <= 0; y1_im <= 0;
            y2_re <= 0; y2_im <= 0;
            y3_re <= 0; y3_im <= 0;
            y4_re <= 0; y4_im <= 0;
        end else begin
            y1_re <= saturate_q15(y1_re_full); y1_im <= saturate_q15(y1_im_full);
            y2_re <= saturate_q15(y2_re_full); y2_im <= saturate_q15(y2_im_full);
            y3_re <= saturate_q15(y3_re_full); y3_im <= saturate_q15(y3_im_full);
            y4_re <= saturate_q15(y4_re_full); y4_im <= saturate_q15(y4_im_full);
        end
    end

endmodule
