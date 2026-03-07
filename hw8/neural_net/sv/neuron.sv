module neuron #(
    parameter DATA_WIDTH = 32,
    parameter BITS       = 14
)(
    input  logic                          clock,
    input  logic                          reset,
    input  logic                          start,
    input  logic signed [DATA_WIDTH-1:0]  bias,
    input  logic                          data_valid,
    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic signed [DATA_WIDTH-1:0]  weight_in,
    output logic signed [DATA_WIDTH-1:0]  result
);

    // Accumulator register and next-state
    logic signed [DATA_WIDTH-1:0] acc, acc_c;

    // 64-bit multiplication result for full precision
    logic signed [2*DATA_WIDTH-1:0] mult_result;

    // Combinational multiply
    assign mult_result = data_in * weight_in;

    // Sequential: accumulator register
    always_ff @(posedge clock or posedge reset) begin
        if (reset)
            acc <= '0;
        else
            acc <= acc_c;
    end

    // Combinational: next accumulator value
    always_comb begin
        acc_c = acc;
        if (start)
            acc_c = bias;
        else if (data_valid)
            acc_c = acc + DATA_WIDTH'(mult_result >>> BITS);
    end

    // Output: raw accumulator (shift + ReLU applied externally by layer)
    assign result = acc;

endmodule
