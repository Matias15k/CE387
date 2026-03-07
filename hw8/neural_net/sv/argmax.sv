module argmax #(
    parameter DATA_WIDTH  = 32,
    parameter NUM_INPUTS  = 10
)(
    input  logic signed [DATA_WIDTH-1:0]            values [NUM_INPUTS],
    output logic [$clog2(NUM_INPUTS)-1:0]           index,
    output logic signed [DATA_WIDTH-1:0]            max_val
);

    // Combinational argmax – find the index of the largest value
    always_comb begin
        max_val = values[0];
        index   = '0;
        for (int i = 1; i < NUM_INPUTS; i++) begin
            if (values[i] > max_val) begin
                max_val = values[i];
                index   = i[$clog2(NUM_INPUTS)-1:0];
            end
        end
    end

endmodule
