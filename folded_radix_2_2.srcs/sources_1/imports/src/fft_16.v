`timescale 1ns / 1ps

module fft_16_radix2_2 (
    input clk,
    input rst,
    input start,
    output reg done,
    // Provide a way to read output
    input [3:0] read_addr,
    output [15:0] read_data_re,
    output [15:0] read_data_im
);

    reg signed [15:0] data_re [0:15];
    reg signed [15:0] data_im [0:15];
    
    // Base-4 digit reversal for 16 points (for reading out in correct order)
    wire [3:0] rev [0:15];
    assign rev[0] = 0;   assign rev[1] = 4;
    assign rev[2] = 8;   assign rev[3] = 12;
    assign rev[4] = 1;   assign rev[5] = 5;
    assign rev[6] = 9;   assign rev[7] = 13;
    assign rev[8] = 2;   assign rev[9] = 6;
    assign rev[10] = 10; assign rev[11] = 14;
    assign rev[12] = 3;  assign rev[13] = 7;
    assign rev[14] = 11; assign rev[15] = 15;

    // Assign read data (DIF outputs are in digit-reversed order)
    assign read_data_re = data_re[rev[read_addr]];
    assign read_data_im = data_im[rev[read_addr]];
    
    // Twiddle factors for 16-point FFT
    wire signed [15:0] w_re_ROM [0:9];
    wire signed [15:0] w_im_ROM [0:9];
    
    // Q15 formatting 
    assign w_re_ROM[0] = 16'd32767;  assign w_im_ROM[0] = 16'd0;
    assign w_re_ROM[1] = 16'd30273;  assign w_im_ROM[1] = -16'd12540;
    assign w_re_ROM[2] = 16'd23170;  assign w_im_ROM[2] = -16'd23170;
    assign w_re_ROM[3] = 16'd12540;  assign w_im_ROM[3] = -16'd30273;
    assign w_re_ROM[4] = 16'd0;      assign w_im_ROM[4] = -16'd32767;
    assign w_re_ROM[5] = -16'd12540; assign w_im_ROM[5] = -16'd30273;
    assign w_re_ROM[6] = -16'd23170; assign w_im_ROM[6] = -16'd23170;
    assign w_re_ROM[7] = -16'd30273; assign w_im_ROM[7] = -16'd12540;
    assign w_re_ROM[8] = -16'd32767; assign w_im_ROM[8] = 16'd0;
    assign w_re_ROM[9] = -16'd30273; assign w_im_ROM[9] = 16'd12540;

    reg stage; // 2 stages: 0 and 1
    reg [2:0] state;
    reg [2:0] wait_count;
    
    localparam IDLE = 0, LOAD = 1, WAIT_STAGE = 2, WRITE_STAGE = 3, DONE = 4;
    
    // Instantiate 4 butterflies in parallel for radix-2^2 folded architecture
    reg signed [15:0] bf_a_re[0:3], bf_a_im[0:3];
    reg signed [15:0] bf_b_re[0:3], bf_b_im[0:3];
    reg signed [15:0] bf_c_re[0:3], bf_c_im[0:3];
    reg signed [15:0] bf_d_re[0:3], bf_d_im[0:3];
    
    reg signed [15:0] bf_w0_re[0:3], bf_w0_im[0:3];
    reg signed [15:0] bf_w1_re[0:3], bf_w1_im[0:3];
    reg signed [15:0] bf_w2_re[0:3], bf_w2_im[0:3];
    reg signed [15:0] bf_w3_re[0:3], bf_w3_im[0:3];
    
    wire signed [15:0] bf_y1_re[0:3], bf_y1_im[0:3];
    wire signed [15:0] bf_y2_re[0:3], bf_y2_im[0:3];
    wire signed [15:0] bf_y3_re[0:3], bf_y3_im[0:3];
    wire signed [15:0] bf_y4_re[0:3], bf_y4_im[0:3];
    
    genvar i;
    generate
        for(i=0; i<4; i=i+1) begin : bf_gen
            radix2_2_butterfly b(
                .clk(clk),
                .rst(rst),
                .a_re(bf_a_re[i]), .a_im(bf_a_im[i]),
                .b_re(bf_b_re[i]), .b_im(bf_b_im[i]),
                .c_re(bf_c_re[i]), .c_im(bf_c_im[i]),
                .d_re(bf_d_re[i]), .d_im(bf_d_im[i]),
                .w0_re(bf_w0_re[i]), .w0_im(bf_w0_im[i]),
                .w1_re(bf_w1_re[i]), .w1_im(bf_w1_im[i]),
                .w2_re(bf_w2_re[i]), .w2_im(bf_w2_im[i]),
                .w3_re(bf_w3_re[i]), .w3_im(bf_w3_im[i]),
                .y1_re(bf_y1_re[i]), .y1_im(bf_y1_im[i]),
                .y2_re(bf_y2_re[i]), .y2_im(bf_y2_im[i]),
                .y3_re(bf_y3_re[i]), .y3_im(bf_y3_im[i]),
                .y4_re(bf_y4_re[i]), .y4_im(bf_y4_im[i])
            );
        end
    endgenerate

    // Multiplexer logic to map folding to parallel array
    integer b;
    always @(*) begin
        for(b=0; b<4; b=b+1) begin
            if(stage == 0) begin 
                // Stage 0 DIF: Group of 16, spacing 4
                bf_a_re[b] = data_re[b];
                bf_a_im[b] = data_im[b];
                bf_b_re[b] = data_re[b+4];
                bf_b_im[b] = data_im[b+4];
                bf_c_re[b] = data_re[b+8];
                bf_c_im[b] = data_im[b+8];
                bf_d_re[b] = data_re[b+12];
                bf_d_im[b] = data_im[b+12];
                
                // Twiddles: W^0, W^b, W^2b, W^3b
                bf_w0_re[b] = w_re_ROM[0];
                bf_w0_im[b] = w_im_ROM[0];
                bf_w1_re[b] = w_re_ROM[b];
                bf_w1_im[b] = w_im_ROM[b];
                bf_w2_re[b] = w_re_ROM[2*b];
                bf_w2_im[b] = w_im_ROM[2*b];
                bf_w3_re[b] = w_re_ROM[3*b];
                bf_w3_im[b] = w_im_ROM[3*b];
            end else begin 
                // Stage 1 DIF: Groups of 4, spacing 1
                bf_a_re[b] = data_re[b*4];
                bf_a_im[b] = data_im[b*4];
                bf_b_re[b] = data_re[b*4+1];
                bf_b_im[b] = data_im[b*4+1];
                bf_c_re[b] = data_re[b*4+2];
                bf_c_im[b] = data_im[b*4+2];
                bf_d_re[b] = data_re[b*4+3];
                bf_d_im[b] = data_im[b*4+3];
                
                // Twiddles are W^0 for all in stage 1
                bf_w0_re[b] = w_re_ROM[0]; bf_w0_im[b] = w_im_ROM[0];
                bf_w1_re[b] = w_re_ROM[0]; bf_w1_im[b] = w_im_ROM[0];
                bf_w2_re[b] = w_re_ROM[0]; bf_w2_im[b] = w_im_ROM[0];
                bf_w3_re[b] = w_re_ROM[0]; bf_w3_im[b] = w_im_ROM[0];
            end
        end
    end

    // Same sample test signal
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

    integer j;

    // FSM Memory Control
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            stage <= 0;
            wait_count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    // DIF starts with normal ordering
                    for(j=0; j<16; j=j+1) begin
                        data_re[j] <= in_re_init[j];
                        data_im[j] <= in_im_init[j];
                    end
                    stage <= 0;
                    wait_count <= 0;
                    state <= WAIT_STAGE;
                end
                WAIT_STAGE: begin
                    // Radix-2^2 butterfly latency is 6 cycles
                    if (wait_count == 5) begin
                        state <= WRITE_STAGE;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1;
                    end
                end
                WRITE_STAGE: begin
                    for(j=0; j<4; j=j+1) begin
                        if(stage == 0) begin
                            data_re[j]    <= bf_y1_re[j];
                            data_im[j]    <= bf_y1_im[j];
                            data_re[j+4]  <= bf_y2_re[j];
                            data_im[j+4]  <= bf_y2_im[j];
                            data_re[j+8]  <= bf_y3_re[j];
                            data_im[j+8]  <= bf_y3_im[j];
                            data_re[j+12] <= bf_y4_re[j];
                            data_im[j+12] <= bf_y4_im[j];
                        end
                        else if(stage == 1) begin
                            data_re[j*4]   <= bf_y1_re[j];
                            data_im[j*4]   <= bf_y1_im[j];
                            data_re[j*4+1] <= bf_y2_re[j];
                            data_im[j*4+1] <= bf_y2_im[j];
                            data_re[j*4+2] <= bf_y3_re[j];
                            data_im[j*4+2] <= bf_y3_im[j];
                            data_re[j*4+3] <= bf_y4_re[j];
                            data_im[j*4+3] <= bf_y4_im[j];
                        end
                    end
                    
                    if (stage == 1) begin
                        state <= DONE;
                        done <= 1;
                    end else begin
                        stage <= 1;
                        wait_count <= 0;
                        state <= WAIT_STAGE;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
