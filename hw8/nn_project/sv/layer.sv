// =============================================================================
// layer.sv
// Parameterized dense layer.  Instantiates NUM_NEURONS neuron modules.
// Loads weights & biases from WEIGHT_FILE via $readmemh.
// File layout: first INPUT_SIZE*NUM_NEURONS words = weights (neuron-major),
//              then NUM_NEURONS words = biases.
// Internal counter drives weights and generates data_valid / last_input
// in lock-step with data_in arriving from the parent (neural_net).
// 2-process FSM style consistent with grayscale reference.
// =============================================================================

module layer #(
    parameter int          DATA_WIDTH  = 32,
    parameter int          INPUT_SIZE  = 784,
    parameter int          NUM_NEURONS = 10,
    parameter int          BITS        = 14,
    parameter int          ACC_WIDTH   = 64,
    parameter string       WEIGHT_FILE = "layer_0_weights_biases.txt"
)(
    input  logic                    clock,
    input  logic                    reset,
    // Handshake with neural_net
    input  logic                    start,      // one-cycle pulse: begin computation
    input  logic [DATA_WIDTH-1:0]   data_in,    // one input sample per cycle (from parent buf)
    output logic                    done,       // one-cycle pulse: results are valid
    // Neuron results
    output logic [DATA_WIDTH-1:0]   results [0:NUM_NEURONS-1]
);

    // -----------------------------------------------------------------
    // Weight / bias ROM
    // Total entries = INPUT_SIZE*NUM_NEURONS (weights) + NUM_NEURONS (biases)
    // -----------------------------------------------------------------
    localparam int TOTAL_MEM = INPUT_SIZE * NUM_NEURONS + NUM_NEURONS;
    logic [DATA_WIDTH-1:0] mem [0:TOTAL_MEM-1];
    initial $readmemh(WEIGHT_FILE, mem);

    // -----------------------------------------------------------------
    // Counter and state
    // -----------------------------------------------------------------
    localparam int CNT_W = $clog2(INPUT_SIZE) + 1;

    typedef enum logic [1:0] {IDLE, ACTIVE, DONE_ST} state_t;
    state_t state, state_c;

    logic [CNT_W-1:0] cnt, cnt_c;
    logic             done_c;
    logic             data_valid_w;
    logic             last_input_w;

    // Combinational decode
    assign data_valid_w = (state == ACTIVE);
    assign last_input_w = (state == ACTIVE) && (cnt == CNT_W'(INPUT_SIZE - 1));

    // -----------------------------------------------------------------
    // Sequential process
    // -----------------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            cnt   <= '0;
            done  <= 1'b0;
        end else begin
            state <= state_c;
            cnt   <= cnt_c;
            done  <= done_c;
        end
    end

    // -----------------------------------------------------------------
    // Combinational process — next-state + counter + done
    // -----------------------------------------------------------------
    always_comb begin
        state_c = state;
        cnt_c   = cnt;
        done_c  = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    cnt_c   = '0;
                    state_c = ACTIVE;
                end
            end

            ACTIVE: begin
                if (cnt == CNT_W'(INPUT_SIZE - 1)) begin
                    // Last sample processed this cycle → go to DONE_ST
                    cnt_c   = '0;
                    state_c = DONE_ST;
                end else begin
                    cnt_c = cnt + 1'b1;
                end
            end

            DONE_ST: begin
                // One-cycle pulse: results are now registered in neurons
                done_c  = 1'b1;
                state_c = IDLE;
            end

            default: state_c = IDLE;
        endcase
    end

    // -----------------------------------------------------------------
    // Instantiate NUM_NEURONS neurons
    // Neuron j uses: weight = mem[j*INPUT_SIZE + cnt], bias = mem[NUM_NEURONS*INPUT_SIZE + j]
    // -----------------------------------------------------------------
    genvar j;
    generate
        for (j = 0; j < NUM_NEURONS; j++) begin : neuron_gen
            logic [DATA_WIDTH-1:0] w_in;
            // Combinationally select weight for neuron j at current input index
            assign w_in = mem[j * INPUT_SIZE + cnt];

            neuron #(
                .DATA_WIDTH(DATA_WIDTH),
                .INPUT_SIZE(INPUT_SIZE),
                .BITS       (BITS),
                .ACC_WIDTH  (ACC_WIDTH)
            ) n_inst (
                .clock      (clock),
                .reset      (reset),
                .start      (start),
                .data_valid (data_valid_w),
                .last_input (last_input_w),
                .data_in    (data_in),
                .weight_in  (w_in),
                .bias       (mem[NUM_NEURONS * INPUT_SIZE + j]),
                .result     (results[j])
            );
        end
    endgenerate

endmodule
