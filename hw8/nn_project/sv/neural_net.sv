// =============================================================================
// neural_net.sv
// Pipelined streaming deep neural network (2 dense layers).
// 2-process FSM style consistent with grayscale reference.
//
// Architecture:
//   FIFO_IN → [Load 784 inputs] → Layer0 (784→10, ReLU) →
//              Layer1 (10→10, ReLU) → Argmax → FIFO_OUT (4-bit class)
//
// Quantization: BITS=14 fixed-point throughout (matches C reference)
// =============================================================================

module neural_net #(
    parameter int    DATA_WIDTH  = 32,
    parameter int    NUM_INPUTS  = 784,   // pixels per image
    parameter int    L0_NEURONS  = 10,    // layer 0 output neurons
    parameter int    L1_NEURONS  = 10,    // layer 1 output neurons (= final classes)
    parameter int    BITS        = 14,    // fixed-point fractional bits
    parameter int    ACC_WIDTH   = 64,
    parameter int    OUT_WIDTH   = 4,     // ceil(log2(10))
    parameter string L0_FILE     = "layer_0_weights_biases.txt",
    parameter string L1_FILE     = "layer_1_weights_biases.txt"
)(
    input  logic                    clock,
    input  logic                    reset,
    // Input FIFO interface
    output logic                    in_rd_en,
    input  logic                    in_empty,
    input  logic [DATA_WIDTH-1:0]   in_dout,
    // Output FIFO interface
    output logic                    out_wr_en,
    input  logic                    out_full,
    output logic [OUT_WIDTH-1:0]    out_din
);

    // =========================================================================
    // FSM state encoding
    // =========================================================================
    typedef enum logic [3:0] {
        S_IDLE,
        S_LOAD,       // read 784 pixels from input FIFO
        S_START_L0,   // pulse start to layer 0
        S_L0_COMPUTE, // stream inputs to layer 0 (784 cycles)
        S_L0_WAIT,    // wait one cycle for neurons to register results
        S_RELU_L0,    // apply ReLU to layer 0 outputs
        S_START_L1,   // pulse start to layer 1
        S_L1_COMPUTE, // stream layer-0 results to layer 1 (10 cycles)
        S_L1_WAIT,    // wait one cycle for neurons to register results
        S_RELU_L1,    // apply ReLU to layer 1 outputs
        S_ARGMAX,     // compute argmax
        S_OUTPUT      // write 4-bit class to output FIFO
    } state_t;

    state_t state, state_c;

    // =========================================================================
    // Data storage
    // =========================================================================
    localparam int LOAD_CNT_W = $clog2(NUM_INPUTS) + 1;
    localparam int L0_CNT_W   = $clog2(NUM_INPUTS) + 1;
    localparam int L1_CNT_W   = $clog2(L0_NEURONS) + 1;

    // Input pixel buffer
    logic [DATA_WIDTH-1:0] input_buf [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] input_buf_c [0:NUM_INPUTS-1];

    // Layer 0 post-ReLU outputs (feed into layer 1)
    logic [DATA_WIDTH-1:0] l0_buf [0:L0_NEURONS-1];
    logic [DATA_WIDTH-1:0] l0_buf_c [0:L0_NEURONS-1];

    // Layer 1 post-ReLU outputs (feed into argmax)
    logic [DATA_WIDTH-1:0] l1_buf [0:L1_NEURONS-1];
    logic [DATA_WIDTH-1:0] l1_buf_c [0:L1_NEURONS-1];

    // Counters
    logic [LOAD_CNT_W-1:0] load_cnt, load_cnt_c;
    logic [L0_CNT_W-1:0]   l0_cnt,   l0_cnt_c;
    logic [L1_CNT_W-1:0]   l1_cnt,   l1_cnt_c;

    // Output register
    logic [OUT_WIDTH-1:0] class_out, class_out_c;

    // =========================================================================
    // Layer interfaces
    // =========================================================================
    // Layer 0 signals
    logic                    l0_start;
    logic [DATA_WIDTH-1:0]   l0_data_in;
    logic                    l0_done;
    logic [DATA_WIDTH-1:0]   l0_results [0:L0_NEURONS-1];

    // Layer 1 signals
    logic                    l1_start;
    logic [DATA_WIDTH-1:0]   l1_data_in;
    logic                    l1_done;
    logic [DATA_WIDTH-1:0]   l1_results [0:L1_NEURONS-1];

    // Argmax
    logic [OUT_WIDTH-1:0]    argmax_out;

    // =========================================================================
    // Module instantiations
    // =========================================================================
    layer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .INPUT_SIZE  (NUM_INPUTS),
        .NUM_NEURONS (L0_NEURONS),
        .BITS        (BITS),
        .ACC_WIDTH   (ACC_WIDTH),
        .WEIGHT_FILE (L0_FILE)
    ) layer_0 (
        .clock   (clock),
        .reset   (reset),
        .start   (l0_start),
        .data_in (l0_data_in),
        .done    (l0_done),
        .results (l0_results)
    );

    layer #(
        .DATA_WIDTH  (DATA_WIDTH),
        .INPUT_SIZE  (L0_NEURONS),
        .NUM_NEURONS (L1_NEURONS),
        .BITS        (BITS),
        .ACC_WIDTH   (ACC_WIDTH),
        .WEIGHT_FILE (L1_FILE)
    ) layer_1 (
        .clock   (clock),
        .reset   (reset),
        .start   (l1_start),
        .data_in (l1_data_in),
        .done    (l1_done),
        .results (l1_results)
    );

    argmax #(
        .DATA_WIDTH  (DATA_WIDTH),
        .NUM_CLASSES (L1_NEURONS),
        .IDX_WIDTH   (OUT_WIDTH)
    ) argmax_inst (
        .data_in (l1_buf),
        .result  (argmax_out)
    );

    // =========================================================================
    // Sequential process
    // =========================================================================
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state     <= S_IDLE;
            load_cnt  <= '0;
            l0_cnt    <= '0;
            l1_cnt    <= '0;
            class_out <= '0;
            for (int i = 0; i < NUM_INPUTS;  i++) input_buf[i] <= '0;
            for (int i = 0; i < L0_NEURONS;  i++) l0_buf[i]    <= '0;
            for (int i = 0; i < L1_NEURONS;  i++) l1_buf[i]    <= '0;
        end else begin
            state     <= state_c;
            load_cnt  <= load_cnt_c;
            l0_cnt    <= l0_cnt_c;
            l1_cnt    <= l1_cnt_c;
            class_out <= class_out_c;
            for (int i = 0; i < NUM_INPUTS;  i++) input_buf[i] <= input_buf_c[i];
            for (int i = 0; i < L0_NEURONS;  i++) l0_buf[i]    <= l0_buf_c[i];
            for (int i = 0; i < L1_NEURONS;  i++) l1_buf[i]    <= l1_buf_c[i];
        end
    end

    // =========================================================================
    // Combinational process — next-state + output logic
    // =========================================================================
    always_comb begin
        // ------------------------------------------------------------------
        // Defaults — hold everything, deassert handshake signals
        // ------------------------------------------------------------------
        state_c    = state;
        load_cnt_c = load_cnt;
        l0_cnt_c   = l0_cnt;
        l1_cnt_c   = l1_cnt;
        class_out_c = class_out;

        for (int i = 0; i < NUM_INPUTS; i++) input_buf_c[i] = input_buf[i];
        for (int i = 0; i < L0_NEURONS; i++) l0_buf_c[i]    = l0_buf[i];
        for (int i = 0; i < L1_NEURONS; i++) l1_buf_c[i]    = l1_buf[i];

        in_rd_en   = 1'b0;
        out_wr_en  = 1'b0;
        out_din    = '0;

        l0_start   = 1'b0;
        l0_data_in = '0;
        l1_start   = 1'b0;
        l1_data_in = '0;

        // ------------------------------------------------------------------
        case (state)
            // ---- Wait for input data to arrive in FIFO ------------------
            S_IDLE: begin
                if (!in_empty) begin
                    load_cnt_c = '0;
                    state_c    = S_LOAD;
                end
            end

            // ---- Load NUM_INPUTS pixels from FIFO into input_buf --------
            S_LOAD: begin
                if (!in_empty) begin
                    in_rd_en = 1'b1;
                    input_buf_c[load_cnt] = in_dout;
                    if (load_cnt == LOAD_CNT_W'(NUM_INPUTS - 1)) begin
                        state_c    = S_START_L0;
                        load_cnt_c = '0;
                    end else begin
                        load_cnt_c = load_cnt + 1'b1;
                    end
                end
            end

            // ---- Pulse start to layer 0 ---------------------------------
            S_START_L0: begin
                l0_start = 1'b1;
                l0_cnt_c = '0;
                state_c  = S_L0_COMPUTE;
            end

            // ---- Stream 784 inputs to layer 0 ---------------------------
            S_L0_COMPUTE: begin
                l0_data_in = input_buf[l0_cnt];
                if (l0_cnt == L0_CNT_W'(NUM_INPUTS - 1)) begin
                    state_c  = S_L0_WAIT;
                    l0_cnt_c = '0;
                end else begin
                    l0_cnt_c = l0_cnt + 1'b1;
                end
            end

            // ---- Wait one cycle for neuron results to register ----------
            S_L0_WAIT: begin
                state_c = S_RELU_L0;
            end

            // ---- Apply ReLU to layer 0 results --------------------------
            S_RELU_L0: begin
                for (int i = 0; i < L0_NEURONS; i++) begin
                    l0_buf_c[i] = ($signed(l0_results[i]) > 0) ?
                                   l0_results[i] : '0;
                end
                state_c = S_START_L1;
            end

            // ---- Pulse start to layer 1 ---------------------------------
            S_START_L1: begin
                l1_start = 1'b1;
                l1_cnt_c = '0;
                state_c  = S_L1_COMPUTE;
            end

            // ---- Stream 10 l0 outputs to layer 1 -----------------------
            S_L1_COMPUTE: begin
                l1_data_in = l0_buf[l1_cnt];
                if (l1_cnt == L1_CNT_W'(L0_NEURONS - 1)) begin
                    state_c  = S_L1_WAIT;
                    l1_cnt_c = '0;
                end else begin
                    l1_cnt_c = l1_cnt + 1'b1;
                end
            end

            // ---- Wait one cycle for neuron results to register ----------
            S_L1_WAIT: begin
                state_c = S_RELU_L1;
            end

            // ---- Apply ReLU to layer 1 results --------------------------
            S_RELU_L1: begin
                for (int i = 0; i < L1_NEURONS; i++) begin
                    l1_buf_c[i] = ($signed(l1_results[i]) > 0) ?
                                   l1_results[i] : '0;
                end
                state_c = S_ARGMAX;
            end

            // ---- Argmax (combinational via argmax module) ---------------
            S_ARGMAX: begin
                class_out_c = argmax_out;
                state_c     = S_OUTPUT;
            end

            // ---- Write classification result to output FIFO -------------
            S_OUTPUT: begin
                if (!out_full) begin
                    out_din   = class_out;
                    out_wr_en = 1'b1;
                    state_c   = S_IDLE;
                end
            end

            default: state_c = S_IDLE;
        endcase
    end

endmodule
