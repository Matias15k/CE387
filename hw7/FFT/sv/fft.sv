
module fft #(
    parameter DATA_WIDTH  = 32,
    parameter FFT_N       = 16,
    parameter QUANT_BITS  = 14
) (
    input  logic                          clock,
    input  logic                          reset,
    // Input FIFO interface (both real and imag read together)
    output logic                          in_rd_en,
    input  logic                          in_empty,
    input  logic signed [DATA_WIDTH-1:0]  in_real_dout,
    input  logic signed [DATA_WIDTH-1:0]  in_imag_dout,
    // Output FIFO interface (both real and imag written together)
    output logic                          out_wr_en,
    input  logic                          out_full,
    output logic signed [DATA_WIDTH-1:0]  out_real_din,
    output logic signed [DATA_WIDTH-1:0]  out_imag_din
);

    // -----------------------------------------------------------
    // Local parameters
    // -----------------------------------------------------------
    localparam NUM_STAGES = $clog2(FFT_N);  // 4 for N=16
    localparam QUANT_VAL  = 1 << QUANT_BITS;
    localparam HALF_QUANT = QUANT_VAL / 2;
    localparam CNT_W      = $clog2(FFT_N) + 1; // counter width

    // -----------------------------------------------------------
    // Bit-reversal lookup (computed at elaboration)
    // -----------------------------------------------------------
    function automatic integer bit_reverse(input integer idx, input integer nbits);
        integer result, b;
        result = 0;
        for (b = 0; b < nbits; b++) begin
            if (idx & (1 << b))
                result = result | (1 << (nbits - 1 - b));
        end
        return result;
    endfunction

    // -----------------------------------------------------------
    // Twiddle factor ROM  (N = 16, NUM_STAGES = 4)
    // tw_real[stage][j], tw_imag[stage][j]
    // angle = -PI * j / (step/2)  where step = 2^(stage+1)
    // Quantized: (int)(cos(angle) * QUANT_VAL)
    // -----------------------------------------------------------
    localparam signed [DATA_WIDTH-1:0] TW_REAL [0:NUM_STAGES-1][0:FFT_N/2-1] = '{
        '{ 32'sd16384,  32'sd0,      32'sd0,       32'sd0,      32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{ 32'sd16384,  32'sd0,      32'sd0,       32'sd0,      32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{ 32'sd16384,  32'sd11585,  32'sd0,      -32'sd11585,  32'sd0,  32'sd0,       32'sd0,       32'sd0      },
        '{ 32'sd16384,  32'sd15136,  32'sd11585,   32'sd6269,   32'sd0, -32'sd6269,   -32'sd11585,  -32'sd15136  }
    };

    localparam signed [DATA_WIDTH-1:0] TW_IMAG [0:NUM_STAGES-1][0:FFT_N/2-1] = '{
        '{ 32'sd0,       32'sd0,       32'sd0,       32'sd0,      32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{ 32'sd0,      -32'sd16384,   32'sd0,       32'sd0,      32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{ 32'sd0,      -32'sd11585,  -32'sd16384,  -32'sd11585,  32'sd0,       32'sd0,       32'sd0,      32'sd0      },
        '{ 32'sd0,      -32'sd6269,   -32'sd11585,  -32'sd15136, -32'sd16384,  -32'sd15136,  -32'sd11585, -32'sd6269   }
    };

    // -----------------------------------------------------------
    // Dequantized multiply: (a * b + HALF_QUANT) / QUANT_VAL
    // Uses signed division (truncates toward zero, matching C)
    // -----------------------------------------------------------
    function automatic signed [DATA_WIDTH-1:0] dequant_mult(
        input signed [DATA_WIDTH-1:0] a,
        input signed [DATA_WIDTH-1:0] b
    );
        logic signed [2*DATA_WIDTH-1:0] product;
        logic signed [2*DATA_WIDTH-1:0] rounded;
        product = $signed(a) * $signed(b);
        rounded = $signed(product) + $signed(64'(HALF_QUANT));
        return DATA_WIDTH'($signed(rounded) / $signed(64'(QUANT_VAL)));
    endfunction

    // -----------------------------------------------------------
    // FSM  (2-process style)
    // -----------------------------------------------------------
    typedef enum logic [1:0] {IDLE, LOAD, COMPUTE, OUTPUT} state_t;
    state_t state, state_c;

    logic [CNT_W-1:0] count, count_c;
    logic [CNT_W-1:0] stage_cnt, stage_cnt_c;

    // Input sample buffer
    logic signed [DATA_WIDTH-1:0] in_buf_real [0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] in_buf_imag [0:FFT_N-1];

    // -----------------------------------------------------------
    // Pipeline stage data
    //   pipe_real/imag[s][k] = registered output of stage s
    //   For s = 0 .. NUM_STAGES-1
    // Source for stage 0 = bit-reversed input buffer (combinational)
    // Source for stage s>0 = pipe[s-1] (registered)
    // -----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] pipe_real [0:NUM_STAGES-1][0:FFT_N-1];
    logic signed [DATA_WIDTH-1:0] pipe_imag [0:NUM_STAGES-1][0:FFT_N-1];

    // Combinational bit-reversed source for stage 0
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

    // -----------------------------------------------------------
    // Generate butterfly pipeline stages
    // -----------------------------------------------------------
    genvar gs, gb;
    generate
        for (gs = 0; gs < NUM_STAGES; gs++) begin : gen_stage
            localparam integer HALF_STEP = 1 << gs;
            localparam integer STEP      = 1 << (gs + 1);

            // Each stage has FFT_N/2 butterfly units
            for (gb = 0; gb < FFT_N/2; gb++) begin : gen_bfly
                localparam integer GROUP_NUM = gb / HALF_STEP;
                localparam integer J_IDX     = gb % HALF_STEP;
                localparam integer IDX1      = GROUP_NUM * STEP + J_IDX;
                localparam integer IDX2      = IDX1 + HALF_STEP;

                // Twiddle factor for this butterfly
                localparam signed [DATA_WIDTH-1:0] W_REAL = TW_REAL[gs][J_IDX];
                localparam signed [DATA_WIDTH-1:0] W_IMAG = TW_IMAG[gs][J_IDX];

                // Source data (combinational mux)
                logic signed [DATA_WIDTH-1:0] src1_r, src1_i, src2_r, src2_i;

                if (gs == 0) begin : src_stage0
                    assign src1_r = br_real[IDX1];
                    assign src1_i = br_imag[IDX1];
                    assign src2_r = br_real[IDX2];
                    assign src2_i = br_imag[IDX2];
                end else begin : src_stagex
                    assign src1_r = pipe_real[gs-1][IDX1];
                    assign src1_i = pipe_imag[gs-1][IDX1];
                    assign src2_r = pipe_real[gs-1][IDX2];
                    assign src2_i = pipe_imag[gs-1][IDX2];
                end

                // Butterfly computation (combinational)
                logic signed [DATA_WIDTH-1:0] v_real, v_imag;
                assign v_real = dequant_mult(W_REAL, src2_r) - dequant_mult(W_IMAG, src2_i);
                assign v_imag = dequant_mult(W_REAL, src2_i) + dequant_mult(W_IMAG, src2_r);

                // Register pipeline outputs
                always_ff @(posedge clock) begin
                    pipe_real[gs][IDX1] <= src1_r + v_real;
                    pipe_imag[gs][IDX1] <= src1_i + v_imag;
                    pipe_real[gs][IDX2] <= src1_r - v_real;
                    pipe_imag[gs][IDX2] <= src1_i - v_imag;
                end
            end : gen_bfly
        end : gen_stage
    endgenerate

    // -----------------------------------------------------------
    // Sequential process (state register + input buffer)
    // -----------------------------------------------------------
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

    // Input buffer loading
    always_ff @(posedge clock) begin
        if (state == LOAD && in_empty == 1'b0) begin
            in_buf_real[count] <= in_real_dout;
            in_buf_imag[count] <= in_imag_dout;
        end
    end

    // -----------------------------------------------------------
    // Combinational process (next-state + outputs)
    // -----------------------------------------------------------
    always_comb begin
        // defaults
        state_c     = state;
        count_c     = count;
        stage_cnt_c = stage_cnt;
        in_rd_en    = 1'b0;
        out_wr_en   = 1'b0;
        out_real_din = '0;
        out_imag_din = '0;

        case (state)
            // -----------------------------------------------
            IDLE: begin
                count_c     = '0;
                stage_cnt_c = '0;
                if (in_empty == 1'b0) begin
                    state_c = LOAD;
                end
            end

            // -----------------------------------------------
            LOAD: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;
                    if (count == FFT_N - 1) begin
                        state_c     = COMPUTE;
                        count_c     = '0;
                        stage_cnt_c = '0;
                    end else begin
                        count_c = count + 1;
                    end
                end
            end

            // -----------------------------------------------
            // Wait for pipeline stages to propagate
            // After LOAD completes, input buffer is stable.
            // Bit reversal -> stage 0 butterflies are combinational.
            // Each clock edge registers the next pipeline stage.
            // Need NUM_STAGES clock edges for full propagation.
            // -----------------------------------------------
            COMPUTE: begin
                stage_cnt_c = stage_cnt + 1;
                if (stage_cnt == CNT_W'(NUM_STAGES)) begin
                    state_c = OUTPUT;
                    count_c = '0;
                end
            end

            // -----------------------------------------------
            OUTPUT: begin
                if (out_full == 1'b0) begin
                    out_wr_en    = 1'b1;
                    out_real_din = pipe_real[NUM_STAGES-1][count];
                    out_imag_din = pipe_imag[NUM_STAGES-1][count];
                    if (count == FFT_N - 1) begin
                        state_c = IDLE;
                        count_c = '0;
                    end else begin
                        count_c = count + 1;
                    end
                end
            end

            // -----------------------------------------------
            default: begin
                state_c     = IDLE;
                count_c     = '0;
                stage_cnt_c = '0;
            end
        endcase
    end

endmodule
