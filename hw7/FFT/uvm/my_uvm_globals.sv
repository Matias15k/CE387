`ifndef __GLOBALS__
`define __GLOBALS__

// FFT parameters
localparam int FFT_N          = 16;
localparam int DATA_WIDTH     = 32;
localparam int FIFO_DEPTH     = 16;
localparam int QUANT_BITS     = 14;
localparam int NUM_STAGES     = $clog2(FFT_N);   // 4
localparam int CLOCK_PERIOD   = 10;               // 100 MHz -> 10 ns

// Reference file names (placed in sim directory)
localparam string FFT_IN_REAL_NAME  = "fft_in_real.txt";
localparam string FFT_IN_IMAG_NAME  = "fft_in_imag.txt";
localparam string FFT_OUT_REAL_NAME = "fft_out_real.txt";
localparam string FFT_OUT_IMAG_NAME = "fft_out_imag.txt";

`endif
