module neural_net #(
    parameter DATA_WIDTH   = 32,
    parameter NUM_INPUTS   = 784,
    parameter NUM_L0_OUT   = 10,
    parameter NUM_L1_OUT   = 10,
    parameter BITS         = 14,
    parameter string WEIGHT_FILE0 = "layer_0_weights_biases.txt",
    parameter string WEIGHT_FILE1 = "layer_1_weights_biases.txt"
)(
    input  logic                          clock,
    input  logic                          reset,
    // Input FIFO read interface (FIFO pushes data to us)
    output logic                          in_rd_en,
    input  logic                          in_empty,
    input  logic signed [DATA_WIDTH-1:0]  in_dout,
    // Output FIFO write interface
    output logic                          out_wr_en,
    input  logic                          out_full,
    output logic [3:0]                    out_din,
    // Layer outputs exposed for UVM coverage / monitoring
    output logic signed [DATA_WIDTH-1:0]  layer0_out [NUM_L0_OUT],
    output logic signed [DATA_WIDTH-1:0]  layer1_out [NUM_L1_OUT],
    output logic [3:0]                    predicted_digit,
    output logic                          inference_done
);

    // -------------------------------------------------------
    // FSM state definitions
    // -------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE,
        S_L0_START,
        S_L0_FEED,
        S_L0_WAIT,
        S_L1_START,
        S_L1_FEED,
        S_L1_WAIT,
        S_ARGMAX,
        S_OUTPUT,
        S_DONE
    } state_t;

    state_t state, state_c;

    // -------------------------------------------------------
    // Counters
    // -------------------------------------------------------
    localparam INPUT_CNT_W = $clog2(NUM_INPUTS);
    localparam L1_CNT_W    = $clog2(NUM_L0_OUT);

    logic [INPUT_CNT_W-1:0] input_count, input_count_c;
    logic [L1_CNT_W-1:0]    l1_idx, l1_idx_c;

    // -------------------------------------------------------
    // Layer 0 signals
    // -------------------------------------------------------
    logic                          l0_start;
    logic                          l0_data_valid;
    logic signed [DATA_WIDTH-1:0]  l0_data_in;
    logic signed [DATA_WIDTH-1:0]  l0_results [NUM_L0_OUT];
    logic                          l0_done;

    // -------------------------------------------------------
    // Layer 1 signals
    // -------------------------------------------------------
    logic                          l1_start;
    logic                          l1_data_valid;
    logic signed [DATA_WIDTH-1:0]  l1_data_in;
    logic signed [DATA_WIDTH-1:0]  l1_results [NUM_L1_OUT];
    logic                          l1_done;

    // -------------------------------------------------------
    // Argmax signals
    // -------------------------------------------------------
    logic [$clog2(NUM_L1_OUT)-1:0] argmax_idx;
    logic signed [DATA_WIDTH-1:0]  argmax_val;
    logic [3:0]                    digit_reg, digit_c;
    logic                          inf_done_reg, inf_done_c;

    // -------------------------------------------------------
    // Layer 0 instance
    // -------------------------------------------------------
    layer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .NUM_INPUTS  (NUM_INPUTS),
        .NUM_OUTPUTS (NUM_L0_OUT),
        .BITS        (BITS),
        .WEIGHT_FILE (WEIGHT_FILE0)
    ) layer0 (
        .clock      (clock),
        .reset      (reset),
        .start      (l0_start),
        .data_valid (l0_data_valid),
        .data_in    (l0_data_in),
        .results    (l0_results),
        .done       (l0_done)
    );

    // -------------------------------------------------------
    // Layer 1 instance
    // -------------------------------------------------------
    layer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .NUM_INPUTS  (NUM_L0_OUT),
        .NUM_OUTPUTS (NUM_L1_OUT),
        .BITS        (BITS),
        .WEIGHT_FILE (WEIGHT_FILE1)
    ) layer1 (
        .clock      (clock),
        .reset      (reset),
        .start      (l1_start),
        .data_valid (l1_data_valid),
        .data_in    (l1_data_in),
        .results    (l1_results),
        .done       (l1_done)
    );

    // -------------------------------------------------------
    // Argmax instance (combinational)
    // -------------------------------------------------------
    argmax #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_INPUTS (NUM_L1_OUT)
    ) argmax_inst (
        .values  (l1_results),
        .index   (argmax_idx),
        .max_val (argmax_val)
    );

    // -------------------------------------------------------
    // Expose layer outputs for UVM
    // -------------------------------------------------------
    assign layer0_out      = l0_results;
    assign layer1_out      = l1_results;
    assign predicted_digit = digit_reg;
    assign inference_done  = inf_done_reg;

    // -------------------------------------------------------
    // Process 1: Sequential – state & data registers
    // -------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state       <= S_IDLE;
            input_count <= '0;
            l1_idx      <= '0;
            digit_reg   <= '0;
            inf_done_reg <= 1'b0;
        end else begin
            state       <= state_c;
            input_count <= input_count_c;
            l1_idx      <= l1_idx_c;
            digit_reg   <= digit_c;
            inf_done_reg <= inf_done_c;
        end
    end

    // -------------------------------------------------------
    // Process 2: Combinational – next-state & output logic
    // -------------------------------------------------------
    always_comb begin
        // Defaults
        state_c       = state;
        input_count_c = input_count;
        l1_idx_c      = l1_idx;
        digit_c       = digit_reg;
        inf_done_c    = inf_done_reg;

        in_rd_en      = 1'b0;
        out_wr_en     = 1'b0;
        out_din       = 4'b0;

        l0_start      = 1'b0;
        l0_data_valid = 1'b0;
        l0_data_in    = '0;

        l1_start      = 1'b0;
        l1_data_valid = 1'b0;
        l1_data_in    = '0;

        case (state)
            // --------------------------------------------------
            S_IDLE: begin
                inf_done_c = 1'b0;
                if (in_empty == 1'b0) begin
                    state_c       = S_L0_START;
                    input_count_c = '0;
                end
            end

            // --------------------------------------------------
            S_L0_START: begin
                l0_start = 1'b1;  // resets all layer-0 neurons to biases
                state_c  = S_L0_FEED;
            end

            // --------------------------------------------------
            S_L0_FEED: begin
                if (in_empty == 1'b0) begin
                    l0_data_valid = 1'b1;
                    l0_data_in    = in_dout;
                    in_rd_en      = 1'b1;

                    if (input_count == NUM_INPUTS - 1) begin
                        state_c = S_L0_WAIT;
                    end else begin
                        input_count_c = input_count + 1'b1;
                    end
                end
            end

            // --------------------------------------------------
            // Wait one cycle for last MAC result to register
            S_L0_WAIT: begin
                state_c  = S_L1_START;
                l1_idx_c = '0;
            end

            // --------------------------------------------------
            S_L1_START: begin
                l1_start = 1'b1;  // resets all layer-1 neurons to biases
                state_c  = S_L1_FEED;
            end

            // --------------------------------------------------
            S_L1_FEED: begin
                l1_data_valid = 1'b1;
                l1_data_in    = l0_results[l1_idx];

                if (l1_idx == NUM_L0_OUT - 1) begin
                    state_c = S_L1_WAIT;
                end else begin
                    l1_idx_c = l1_idx + 1'b1;
                end
            end

            // --------------------------------------------------
            // Wait one cycle for last MAC result to register
            S_L1_WAIT: begin
                state_c = S_ARGMAX;
            end

            // --------------------------------------------------
            S_ARGMAX: begin
                digit_c = argmax_idx[3:0];
                state_c = S_OUTPUT;
            end

            // --------------------------------------------------
            S_OUTPUT: begin
                if (out_full == 1'b0) begin
                    out_wr_en  = 1'b1;
                    out_din    = digit_reg;
                    inf_done_c = 1'b1;
                    state_c    = S_DONE;
                end
            end

            // --------------------------------------------------
            S_DONE: begin
                // Stay here after inference (or go back to IDLE for multiple inferences)
                state_c = S_IDLE;
            end

            // --------------------------------------------------
            default: begin
                state_c = S_IDLE;
            end
        endcase
    end

endmodule
