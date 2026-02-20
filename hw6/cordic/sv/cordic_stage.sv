
module cordic_stage #(
    parameter K_IDX = 0,
    parameter signed [15:0] C_VAL = 16'sh0000
) (
    input  logic        clock,
    input  logic        reset,
    input  logic        enable,       // pipeline clock enable (stall when low)
    input  logic signed [15:0] x_in,
    input  logic signed [15:0] y_in,
    input  logic signed [15:0] z_in,
    input  logic        valid_in,
    output logic signed [15:0] x_out,
    output logic signed [15:0] y_out,
    output logic signed [15:0] z_out,
    output logic        valid_out
);

    // Combinational CORDIC iteration
    logic signed [15:0] d;
    logic signed [15:0] tx, ty, tz;

    always_comb begin
        // d = 0 when z >= 0, d = -1 (0xFFFF) when z < 0
        d = (z_in >= 16'sh0000) ? 16'sh0000 : 16'shFFFF;

        // CORDIC rotation:
        //   when d=0  (z>=0): tx = x - (y>>k), ty = y + (x>>k), tz = z - c
        //   when d=-1 (z<0):  tx = x + (y>>k), ty = y - (x>>k), tz = z + c
        tx = x_in - (((y_in >>> K_IDX) ^ d) - d);
        ty = y_in + (((x_in >>> K_IDX) ^ d) - d);
        tz = z_in - ((C_VAL ^ d) - d);
    end

    // Pipeline register with enable (stall support)
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
        // When !enable: hold current values (stall)
    end

endmodule
