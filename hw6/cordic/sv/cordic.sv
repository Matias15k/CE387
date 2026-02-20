
module cordic (
    input  logic        clock,
    input  logic        reset,
    // input FIFO read interface (32-bit radians)
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [31:0] in_dout,
    // sin output FIFO write interface (16-bit)
    output logic        sin_wr_en,
    input  logic        sin_full,
    output logic [15:0] sin_din,
    // cos output FIFO write interface (16-bit)
    output logic        cos_wr_en,
    input  logic        cos_full,
    output logic [15:0] cos_din
);

    // =========================================================================
    // Fixed-point constants (14 fractional bits, matching C code)
    // QUANTIZE_F(f) = (int)((float)(f) * (float)(16384))
    // =========================================================================
    localparam signed [31:0] CORDIC_PI      = 32'sd51471;   // QUANTIZE_F(M_PI)
    localparam signed [31:0] CORDIC_TWO_PI  = 32'sd102943;  // QUANTIZE_F(M_PI*2.0)
    localparam signed [31:0] CORDIC_HALF_PI = 32'sd25735;   // QUANTIZE_F(M_PI/2.0)

    // K = 1.646760258121066, CORDIC_1K = QUANTIZE_F(1/K) = 9949
    localparam signed [15:0] CORDIC_1K = 16'sh26DD;

    // CORDIC lookup table: atan(2^(-i)) quantized to 14 fractional bits
    localparam signed [15:0] CORDIC_TABLE [0:15] = '{
        16'sh3243, 16'sh1DAC, 16'sh0FAD, 16'sh07F5,
        16'sh03FE, 16'sh01FF, 16'sh00FF, 16'sh007F,
        16'sh003F, 16'sh001F, 16'sh000F, 16'sh0007,
        16'sh0003, 16'sh0001, 16'sh0000, 16'sh0000
    };

    // =========================================================================
    // Pipeline wires
    // =========================================================================
    logic signed [15:0] pipe_x     [0:16];
    logic signed [15:0] pipe_y     [0:16];
    logic signed [15:0] pipe_z     [0:16];
    logic               pipe_valid [0:16];

    // =========================================================================
    // Pipeline stall logic:
    // Stall entire pipeline when valid data at output but FIFOs are full.
    // This prevents data loss in the pipeline.
    // =========================================================================
    logic pipeline_en;
    assign pipeline_en = ~pipe_valid[16] | (~sin_full & ~cos_full);

    // =========================================================================
    // Input FIFO read control:
    // Read when pipeline can accept new data AND input FIFO has data
    // =========================================================================
    logic feed_valid;
    assign in_rd_en   = (~in_empty) & pipeline_en;
    assign feed_valid  = in_rd_en;

    // =========================================================================
    // Range reduction (combinational)
    // Reduces input angle from [-2*PI, 2*PI] to [-PI/2, PI/2]
    // =========================================================================
    logic signed [31:0] rad_in;
    logic signed [31:0] r1, r2;
    logic signed [15:0] x_init, y_init, z_init;

    assign rad_in = $signed(in_dout);

    // Step 1: reduce to [-PI, PI]
    always_comb begin
        if (rad_in > CORDIC_PI)
            r1 = rad_in - CORDIC_TWO_PI;
        else if (rad_in < -CORDIC_PI)
            r1 = rad_in + CORDIC_TWO_PI;
        else
            r1 = rad_in;
    end

    // Step 2: reduce to [-PI/2, PI/2] with quadrant adjustment
    always_comb begin
        if (r1 > CORDIC_HALF_PI) begin
            r2 = r1 - CORDIC_PI;
            x_init = -CORDIC_1K;
            y_init = 16'sh0000;
        end else if (r1 < -CORDIC_HALF_PI) begin
            r2 = r1 + CORDIC_PI;
            x_init = -CORDIC_1K;
            y_init = 16'sh0000;
        end else begin
            r2 = r1;
            x_init = CORDIC_1K;
            y_init = 16'sh0000;
        end
        z_init = r2[15:0]; // truncate to 16-bit (same as C: short z = r)
    end

    // =========================================================================
    // Pipeline input connections
    // =========================================================================
    assign pipe_x[0]     = x_init;
    assign pipe_y[0]     = y_init;
    assign pipe_z[0]     = z_init;
    assign pipe_valid[0] = feed_valid;

    // =========================================================================
    // 16-stage hardware pipeline using GENERATE-FOR
    // =========================================================================
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : cordic_pipeline
            cordic_stage #(
                .K_IDX(i),
                .C_VAL(CORDIC_TABLE[i])
            ) stage_inst (
                .clock(clock),
                .reset(reset),
                .enable(pipeline_en),
                .x_in(pipe_x[i]),
                .y_in(pipe_y[i]),
                .z_in(pipe_z[i]),
                .valid_in(pipe_valid[i]),
                .x_out(pipe_x[i+1]),
                .y_out(pipe_y[i+1]),
                .z_out(pipe_z[i+1]),
                .valid_out(pipe_valid[i+1])
            );
        end
    endgenerate

    // =========================================================================
    // Output: write to sin and cos FIFOs when pipeline output is valid
    // =========================================================================
    assign cos_din   = pipe_x[16];    // x output = cos
    assign sin_din   = pipe_y[16];    // y output = sin
    assign sin_wr_en = pipe_valid[16] & (~sin_full);
    assign cos_wr_en = pipe_valid[16] & (~cos_full);

endmodule
