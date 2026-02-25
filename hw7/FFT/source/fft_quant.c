#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

// quantization
#define BITS            14
#define QUANT_VAL       (1 << BITS)
#define QUANTIZE_F(f)   (int)(((float)(f) * (float)QUANT_VAL))
#define QUANTIZE_I(i)   (int)((int)(i) * (int)QUANT_VAL)
#define DEQUANTIZE_I(i)   (int)(((int)(i) + (QUANT_VAL/2)) / (int)QUANT_VAL)
#define DEQUANTIZE_F(i)   (float)((float)(i) / (float)QUANT_VAL)

#define PI 3.14159265358979323846

typedef struct {
    int real;
    int imag;
} Complex;


// Bit reversal
void bit_reversal(Complex *in, Complex *out, int N) 
{
    // Precompute bit-reversed indices for the range [0, N-1]
    int bit_reversal_table[N];
    for (int i = 0; i < N; i++) {
        int j = 0;
        for (int bit = 0; bit < log2(N); bit++) {
            if (i & (1 << bit)) {
                j |= (1 << ((int)log2(N) - bit - 1));
            }
        }
        bit_reversal_table[i] = j;
        //std::cout << (i == 0 ? "[" : ",") << bit_reversal_table[i] << (i == N-1 ? "]\n" : "");
    }

    // Use the precomputed table for reordering
    for (int i = 0; i < N; i++) {
        out[bit_reversal_table[i]] = in[i];
    }
}

// FFT stage operation (butterfly computation)
void butterfly(Complex *in1, Complex *in2, Complex *out1, Complex *out2, Complex w) 
{
    Complex v = { DEQUANTIZE_I(w.real * in2->real) - DEQUANTIZE_I(w.imag * in2->imag),
                  DEQUANTIZE_I(w.real * in2->imag) + DEQUANTIZE_I(w.imag * in2->real) };

    out1->real = in1->real + v.real;
    out1->imag = in1->imag + v.imag;
    out2->real = in1->real - v.real;
    out2->imag = in1->imag - v.imag;

    //printf("w.real = %08x w.imag = %08x\n", w.real, w.imag);
    //printf("v.real = %08x - %08x = %08x\n", DEQUANTIZE_I(w.real * in2->real), DEQUANTIZE_I(w.imag * in2->imag), v.real);
    //printf("v.imag = %08x + %08x = %08x\n", DEQUANTIZE_I(w.real * in2->imag), DEQUANTIZE_I(w.imag * in2->real), v.imag);
}

// FFT function with feed-forward memory allocation
void fft(Complex *in, Complex *out, int N) 
{
    const int NUM_STAGES = log2(N);
    const int TOTAL_SIZE = N * (NUM_STAGES + 1);
    Complex x[TOTAL_SIZE];
    Complex ctable[NUM_STAGES][N];

    // Stage 0: Bit-reversed input stored in stage 0 memory
    bit_reversal(in, x, N);

    //for (int i = 0; i < N; i++) printf("X[%d] = %08x + %08xj\n", i, x[i].real, x[i].imag);

    // FFT computation across stages
    for (int stage = 0; stage < NUM_STAGES; stage++) 
    {
        int step = 1 << (stage + 1);
        for (int i = 0; i < N; i += step) 
        {
            for (int j = 0; j < step / 2; j++) 
            {
                // Calculate read and write addresses for the current stage
                int read_offset = stage * N;
                int write_offset = (stage + 1) * N;
                int in1_idx = read_offset + i + j;
                int in2_idx = read_offset + i + j + step / 2;
                int out1_idx = write_offset + i + j;
                int out2_idx = write_offset + i + j + step / 2;

                // Calculate the twiddle factor
                float angle_step = -PI / (step / 2);
                float angle = j * angle_step;
                Complex w = {QUANTIZE_F(cos(angle)), QUANTIZE_F(sin(angle))};
                ctable[stage][j] = w;

                // Perform the FFT stage operation
                butterfly( &x[in1_idx], &x[in2_idx], &x[out1_idx], &x[out2_idx], w );
                
                /*
                printf("\nStage %d, i=%d, j=%d: "
                    "W = %08x + %08xj, "
                    "X[%d] = %08x + %08xj, "
                    "X[%d] = %08x + %08xj, "
                    "X[%d] = %08x + %08xj, "
                    "X[%d] = %08x + %08xj\n",
                    stage, i, j,
                    w.real, w.imag,
                    in1_idx, x[in1_idx].real, x[in1_idx].imag,
                    in2_idx, x[in2_idx].real, x[in2_idx].imag,
                    out1_idx, x[out1_idx].real, x[out1_idx].imag,
                    out2_idx, x[out2_idx].real, x[out2_idx].imag);
                */
            }
        }
    }

    /*
    // Print the twiddle factor table for SystemVerilog
    printf("localparam logic [0:%d][0:%d][0:1][31:0] ctable = {\n", NUM_STAGES - 1, N - 1);
    for (int i = 0; i < NUM_STAGES; i++) {
        printf("\t{");
        for (int j = 0; j < N; j++) {
            printf("%s{32'sh%08x,32'sh%08x}", (j == 0) ? "" : ", ", ctable[i][j].real, ctable[i][j].imag);
        }
        printf("}%s\n", (i == NUM_STAGES - 1) ? "" : ",");
    }
    printf("};\n");
    */
   
    // Copy final output 
    for (int i = 0; i < N; i++) {
        out[i] = x[NUM_STAGES * N + i];
    }
}

// Main function
int main() 
{
    int N = 16;
    Complex X[N];
    Complex Y[N];

    // Seed the random number generator
    srand(time(NULL));

    // Randomization scale factor (adjust to control noise level)
    double NOISE_SCALE = 0.05; 

    for (int i = 0; i < N; i++) 
    {
        double noise_real = ((rand() % 1000) / 1000.0 - 0.5) * NOISE_SCALE;
        double noise_imag = ((rand() % 1000) / 1000.0 - 0.5) * NOISE_SCALE;

        X[i].real = QUANTIZE_F(cos(2 * PI * i / N) + noise_real);  // Cosine wave + noise
        X[i].imag = QUANTIZE_F(sin(2 * PI * i / N) + noise_imag);  // Sine wave + noise
    }

    // write input to file
    FILE *fft_in_real = fopen("fft_in_real.txt", "w");
    FILE *fft_in_imag = fopen("fft_in_imag.txt", "w");
    for (int i = 0; i < N; i++) 
    {
        //fprintf(fft_in_real, "%.4f\n", DEQUANTIZE_F(X[i].real));
        //fprintf(fft_in_imag, "%.4f\n", DEQUANTIZE_F(X[i].imag));
        fprintf(fft_in_real, "%08x\n", X[i].real);
        fprintf(fft_in_imag, "%08x\n", X[i].imag);
    }
    fclose(fft_in_real);
    fclose(fft_in_imag);

    // run FFT
    fft(X, Y, N);

    // write output to file
    FILE *fft_out_real = fopen("fft_out_real.txt", "w");
    FILE *fft_out_imag = fopen("fft_out_imag.txt", "w");
    for (int i = 0; i < N; i++) 
    {
        //fprintf(fft_out_real, "%.4f\n", DEQUANTIZE_F(Y[i].real));
        //fprintf(fft_out_imag, "%.4f\n", DEQUANTIZE_F(Y[i].imag));
        fprintf(fft_out_real, "%08x\n", Y[i].real);
        fprintf(fft_out_imag, "%08x\n", Y[i].imag);
    }
    fclose(fft_out_real);
    fclose(fft_out_imag);

    return 0;
}