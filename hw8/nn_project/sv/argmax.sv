// =============================================================================
// argmax.sv
// Parameterized combinational argmax.
// Scans NUM_CLASSES signed values and outputs the index of the maximum.
// =============================================================================

module argmax #(
    parameter int DATA_WIDTH  = 32,
    parameter int NUM_CLASSES = 10,
    parameter int IDX_WIDTH   = 4    // ceil(log2(NUM_CLASSES))
)(
    input  logic signed [DATA_WIDTH-1:0]  data_in [0:NUM_CLASSES-1],
    output logic        [IDX_WIDTH-1:0]   result
);

    always_comb begin
        logic signed [DATA_WIDTH-1:0] max_val;
        logic        [IDX_WIDTH-1:0]  max_idx;
        max_val = data_in[0];
        max_idx = '0;
        for (int i = 1; i < NUM_CLASSES; i++) begin
            if ($signed(data_in[i]) > max_val) begin
                max_val = data_in[i];
                max_idx = IDX_WIDTH'(i);
            end
        end
        result = max_idx;
    end

endmodule
