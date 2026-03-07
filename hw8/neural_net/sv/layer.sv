module layer #(
    parameter DATA_WIDTH   = 32,
    parameter NUM_INPUTS   = 784,
    parameter NUM_OUTPUTS  = 10,
    parameter BITS         = 14,
    parameter string WEIGHT_FILE  = "layer_0_weights_biases.txt"
)(
    input  logic                          clock,
    input  logic                          reset,
    input  logic                          start,
    input  logic                          data_valid,
    input  logic signed [DATA_WIDTH-1:0]  data_in,
    output logic signed [DATA_WIDTH-1:0]  results [NUM_OUTPUTS],
    output logic                          done
);

    // -----------------------------------------------------------
    // Weight & bias storage – loaded once from hex file
    // File layout: NUM_INPUTS*NUM_OUTPUTS weights, then NUM_OUTPUTS biases
    // -----------------------------------------------------------
    localparam MEM_DEPTH = NUM_INPUTS * NUM_OUTPUTS + NUM_OUTPUTS;

    logic signed [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    initial begin
        $readmemh(WEIGHT_FILE, mem);
    end

    // -----------------------------------------------------------
    // Input counter – tracks which input sample we are on
    // -----------------------------------------------------------
    localparam IDX_WIDTH = (NUM_INPUTS > 1) ? $clog2(NUM_INPUTS) : 1;

    logic [IDX_WIDTH-1:0] idx, idx_c;
    logic                 counting, counting_c;
    logic                 done_r, done_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            idx      <= '0;
            counting <= 1'b0;
            done_r   <= 1'b0;
        end else begin
            idx      <= idx_c;
            counting <= counting_c;
            done_r   <= done_c;
        end
    end

    always_comb begin
        idx_c      = idx;
        counting_c = counting;
        done_c     = done_r;

        if (start) begin
            idx_c      = '0;
            counting_c = 1'b1;
            done_c     = 1'b0;
        end else if (counting && data_valid) begin
            if (idx == NUM_INPUTS - 1) begin
                counting_c = 1'b0;
                done_c     = 1'b1;
            end else begin
                idx_c = idx + 1'b1;
            end
        end
    end

    assign done = done_r;

    // -----------------------------------------------------------
    // Neuron instances (generate block)
    // Each neuron gets the broadcast data_in and its own weight
    // -----------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] neuron_raw [NUM_OUTPUTS];

    genvar j;
    generate
        for (j = 0; j < NUM_OUTPUTS; j++) begin : neuron_gen

            // Weight selection: weight for neuron j at input idx
            logic signed [DATA_WIDTH-1:0] w_sel;
            assign w_sel = mem[j * NUM_INPUTS + idx];

            // Bias for neuron j
            logic signed [DATA_WIDTH-1:0] b_sel;
            assign b_sel = mem[NUM_INPUTS * NUM_OUTPUTS + j];

            neuron #(
                .DATA_WIDTH (DATA_WIDTH),
                .BITS       (BITS)
            ) neuron_inst (
                .clock      (clock),
                .reset      (reset),
                .start      (start),
                .bias       (b_sel),
                .data_valid (data_valid),
                .data_in    (data_in),
                .weight_in  (w_sel),
                .result     (neuron_raw[j])
            );
        end
    endgenerate

    // -----------------------------------------------------------
    // Output: dequantize (>>> BITS) then ReLU
    // -----------------------------------------------------------
    generate
        for (j = 0; j < NUM_OUTPUTS; j++) begin : relu_gen
            logic signed [DATA_WIDTH-1:0] shifted;
            assign shifted    = neuron_raw[j] >>> BITS;
            assign results[j] = (shifted > 0) ? shifted : '0;
        end
    endgenerate

endmodule
