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

    // ----------------------------------------------------------------
    // Local parameters
    // ----------------------------------------------------------------
    localparam NUM_STAGES = $clog2(FFT_N);          // 4 for N=16
    localparam CNT_W      = $clog2(FFT_N) + 1;     // counter width

    // ----------------------------------------------------------------
    // Twiddle factor ROM (precomputed, quantized)
    //
    // For stage s, butterfly index j within a group:
    //   angle = -PI * j / (step/2)   where step = 2^(s+1)
    //   tw_real = quantize(cos(angle)) = (int)(cos(angle) * 2^QUANT_BITS)
    //   tw_imag = quantize(sin(angle))
    //
    // N = 16 twiddle table (QUANT_BITS = 14, QUANT_VAL = 16384):
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // FSM (2-process: sequential + combinational)
    // ----------------------------------------------------------------
    typedef enum logic [1:0] {IDLE, LOAD, COMPUTE, OUTPUT} state_t;
    state_t state, state_c;

    logic [CNT_W-1:0] count, count_c;
    logic [CNT_W-1:0] stage_cnt, stage_cnt_c;

    // ----------------------------------------------------------------
    // Input sample buffer
    // ----------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] in_buf_real [0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] in_buf_imag [0:FFT_N-1];

    // ----------------------------------------------------------------
    // Bit-reversed output (combinational, feeds pipeline stage 0)
    // ----------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] br_real [0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] br_imag [0:FFT_N-1];

    bit_reversal #(
        .DATA_WIDTH(DATA_WIDTH),
        .FFT_N(FFT_N)
    ) bit_rev_inst (
        .in_real(in_buf_real),
        .in_imag(in_buf_imag),
        .out_real(br_real),
        .out_imag(br_imag)
    );

    // ----------------------------------------------------------------
    // Pipeline stage registers
    //   stage_real[s][k], stage_imag[s][k]
    //   s = 0..NUM_STAGES-1 (registered output of each butterfly stage)
    // ----------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] stage_real [0:NUM_STAGES-1][0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] stage_imag [0:NUM_STAGES-1][0:FFT_N-1];

    // ----------------------------------------------------------------
    // Generate butterfly pipeline stages
    //   Each stage: N/2 butterfly units computing in parallel
    //   Stage s reads from stage_real[s-1] (or br_real for s==0)
    //   Stage s writes to stage_real[s] (registered)
    // ----------------------------------------------------------------
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
                    .x1_real(src1_r),  .x1_imag(src1_i),
                    .x2_real(src2_r),  .x2_imag(src2_i),
                    .w_real(W_R),      .w_imag(W_I),
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

    // ----------------------------------------------------------------
    // Sequential process (state register + input buffer)
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Combinational process (next-state + output logic)
    // ----------------------------------------------------------------
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
            // -------------------------------------------
            IDLE: begin
                count_c     = '0;
                stage_cnt_c = '0;
                if (in_empty == 1'b0) begin
                    state_c = LOAD;
                end
            end

            // -------------------------------------------
            // Load N samples from input FIFOs
            // -------------------------------------------
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

            // -------------------------------------------
            // Wait for pipeline stages to propagate
            // Need NUM_STAGES clock edges for data to
            // flow through all butterfly pipeline stages.
            // -------------------------------------------
            COMPUTE: begin
                stage_cnt_c = stage_cnt + 1;
                if (stage_cnt == CNT_W'(NUM_STAGES)) begin
                    state_c = OUTPUT;
                    count_c = '0;
                end
            end

            // -------------------------------------------
            // Output N results to output FIFOs
            // (1 sample per clock cycle)
            // -------------------------------------------
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

            // -------------------------------------------
            default: begin
                state_c     = IDLE;
                count_c     = '0;
                stage_cnt_c = '0;
            end
        endcase
    end

endmodule
