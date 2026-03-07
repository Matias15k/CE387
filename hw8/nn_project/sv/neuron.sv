// =============================================================================
// neuron.sv
// Parameterized sequential neuron with 2-process FSM.
// Accumulates (data_in * weight_in) >> BITS each data_valid cycle.
// On last_input, computes final result = acc >> BITS.
// =============================================================================

module neuron #(
    parameter int DATA_WIDTH = 32,
    parameter int INPUT_SIZE = 784,
    parameter int BITS       = 14,
    parameter int ACC_WIDTH  = 64
)(
    input  logic                    clock,
    input  logic                    reset,
    // Control
    input  logic                    start,       // one-cycle pulse: load bias, begin
    input  logic                    data_valid,  // data_in/weight_in valid this cycle
    input  logic                    last_input,  // this is the last valid sample
    // Data
    input  logic [DATA_WIDTH-1:0]   data_in,
    input  logic [DATA_WIDTH-1:0]   weight_in,
    input  logic [DATA_WIDTH-1:0]   bias,
    // Output
    output logic [DATA_WIDTH-1:0]   result
);

    // -----------------------------------------------------------------
    // Signed intermediate for MAC
    // Explicitly sign-extend operands to 64-bit before multiply so
    // the full double-width product is preserved (no overflow).
    // -----------------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] data_sx, weight_sx;
    logic signed [ACC_WIDTH-1:0] product;

    // Arithmetic sign-extension: replicate the MSB
    assign data_sx   = {{(ACC_WIDTH-DATA_WIDTH){data_in[DATA_WIDTH-1]}},   data_in};
    assign weight_sx = {{(ACC_WIDTH-DATA_WIDTH){weight_in[DATA_WIDTH-1]}}, weight_in};
    assign product   = data_sx * weight_sx;

    // -----------------------------------------------------------------
    // State / registers
    // -----------------------------------------------------------------
    typedef enum logic {IDLE, COMPUTE} state_t;
    state_t state, state_c;

    logic signed [ACC_WIDTH-1:0] acc,    acc_c;
    logic        [DATA_WIDTH-1:0] result_c;

    // -----------------------------------------------------------------
    // Sequential process (always_ff)
    // -----------------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state  <= IDLE;
            acc    <= '0;
            result <= '0;
        end else begin
            state  <= state_c;
            acc    <= acc_c;
            result <= result_c;
        end
    end

    // -----------------------------------------------------------------
    // Combinational process (always_comb) — next-state + output logic
    // -----------------------------------------------------------------
    always_comb begin
        // Defaults (hold current values)
        state_c  = state;
        acc_c    = acc;
        result_c = result;

        case (state)
            IDLE: begin
                if (start) begin
                    // Sign-extend bias (32-bit) to ACC_WIDTH for accumulator
                    acc_c   = {{(ACC_WIDTH-DATA_WIDTH){bias[DATA_WIDTH-1]}}, bias};
                    state_c = COMPUTE;
                end
            end

            COMPUTE: begin
                if (data_valid) begin
                    // Accumulate: acc += (data_in * weight_in) >>> BITS
                    // product is already 64-bit signed; arithmetic shift preserves sign
                    acc_c = acc + (product >>> BITS);

                    if (last_input) begin
                        // Final dequantize: result = acc >>> BITS (lower DATA_WIDTH bits)
                        result_c = DATA_WIDTH'((acc_c) >>> BITS);
                        state_c  = IDLE;
                    end
                end
            end

            default: state_c = IDLE;
        endcase
    end

endmodule
