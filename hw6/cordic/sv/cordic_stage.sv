
module cordic_stage
#(
    parameter K_IDX = 0,                        
    parameter signed [15:0] C_VAL = 16'sh0000   
)
(
    input  logic                clock,
    input  logic                reset,
    input  logic                enable,
    input  logic signed [15:0]  x_in,
    input  logic signed [15:0]  y_in,
    input  logic signed [15:0]  z_in,
    input  logic                valid_in,
    output logic signed [15:0]  x_out,
    output logic signed [15:0]  y_out,
    output logic signed [15:0]  z_out,
    output logic                valid_out
);

    logic signed [15:0] d;
    assign d = (z_in >= 16'sh0000) ? 16'sh0000 : 16'shFFFF;

    logic signed [15:0] tx, ty, tz;
    assign tx = x_in - (((y_in >>> K_IDX) ^ d) - d);
    assign ty = y_in + (((x_in >>> K_IDX) ^ d) - d);
    assign tz = z_in - ((C_VAL ^ d) - d);

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
