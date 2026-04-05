`timescale 1ns / 1ps

module fft_16 (
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
    
    // Assign read data
    assign read_data_re = data_re[read_addr];
    assign read_data_im = data_im[read_addr];
    
    // Twiddle factors for 16-point Radix-2
    wire signed [15:0] w_re_ROM [0:7];
    wire signed [15:0] w_im_ROM [0:7];
    
    // Q15 formatting 
    assign w_re_ROM[0] = 16'd32767; assign w_im_ROM[0] = 16'd0;
    assign w_re_ROM[1] = 16'd30273; assign w_im_ROM[1] = -16'd12540;
    assign w_re_ROM[2] = 16'd23170; assign w_im_ROM[2] = -16'd23170;
    assign w_re_ROM[3] = 16'd12540; assign w_im_ROM[3] = -16'd30273;
    assign w_re_ROM[4] = 16'd0;     assign w_im_ROM[4] = -16'd32767;
    assign w_re_ROM[5] = -16'd12540;assign w_im_ROM[5] = -16'd30273;
    assign w_re_ROM[6] = -16'd23170;assign w_im_ROM[6] = -16'd23170;
    assign w_re_ROM[7] = -16'd30273;assign w_im_ROM[7] = -16'd12540;

    reg [2:0] stage;
    reg [2:0] state;
    reg [2:0] wait_count;
    
    localparam IDLE = 0, BIT_REVERSE = 1, WAIT_STAGE = 2, WRITE_STAGE = 3, DONE = 4;
    
    // Instantiate 8 butterflies in parallel, creating a stage-folded Radix architecture
    // This design naturally boosts DSP slices close to ~90% of Basys3
    reg signed [15:0] bf_a_re[0:7];
    reg signed [15:0] bf_a_im[0:7];
    reg signed [15:0] bf_b_re[0:7];
    reg signed [15:0] bf_b_im[0:7];
    reg signed [15:0] bf_w_re[0:7];
    reg signed [15:0] bf_w_im[0:7];
    
    wire signed [15:0] bf_y1_re[0:7];
    wire signed [15:0] bf_y1_im[0:7];
    wire signed [15:0] bf_y2_re[0:7];
    wire signed [15:0] bf_y2_im[0:7];
    
    genvar i;
    generate
        for(i=0; i<8; i=i+1) begin : bf_gen
            butterfly b(
                .clk(clk),
                .rst(rst),
                .a_re(bf_a_re[i]),
                .a_im(bf_a_im[i]),
                .b_re(bf_b_re[i]),
                .b_im(bf_b_im[i]),
                .w_re(bf_w_re[i]),
                .w_im(bf_w_im[i]),
                .y1_re(bf_y1_re[i]),
                .y1_im(bf_y1_im[i]),
                .y2_re(bf_y2_re[i]),
                .y2_im(bf_y2_im[i])
            );
        end
    endgenerate

    // Multiplexer logic to map folding to parallel array
    integer b;
    always @(*) begin
        for(b=0; b<8; b=b+1) begin
            case(stage)
                0: begin // Sub-groups of 2
                    bf_a_re[b] = data_re[b*2];
                    bf_a_im[b] = data_im[b*2];
                    bf_b_re[b] = data_re[b*2+1];
                    bf_b_im[b] = data_im[b*2+1];
                    bf_w_re[b] = w_re_ROM[0];
                    bf_w_im[b] = w_im_ROM[0];
                end
                1: begin // Sub-groups of 4
                    bf_a_re[b] = data_re[(b/2)*4 + (b%2)];
                    bf_a_im[b] = data_im[(b/2)*4 + (b%2)];
                    bf_b_re[b] = data_re[(b/2)*4 + (b%2) + 2];
                    bf_b_im[b] = data_im[(b/2)*4 + (b%2) + 2];
                    bf_w_re[b] = w_re_ROM[(b%2)*4];
                    bf_w_im[b] = w_im_ROM[(b%2)*4];
                end
                2: begin // Sub-groups of 8
                    bf_a_re[b] = data_re[(b/4)*8 + (b%4)];
                    bf_a_im[b] = data_im[(b/4)*8 + (b%4)];
                    bf_b_re[b] = data_re[(b/4)*8 + (b%4) + 4];
                    bf_b_im[b] = data_im[(b/4)*8 + (b%4) + 4];
                    bf_w_re[b] = w_re_ROM[(b%4)*2];
                    bf_w_im[b] = w_im_ROM[(b%4)*2];
                end
                3: begin // Singular massive sub-group!
                    bf_a_re[b] = data_re[b];
                    bf_a_im[b] = data_im[b];
                    bf_b_re[b] = data_re[b+8];
                    bf_b_im[b] = data_im[b+8];
                    bf_w_re[b] = w_re_ROM[b];
                    bf_w_im[b] = w_im_ROM[b];
                end
                default: begin
                    bf_a_re[b] = 0; bf_a_im[b] = 0;
                    bf_b_re[b] = 0; bf_b_im[b] = 0;
                    bf_w_re[b] = 0; bf_w_im[b] = 0;
                end
            endcase
        end
    end

    integer j;
    // Local memory indexing implementation to avoid high LUTs.
    wire [3:0] rev [0:15];
    assign rev[0] = 0;   assign rev[1] = 8;
    assign rev[2] = 4;   assign rev[3] = 12;
    assign rev[4] = 2;   assign rev[5] = 10;
    assign rev[6] = 6;   assign rev[7] = 14;
    assign rev[8] = 1;   assign rev[9] = 9;
    assign rev[10] = 5;  assign rev[11] = 13;
    assign rev[12] = 3;  assign rev[13] = 11;
    assign rev[14] = 7;  assign rev[15] = 15;

    // A sample test signal to process and visualize on 7 seg.
    // Base signal shape: DC bias (500) + Cosine signal 
    // It creates nice sequence peaks: Mag of Bin[0] = 8000, Mag of Bin[1]/[15] = 2000
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
                        state <= BIT_REVERSE;
                    end
                end
                BIT_REVERSE: begin
                    for(j=0; j<16; j=j+1) begin
                        data_re[j] <= in_re_init[rev[j]];
                        data_im[j] <= in_im_init[rev[j]];
                    end
                    stage <= 0;
                    wait_count <= 0;
                    state <= WAIT_STAGE;
                end
                WAIT_STAGE: begin
                    // Wait butterfly's 4-cycle latency pipeline
                    if (wait_count == 3) begin
                        state <= WRITE_STAGE;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1;
                    end
                end
                WRITE_STAGE: begin
                    for(j=0; j<8; j=j+1) begin
                        if(stage == 0) begin
                            data_re[j*2]   <= bf_y1_re[j];
                            data_im[j*2]   <= bf_y1_im[j];
                            data_re[j*2+1] <= bf_y2_re[j];
                            data_im[j*2+1] <= bf_y2_im[j];
                        end
                        else if(stage == 1) begin
                            data_re[(j/2)*4 + (j%2)]     <= bf_y1_re[j];
                            data_im[(j/2)*4 + (j%2)]     <= bf_y1_im[j];
                            data_re[(j/2)*4 + (j%2) + 2] <= bf_y2_re[j];
                            data_im[(j/2)*4 + (j%2) + 2] <= bf_y2_im[j];
                        end
                        else if(stage == 2) begin
                            data_re[(j/4)*8 + (j%4)]     <= bf_y1_re[j];
                            data_im[(j/4)*8 + (j%4)]     <= bf_y1_im[j];
                            data_re[(j/4)*8 + (j%4) + 4] <= bf_y2_re[j];
                            data_im[(j/4)*8 + (j%4) + 4] <= bf_y2_im[j];
                        end
                        else if(stage == 3) begin
                            data_re[j]     <= bf_y1_re[j];
                            data_im[j]     <= bf_y1_im[j];
                            data_re[j+8] <= bf_y2_re[j];
                            data_im[j+8] <= bf_y2_im[j];
                        end
                    end
                    
                    if (stage == 3) begin
                        state <= DONE;
                        done <= 1;
                    end else begin
                        stage <= stage + 1;
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
