module fft #(
    parameter DATA_WIDTH = 32,
    parameter FFT_N      = 16,
    parameter QUANT_BITS = 14
) (
    input  logic                          clock,
    input  logic                          reset,
    // Input FIFO interface
    output logic                          in_rd_en,
    input  logic                          in_empty,
    input  logic signed [DATA_WIDTH-1:0]  in_real_dout,
    input  logic signed [DATA_WIDTH-1:0]  in_imag_dout,
    // Output FIFO interface
    output logic                          out_wr_en,
    input  logic                          out_full,
    output logic signed [DATA_WIDTH-1:0]  out_real_din,
    output logic signed [DATA_WIDTH-1:0]  out_imag_din
);

    localparam NUM_STAGES = $clog2(FFT_N);          // 4 for N=16
    localparam CNT_W      = $clog2(FFT_N) + 1;     // counter width

    localparam signed [DATA_WIDTH-1:0] TW_REAL [0:NUM_STAGES-1][0:FFT_N/2-1] = '{
        '{  32'sd16384,  32'sd0,      32'sd0,      32'sd0,       32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{  32'sd16384,  32'sd0,      32'sd0,      32'sd0,       32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{  32'sd16384,  32'sd11585,  32'sd0,     -32'sd11585,   32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{  32'sd16384,  32'sd15136,  32'sd11585,  32'sd6269,    32'sd0, -32'sd6269,   -32'sd11585,  -32'sd15136  }
    };

    localparam signed [DATA_WIDTH-1:0] TW_IMAG [0:NUM_STAGES-1][0:FFT_N/2-1] = '{
        '{  32'sd0,       32'sd0,       32'sd0,       32'sd0,      32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{  32'sd0,      -32'sd16384,   32'sd0,       32'sd0,      32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{  32'sd0,      -32'sd11585,  -32'sd16384,  -32'sd11585,  32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{  32'sd0,      -32'sd6269,   -32'sd11585,  -32'sd15136, -32'sd16384,  -32'sd15136,  -32'sd11585, -32'sd6269   }
    };

    typedef enum logic [1:0] {IDLE, LOAD, COMPUTE, OUTPUT} state_t;
    state_t state, state_c;

    logic [CNT_W-1:0] count, count_c;
    logic [CNT_W-1:0] stage_cnt, stage_cnt_c;

    logic signed [DATA_WIDTH-1:0] in_buf_real [0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] in_buf_imag [0:FFT_N-1];

    function automatic integer bit_reverse(input integer idx, input integer nbits);
        integer result, b;
        result = 0;
        for (b = 0; b < nbits; b++) begin
            if (idx & (1 << b))
                result = result | (1 << (nbits - 1 - b));
        end
        return result;
    endfunction

    logic signed [DATA_WIDTH-1:0] br_real [0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] br_imag [0:FFT_N-1];

    genvar gi;
    generate
        for (gi = 0; gi < FFT_N; gi++) begin : gen_bitrev
            localparam integer BR_IDX = bit_reverse(gi, NUM_STAGES);
            assign br_real[BR_IDX] = in_buf_real[gi];
            assign br_imag[BR_IDX] = in_buf_imag[gi];
        end
    endgenerate

    logic signed [DATA_WIDTH-1:0] stage_real [0:NUM_STAGES-1][0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] stage_imag [0:NUM_STAGES-1][0:FFT_N-1];

    genvar gs, gb;
    generate
        for (gs = 0; gs < NUM_STAGES; gs++) begin : gen_stage
            localparam integer HALF_STEP = 1 << gs;
            localparam integer STEP      = 1 << (gs + 1);

            for (gb = 0; gb < FFT_N/2; gb++) begin : gen_bfly
                localparam integer GROUP_IDX = gb / HALF_STEP;
                localparam integer J_IDX     = gb % HALF_STEP;
                localparam integer IDX1      = GROUP_IDX * STEP + J_IDX;
                localparam integer IDX2      = IDX1 + HALF_STEP;

                // Twiddle factors (compile-time constants)
                localparam signed [DATA_WIDTH-1:0] W_R = TW_REAL[gs][J_IDX];
                localparam signed [DATA_WIDTH-1:0] W_I = TW_IMAG[gs][J_IDX];

                // Source signals (from previous stage or bit-reversed input)
                logic signed [DATA_WIDTH-1:0] src1_r, src1_i, src2_r, src2_i;

                if (gs == 0) begin : src_from_br
                    assign src1_r = br_real[IDX1];
                    assign src1_i = br_imag[IDX1];
                    assign src2_r = br_real[IDX2];
                    assign src2_i = br_imag[IDX2];
                end else begin : src_from_prev
                    assign src1_r = stage_real[gs-1][IDX1];
                    assign src1_i = stage_imag[gs-1][IDX1];
                    assign src2_r = stage_real[gs-1][IDX2];
                    assign src2_i = stage_imag[gs-1][IDX2];
                end

                // Butterfly combinational outputs
                logic signed [DATA_WIDTH-1:0] bfly_y1_r, bfly_y1_i;
                logic signed [DATA_WIDTH-1:0] bfly_y2_r, bfly_y2_i;

                butterfly #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .QUANT_BITS(QUANT_BITS)
                ) bfly_inst (
                    .x1_real(src1_r),    .x1_imag(src1_i),
                    .x2_real(src2_r),    .x2_imag(src2_i),
                    .w_real(W_R),        .w_imag(W_I),
                    .y1_real(bfly_y1_r), .y1_imag(bfly_y1_i),
                    .y2_real(bfly_y2_r), .y2_imag(bfly_y2_i)
                );

                // Register butterfly outputs into the pipeline stage
                always_ff @(posedge clock) begin
                    stage_real[gs][IDX1] <= bfly_y1_r;
                    stage_imag[gs][IDX1] <= bfly_y1_i;
                    stage_real[gs][IDX2] <= bfly_y2_r;
                    stage_imag[gs][IDX2] <= bfly_y2_i;
                end

            end : gen_bfly
        end : gen_stage
    endgenerate

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            count     <= '0;
            stage_cnt <= '0;
        end else begin
            state     <= state_c;
            count     <= count_c;
            stage_cnt <= stage_cnt_c;
        end
    end

    // Input buffer capture
    always_ff @(posedge clock) begin
        if (state == LOAD && in_empty == 1'b0) begin
            in_buf_real[count] <= in_real_dout;
            in_buf_imag[count] <= in_imag_dout;
        end
    end

    always_comb begin
        // Defaults
        state_c     = state;
        count_c     = count;
        stage_cnt_c = stage_cnt;
        in_rd_en    = 1'b0;
        out_wr_en   = 1'b0;
        out_real_din = '0;
        out_imag_din = '0;

        case (state)

            IDLE: begin
                count_c     = '0;
                stage_cnt_c = '0;
                if (in_empty == 1'b0) begin
                    state_c = LOAD;
                end
            end

            LOAD: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;
                    if (count == CNT_W'(FFT_N - 1)) begin
                        state_c     = COMPUTE;
                        count_c     = '0;
                        stage_cnt_c = '0;
                    end else begin
                        count_c = count + 1;
                    end
                end
            end

            COMPUTE: begin
                stage_cnt_c = stage_cnt + 1;
                if (stage_cnt == CNT_W'(NUM_STAGES)) begin
                    state_c = OUTPUT;
                    count_c = '0;
                end
            end

            OUTPUT: begin
                if (out_full == 1'b0) begin
                    out_wr_en    = 1'b1;
                    out_real_din = stage_real[NUM_STAGES-1][count];
                    out_imag_din = stage_imag[NUM_STAGES-1][count];
                    if (count == CNT_W'(FFT_N - 1)) begin
                        state_c = IDLE;
                        count_c = '0;
                    end else begin
                        count_c = count + 1;
                    end
                end
            end

            default: begin
                state_c     = IDLE;
                count_c     = '0;
                stage_cnt_c = '0;
            end
        endcase
    end

endmodule
