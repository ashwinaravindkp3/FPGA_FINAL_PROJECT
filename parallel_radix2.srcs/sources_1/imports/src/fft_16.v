`timescale 1ns / 1ps

module fft_16_parallel_radix2 (
    input clk,
    input rst,
    input start,
    output done,
    
    // Provide a way to read output
    input [3:0] read_addr,
    output [15:0] read_data_re,
    output [15:0] read_data_im
);

    // Hardcoded test signal used in previous folded architectures
    wire signed [15:0] in_re_init [0:15];
    wire signed [15:0] in_im_init [0:15];
    
    assign in_re_init[0] = 16'd750; assign in_im_init[0] = 0;
    assign in_re_init[1] = 16'd731; assign in_im_init[1] = 0;
    assign in_re_init[2] = 16'd677; assign in_im_init[2] = 0;
    assign in_re_init[3] = 16'd596; assign in_im_init[3] = 0;
    assign in_re_init[4] = 16'd500; assign in_im_init[4] = 0;
    assign in_re_init[5] = 16'd404; assign in_im_init[5] = 0;
    assign in_re_init[6] = 16'd323; assign in_im_init[6] = 0;
    assign in_re_init[7] = 16'd269; assign in_im_init[7] = 0;
    assign in_re_init[8] = 16'd250; assign in_im_init[8] = 0;
    assign in_re_init[9] = 16'd269; assign in_im_init[9] = 0;
    assign in_re_init[10] = 16'd323; assign in_im_init[10] = 0;
    assign in_re_init[11] = 16'd404; assign in_im_init[11] = 0;
    assign in_re_init[12] = 16'd500; assign in_im_init[12] = 0;
    assign in_re_init[13] = 16'd596; assign in_im_init[13] = 0;
    assign in_re_init[14] = 16'd677; assign in_im_init[14] = 0;
    assign in_re_init[15] = 16'd731; assign in_im_init[15] = 0;

    // Local memory indexing implementation for DIT bit-reversal
    wire [3:0] rev [0:15];
    assign rev[0] = 0;   assign rev[1] = 8;
    assign rev[2] = 4;   assign rev[3] = 12;
    assign rev[4] = 2;   assign rev[5] = 10;
    assign rev[6] = 6;   assign rev[7] = 14;
    assign rev[8] = 1;   assign rev[9] = 9;
    assign rev[10] = 5;  assign rev[11] = 13;
    assign rev[12] = 3;  assign rev[13] = 11;
    assign rev[14] = 7;  assign rev[15] = 15;

    // Twiddle factors for 16-point Radix-2
    wire signed [15:0] w_re_ROM [0:7];
    wire signed [15:0] w_im_ROM [0:7];
    
    // Q15 formatting 
    assign w_re_ROM[0] = 16'd32767;  assign w_im_ROM[0] = 16'd0;
    assign w_re_ROM[1] = 16'd30273;  assign w_im_ROM[1] = -16'd12540;
    assign w_re_ROM[2] = 16'd23170;  assign w_im_ROM[2] = -16'd23170;
    assign w_re_ROM[3] = 16'd12540;  assign w_im_ROM[3] = -16'd30273;
    assign w_re_ROM[4] = 16'd0;      assign w_im_ROM[4] = -16'd32767;
    assign w_re_ROM[5] = -16'd12540; assign w_im_ROM[5] = -16'd30273;
    assign w_re_ROM[6] = -16'd23170; assign w_im_ROM[6] = -16'd23170;
    assign w_re_ROM[7] = -16'd30273; assign w_im_ROM[7] = -16'd12540;

    // Stage pipeline networks
    // stage_0
    wire signed [15:0] st0_re [0:15];
    wire signed [15:0] st0_im [0:15];
    
    // stage_1
    wire signed [15:0] st1_re [0:15];
    wire signed [15:0] st1_im [0:15];

    // stage_2
    wire signed [15:0] st2_re [0:15];
    wire signed [15:0] st2_im [0:15];

    // stage_3 (Final Output)
    wire signed [15:0] st3_re [0:15];
    wire signed [15:0] st3_im [0:15];

    // Input assignments (Apply bit-reversal entering Stage 0)
    // If not started, feed zeros
    wire signed [15:0] din_re [0:15];
    wire signed [15:0] din_im [0:15];
    genvar n;
    generate
        for(n=0; n<16; n=n+1) begin
            assign din_re[n] = start ? in_re_init[rev[n]] : 16'd0;
            assign din_im[n] = start ? in_im_init[rev[n]] : 16'd0;
        end
    endgenerate

    // ==========================================
    // STAGE 0: Span = 1 (groups of 2)
    // ==========================================
    genvar b0;
    generate
        for(b0=0; b0<8; b0=b0+1) begin : st0_bf
            butterfly_nodsp b (
                .clk(clk), .rst(rst),
                .a_re(din_re[b0*2]),   .a_im(din_im[b0*2]),
                .b_re(din_re[b0*2+1]), .b_im(din_im[b0*2+1]),
                .w_re(w_re_ROM[0]),    .w_im(w_im_ROM[0]),
                .y1_re(st0_re[b0*2]),  .y1_im(st0_im[b0*2]),
                .y2_re(st0_re[b0*2+1]),.y2_im(st0_im[b0*2+1])
            );
        end
    endgenerate

    // ==========================================
    // STAGE 1: Span = 2 (groups of 4)
    // ==========================================
    genvar b1;
    generate
        for(b1=0; b1<8; b1=b1+1) begin : st1_bf
            butterfly b (
                .clk(clk), .rst(rst),
                .a_re(st0_re[(b1 / 2)*4 + (b1 % 2)]), .a_im(st0_im[(b1 / 2)*4 + (b1 % 2)]),
                .b_re(st0_re[(b1 / 2)*4 + (b1 % 2) + 2]), .b_im(st0_im[(b1 / 2)*4 + (b1 % 2) + 2]),
                .w_re(w_re_ROM[(b1 % 2) * 4]), .w_im(w_im_ROM[(b1 % 2) * 4]),
                .y1_re(st1_re[(b1 / 2)*4 + (b1 % 2)]), .y1_im(st1_im[(b1 / 2)*4 + (b1 % 2)]),
                .y2_re(st1_re[(b1 / 2)*4 + (b1 % 2) + 2]), .y2_im(st1_im[(b1 / 2)*4 + (b1 % 2) + 2])
            );
        end
    endgenerate

    // ==========================================
    // STAGE 2: Span = 4 (groups of 8)
    // ==========================================
    genvar b2;
    generate
        for(b2=0; b2<8; b2=b2+1) begin : st2_bf
            butterfly b (
                .clk(clk), .rst(rst),
                .a_re(st1_re[(b2 / 4)*8 + (b2 % 4)]), .a_im(st1_im[(b2 / 4)*8 + (b2 % 4)]),
                .b_re(st1_re[(b2 / 4)*8 + (b2 % 4) + 4]), .b_im(st1_im[(b2 / 4)*8 + (b2 % 4) + 4]),
                .w_re(w_re_ROM[(b2 % 4) * 2]), .w_im(w_im_ROM[(b2 % 4) * 2]),
                .y1_re(st2_re[(b2 / 4)*8 + (b2 % 4)]), .y1_im(st2_im[(b2 / 4)*8 + (b2 % 4)]),
                .y2_re(st2_re[(b2 / 4)*8 + (b2 % 4) + 4]), .y2_im(st2_im[(b2 / 4)*8 + (b2 % 4) + 4])
            );
        end
    endgenerate

    // ==========================================
    // STAGE 3: Span = 8 (group of 16)
    // ==========================================
    genvar b3;
    generate
        for(b3=0; b3<8; b3=b3+1) begin : st3_bf
            // Node A = b3
            // Node B = b3 + 8
            // Twiddle index = b3
            butterfly b (
                .clk(clk), .rst(rst),
                .a_re(st2_re[b3]), .a_im(st2_im[b3]),
                .b_re(st2_re[b3+8]), .b_im(st2_im[b3+8]),
                .w_re(w_re_ROM[b3]), .w_im(w_im_ROM[b3]),
                .y1_re(st3_re[b3]), .y1_im(st3_im[b3]),
                .y2_re(st3_re[b3+8]), .y2_im(st3_im[b3+8])
            );
        end
    endgenerate

    // Valid Shift Register to track array latency (4 stages * 5 cycles/stage = 20 cycles)
    reg [19:0] valid_sr;
    always @(posedge clk) begin
        if (rst) begin
            valid_sr <= 0;
        end else begin
            valid_sr <= {valid_sr[18:0], start};
        end
    end
    
    // Output assignment
    assign done = valid_sr[19];
    assign read_data_re = st3_re[read_addr];
    assign read_data_im = st3_im[read_addr];

endmodule
