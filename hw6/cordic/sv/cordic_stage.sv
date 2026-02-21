
module cordic_stage
#(
    parameter K_IDX = 0,                        // rotation index (shift amount)
    parameter signed [15:0] C_VAL = 16'sh0000   // atan(2^(-K_IDX)) constant
)
(
    input  logic                clock,
    input  logic                reset,
    input  logic                enable,
    // pipeline data in (signed ports handle signedness from packed array slices)
    input  logic signed [15:0]  x_in,
    input  logic signed [15:0]  y_in,
    input  logic signed [15:0]  z_in,
    input  logic                valid_in,
    // pipeline data out (registered)
    output logic signed [15:0]  x_out,
    output logic signed [15:0]  y_out,
    output logic signed [15:0]  z_out,
    output logic                valid_out
);

    // CORDIC rotation direction: d = 0 if z >= 0, d = -1 if z < 0
    logic signed [15:0] d;
    assign d = (z_in >= 16'sh0000) ? 16'sh0000 : 16'shFFFF;

    // Combinational CORDIC micro-rotation for this stage
    // Uses XOR trick: ((val >>> k) ^ d) - d
    //   when d=0:  result =  (val >>> k)   [positive rotation]
    //   when d=-1: result = -(val >>> k)-1 [negative rotation, via complement]
    logic signed [15:0] tx, ty, tz;
    assign tx = x_in - (((y_in >>> K_IDX) ^ d) - d);
    assign ty = y_in + (((x_in >>> K_IDX) ^ d) - d);
    assign tz = z_in - ((C_VAL ^ d) - d);

    // Pipeline register (with enable for stall support)
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            x_out     <= 16'sh0000;
            y_out     <= 16'sh0000;
            z_out     <= 16'sh0000;
            valid_out <= 1'b0;
        end else if (enable) begin
            x_out     <= tx;
            y_out     <= ty;
            z_out     <= tz;
            valid_out <= valid_in;
        end
    end

endmodule
