module butterfly #(
    parameter DATA_WIDTH = 32,
    parameter QUANT_BITS = 14
) (
    input  logic signed [DATA_WIDTH-1:0] x1_real,
    input  logic signed [DATA_WIDTH-1:0] x1_imag,
    input  logic signed [DATA_WIDTH-1:0] x2_real,
    input  logic signed [DATA_WIDTH-1:0] x2_imag,
    input  logic signed [DATA_WIDTH-1:0] w_real,
    input  logic signed [DATA_WIDTH-1:0] w_imag,
    output logic signed [DATA_WIDTH-1:0] y1_real,
    output logic signed [DATA_WIDTH-1:0] y1_imag,
    output logic signed [DATA_WIDTH-1:0] y2_real,
    output logic signed [DATA_WIDTH-1:0] y2_imag
);

    localparam signed [2*DATA_WIDTH-1:0] HALF_Q    = 1 <<< (QUANT_BITS - 1);
    localparam signed [2*DATA_WIDTH-1:0] Q_MINUS_1 = (1 <<< QUANT_BITS) - 1;

    logic signed [2*DATA_WIDTH-1:0] prod_rr, prod_ii, prod_ri, prod_ir;
    logic signed [2*DATA_WIDTH-1:0] sum_rr,  sum_ii,  sum_ri,  sum_ir;
    logic signed [DATA_WIDTH-1:0]   dq_rr,   dq_ii,   dq_ri,   dq_ir;
    logic signed [DATA_WIDTH-1:0]   v_real,  v_imag;

    // Multiply
    assign prod_rr = $signed(w_real) * $signed(x2_real);
    assign prod_ii = $signed(w_imag) * $signed(x2_imag);
    assign prod_ri = $signed(w_real) * $signed(x2_imag);
    assign prod_ir = $signed(w_imag) * $signed(x2_real);

    // Add half-quantum for rounding
    assign sum_rr = prod_rr + HALF_Q;
    assign sum_ii = prod_ii + HALF_Q;
    assign sum_ri = prod_ri + HALF_Q;
    assign sum_ir = prod_ir + HALF_Q;

    assign dq_rr = (sum_rr >= 0) ? DATA_WIDTH'(sum_rr >>> QUANT_BITS)
                                 : DATA_WIDTH'((sum_rr + Q_MINUS_1) >>> QUANT_BITS);
    assign dq_ii = (sum_ii >= 0) ? DATA_WIDTH'(sum_ii >>> QUANT_BITS)
                                 : DATA_WIDTH'((sum_ii + Q_MINUS_1) >>> QUANT_BITS);
    assign dq_ri = (sum_ri >= 0) ? DATA_WIDTH'(sum_ri >>> QUANT_BITS)
                                 : DATA_WIDTH'((sum_ri + Q_MINUS_1) >>> QUANT_BITS);
    assign dq_ir = (sum_ir >= 0) ? DATA_WIDTH'(sum_ir >>> QUANT_BITS)
                                 : DATA_WIDTH'((sum_ir + Q_MINUS_1) >>> QUANT_BITS);

    // Twiddle product
    assign v_real = dq_rr - dq_ii;
    assign v_imag = dq_ri + dq_ir;

    // Butterfly outputs
    assign y1_real = x1_real + v_real;
    assign y1_imag = x1_imag + v_imag;
    assign y2_real = x1_real - v_real;
    assign y2_imag = x1_imag - v_imag;

endmodule
