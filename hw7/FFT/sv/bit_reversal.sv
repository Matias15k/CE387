module bit_reversal #(
    parameter DATA_WIDTH = 32,
    parameter FFT_N      = 16
) (
    input  logic signed [DATA_WIDTH-1:0] in_real  [0:FFT_N-1],
    input  logic signed [DATA_WIDTH-1:0] in_imag  [0:FFT_N-1],
    output logic signed [DATA_WIDTH-1:0] out_real [0:FFT_N-1],
    output logic signed [DATA_WIDTH-1:0] out_imag [0:FFT_N-1]
);

    localparam NUM_BITS = $clog2(FFT_N);

    // Bit-reverse index computation at elaboration time
    function automatic integer bit_reverse(input integer idx, input integer nbits);
        integer result, b;
        result = 0;
        for (b = 0; b < nbits; b++) begin
            if (idx & (1 << b))
                result = result | (1 << (nbits - 1 - b));
        end
        return result;
    endfunction

    // Generate bit-reversed wiring
    genvar i;
    generate
        for (i = 0; i < FFT_N; i++) begin : gen_br
            localparam integer BR_IDX = bit_reverse(i, NUM_BITS);
            assign out_real[BR_IDX] = in_real[i];
            assign out_imag[BR_IDX] = in_imag[i];
        end
    endgenerate

endmodule
