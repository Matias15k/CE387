
module cordic
#(parameter STAGES = 16)
(
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
    // =========================================================================
    localparam signed [31:0] CORDIC_PI      = 32'sd51471;
    localparam signed [31:0] CORDIC_TWO_PI  = 32'sd102943;
    localparam signed [31:0] CORDIC_HALF_PI = 32'sd25735;
    localparam signed [15:0] CORDIC_1K      = 16'sh26DD;

    // CORDIC lookup table: atan(2^(-i)) quantized to 14 fractional bits
    localparam signed [15:0] CORDIC_TABLE [0:STAGES-1] = '{
        16'sh3243, 16'sh1DAC, 16'sh0FAD, 16'sh07F5,
        16'sh03FE, 16'sh01FF, 16'sh00FF, 16'sh007F,
        16'sh003F, 16'sh001F, 16'sh000F, 16'sh0007,
        16'sh0003, 16'sh0001, 16'sh0000, 16'sh0000
    };

    // =========================================================================
    // Pipeline packed arrays (following mult_pipe.sv style)
    // x[0..STAGES]: index 0 = input to stage 0, index STAGES = output of stage 15
    // =========================================================================
    logic signed [0:STAGES] [15:0] x;
    logic signed [0:STAGES] [15:0] y;
    logic signed [0:STAGES] [15:0] z;
    logic        [0:STAGES]        valid;

    // =========================================================================
    // Pipeline stall: hold all registers when output valid but FIFOs full
    // =========================================================================
    logic pipeline_en;
    assign pipeline_en = ~valid[STAGES] | (~sin_full & ~cos_full);

    // =========================================================================
    // Input FIFO read control
    // =========================================================================
    assign in_rd_en = (~in_empty) & pipeline_en;

    // =========================================================================
    // Range reduction (combinational) — reduces to [-PI/2, PI/2]
    // =========================================================================
    logic signed [31:0] rad_in, r1, r2;
    logic signed [15:0] x_init, y_init, z_init;

    assign rad_in = $signed(in_dout);

    always_comb begin
        // Step 1: reduce to [-PI, PI]
        if (rad_in > CORDIC_PI)
            r1 = rad_in - CORDIC_TWO_PI;
        else if (rad_in < -CORDIC_PI)
            r1 = rad_in + CORDIC_TWO_PI;
        else
            r1 = rad_in;
    end

    always_comb begin
        // Step 2: reduce to [-PI/2, PI/2] with quadrant flip
        if (r1 > CORDIC_HALF_PI) begin
            r2     = r1 - CORDIC_PI;
            x_init = -CORDIC_1K;
            y_init = 16'sh0000;
        end else if (r1 < -CORDIC_HALF_PI) begin
            r2     = r1 + CORDIC_PI;
            x_init = -CORDIC_1K;
            y_init = 16'sh0000;
        end else begin
            r2     = r1;
            x_init = CORDIC_1K;
            y_init = 16'sh0000;
        end
        z_init = r2[15:0];
    end

    // Pipeline input (combinational, feeds stage 0)
    assign x[0]     = x_init;
    assign y[0]     = y_init;
    assign z[0]     = z_init;
    assign valid[0] = in_rd_en;

    // =========================================================================
    // 16-stage pipelined CORDIC — instantiate cordic_stage components
    // using GENERATE-FOR with packed array wiring (mult_pipe.sv style)
    //
    // NOTE: cordic_stage ports are declared 'signed', so packed array slices
    // (which lose signedness) are correctly interpreted inside each stage.
    // =========================================================================
    genvar k;
    generate
        for (k = 0; k < STAGES; k++) begin : pipe
            cordic_stage #(
                .K_IDX(k),
                .C_VAL(CORDIC_TABLE[k])
            ) stage_inst (
                .clock    (clock),
                .reset    (reset),
                .enable   (pipeline_en),
                .x_in     (x[k]),
                .y_in     (y[k]),
                .z_in     (z[k]),
                .valid_in (valid[k]),
                .x_out    (x[k+1]),
                .y_out    (y[k+1]),
                .z_out    (z[k+1]),
                .valid_out(valid[k+1])
            );
        end
    endgenerate

    // =========================================================================
    // Output: write to sin and cos FIFOs
    // =========================================================================
    assign cos_din   = x[STAGES];
    assign sin_din   = y[STAGES];
    assign sin_wr_en = valid[STAGES] & (~sin_full);
    assign cos_wr_en = valid[STAGES] & (~cos_full);

endmodule
