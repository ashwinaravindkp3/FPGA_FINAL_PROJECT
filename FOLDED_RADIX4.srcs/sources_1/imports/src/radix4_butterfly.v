`timescale 1ns / 1ps

module radix4_butterfly (
    input clk,
    input signed [15:0] a_re,
    input signed [15:0] a_im,
    input signed [15:0] b_re,
    input signed [15:0] b_im,
    input signed [15:0] c_re,
    input signed [15:0] c_im,
    input signed [15:0] d_re,
    input signed [15:0] d_im,
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

    // Stage 0: Register inputs
    reg signed [15:0] a_re_r, a_im_r;
    reg signed [15:0] b_re_r, b_im_r;
    reg signed [15:0] c_re_r, c_im_r;
    reg signed [15:0] d_re_r, d_im_r;
    reg signed [15:0] w1_re_r, w1_im_r;
    reg signed [15:0] w2_re_r, w2_im_r;
    reg signed [15:0] w3_re_r, w3_im_r;

    always @(posedge clk) begin
        if (rst) begin
            a_re_r <= 0; a_im_r <= 0; b_re_r <= 0; b_im_r <= 0;
            c_re_r <= 0; c_im_r <= 0; d_re_r <= 0; d_im_r <= 0;
            w1_re_r <= 0; w1_im_r <= 0; w2_re_r <= 0; w2_im_r <= 0; w3_re_r <= 0; w3_im_r <= 0;
        end else begin
            a_re_r <= a_re; a_im_r <= a_im;
            b_re_r <= b_re; b_im_r <= b_im;
            c_re_r <= c_re; c_im_r <= c_im;
            d_re_r <= d_re; d_im_r <= d_im;
            w1_re_r <= w1_re; w1_im_r <= w1_im;
            w2_re_r <= w2_re; w2_im_r <= w2_im;
            w3_re_r <= w3_re; w3_im_r <= w3_im;
        end
    end

    // Stage 1: Multiplication (DSP M-register)
    (* use_dsp = "yes" *) reg signed [31:0] p_b1, p_b2, p_b3, p_b4;
    (* use_dsp = "yes" *) reg signed [31:0] p_c1, p_c2, p_c3, p_c4;
    (* use_dsp = "yes" *) reg signed [31:0] p_d1, p_d2, p_d3, p_d4;

    always @(posedge clk) begin
        if (rst) begin
            p_b1 <= 0; p_b2 <= 0; p_b3 <= 0; p_b4 <= 0;
            p_c1 <= 0; p_c2 <= 0; p_c3 <= 0; p_c4 <= 0;
            p_d1 <= 0; p_d2 <= 0; p_d3 <= 0; p_d4 <= 0;
        end else begin
            p_b1 <= b_re_r * w1_re_r;
            p_b2 <= b_im_r * w1_im_r;
            p_b3 <= b_re_r * w1_im_r;
            p_b4 <= b_im_r * w1_re_r;

            p_c1 <= c_re_r * w2_re_r;
            p_c2 <= c_im_r * w2_im_r;
            p_c3 <= c_re_r * w2_im_r;
            p_c4 <= c_im_r * w2_re_r;

            p_d1 <= d_re_r * w3_re_r;
            p_d2 <= d_im_r * w3_im_r;
            p_d3 <= d_re_r * w3_im_r;
            p_d4 <= d_im_r * w3_re_r;
        end
    end

    // Stage 2: Subtraction/Addition for complex multiply (DSP P-register)
    (* use_dsp = "yes" *) reg signed [31:0] bw1_re_full, bw1_im_full;
    (* use_dsp = "yes" *) reg signed [31:0] bw2_re_full, bw2_im_full;
    (* use_dsp = "yes" *) reg signed [31:0] bw3_re_full, bw3_im_full;

    always @(posedge clk) begin
        if (rst) begin
            bw1_re_full <= 0; bw1_im_full <= 0;
            bw2_re_full <= 0; bw2_im_full <= 0;
            bw3_re_full <= 0; bw3_im_full <= 0;
        end else begin
            bw1_re_full <= p_b1 - p_b2;
            bw1_im_full <= p_b3 + p_b4;
            bw2_re_full <= p_c1 - p_c2;
            bw2_im_full <= p_c3 + p_c4;
            bw3_re_full <= p_d1 - p_d2;
            bw3_im_full <= p_d3 + p_d4;
        end
    end

    // Delay lines for 'a' to match latency
    reg signed [15:0] a_re_d1, a_im_d1;
    reg signed [15:0] a_re_d2, a_im_d2;
    always @(posedge clk) begin
        if (rst) begin
            a_re_d1 <= 0; a_im_d1 <= 0;
            a_re_d2 <= 0; a_im_d2 <= 0;
        end else begin
            a_re_d1 <= a_re_r;  a_im_d1 <= a_im_r;
            a_re_d2 <= a_re_d1; a_im_d2 <= a_im_d1;
        end
    end

    // Saturation logic macro for Q15 shifted outputs
    function signed [15:0] saturate_q15;
        input signed [31:0] val;
        begin
            if (val[31:15] > 32'h0000_0000) begin
                // Positive overflow limit
                saturate_q15 = 16'h7FFF;
            end else if (val[31:15] < 32'hFFFF_FFFF) begin
                // Negative overflow limit
                saturate_q15 = 16'h8000;
            end else begin
                saturate_q15 = val[30:15];
            end
        end
    endfunction

    wire signed [15:0] X2_re = saturate_q15(bw1_re_full);
    wire signed [15:0] X2_im = saturate_q15(bw1_im_full);
    wire signed [15:0] X3_re = saturate_q15(bw2_re_full);
    wire signed [15:0] X3_im = saturate_q15(bw2_im_full);
    wire signed [15:0] X4_re = saturate_q15(bw3_re_full);
    wire signed [15:0] X4_im = saturate_q15(bw3_im_full);
    wire signed [15:0] X1_re = a_re_d2;
    wire signed [15:0] X1_im = a_im_d2;

    // Stage 3: First set of Additions (E1, E2, E3, E4)
    (* use_dsp = "yes" *) reg signed [15:0] E1_re, E1_im;
    (* use_dsp = "yes" *) reg signed [15:0] E2_re, E2_im;
    (* use_dsp = "yes" *) reg signed [15:0] E3_re, E3_im;
    (* use_dsp = "yes" *) reg signed [15:0] E4_re, E4_im;

    always @(posedge clk) begin
        if (rst) begin
            E1_re <= 0; E1_im <= 0;
            E2_re <= 0; E2_im <= 0;
            E3_re <= 0; E3_im <= 0;
            E4_re <= 0; E4_im <= 0;
        end else begin
            E1_re <= X1_re + X3_re;
            E1_im <= X1_im + X3_im;
            
            E2_re <= X1_re - X3_re;
            E2_im <= X1_im - X3_im;

            E3_re <= X2_re + X4_re;
            E3_im <= X2_im + X4_im;
            
            E4_re <= X2_re - X4_re;
            E4_im <= X2_im - X4_im;
        end
    end

    // Stage 4: Second set of Additions (Combines)
    (* use_dsp = "yes" *) reg signed [15:0] A_prime_re, A_prime_im;
    (* use_dsp = "yes" *) reg signed [15:0] B_prime_re, B_prime_im;
    (* use_dsp = "yes" *) reg signed [15:0] C_prime_re, C_prime_im;
    (* use_dsp = "yes" *) reg signed [15:0] D_prime_re, D_prime_im;

    always @(posedge clk) begin
        if (rst) begin
            A_prime_re <= 0; A_prime_im <= 0;
            B_prime_re <= 0; B_prime_im <= 0;
            C_prime_re <= 0; C_prime_im <= 0;
            D_prime_re <= 0; D_prime_im <= 0;
        end else begin
            A_prime_re <= E1_re + E3_re;
            A_prime_im <= E1_im + E3_im;
            
            C_prime_re <= E1_re - E3_re;
            C_prime_im <= E1_im - E3_im;
            
            // B' = E2 - j*E4 = (E2_re + E4_im) + j(E2_im - E4_re)
            B_prime_re <= E2_re + E4_im;
            B_prime_im <= E2_im - E4_re;
            
            // D' = E2 + j*E4 = (E2_re - E4_im) + j(E2_im + E4_re)
            D_prime_re <= E2_re - E4_im;
            D_prime_im <= E2_im + E4_re;
        end
    end

    // Stage 5: Final output registers
    always @(posedge clk) begin
        if (rst) begin
            y1_re <= 0; y1_im <= 0;
            y2_re <= 0; y2_im <= 0;
            y3_re <= 0; y3_im <= 0;
            y4_re <= 0; y4_im <= 0;
        end else begin
            y1_re <= A_prime_re;
            y1_im <= A_prime_im;
            y2_re <= B_prime_re;
            y2_im <= B_prime_im;
            y3_re <= C_prime_re;
            y3_im <= C_prime_im;
            y4_re <= D_prime_re;
            y4_im <= D_prime_im;
        end
    end

endmodule
