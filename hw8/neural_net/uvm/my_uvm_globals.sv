`ifndef __GLOBALS__
`define __GLOBALS__

// Neural Network Parameters
localparam int DATA_WIDTH   = 32;
localparam int NUM_INPUTS   = 784;
localparam int NUM_L0_OUT   = 10;
localparam int NUM_L1_OUT   = 10;
localparam int NUM_OUTPUTS  = 10;
localparam int BITS         = 14;
localparam int FIFO_DEPTH   = 16;

// File paths (relative to sim directory)
localparam string INPUT_FILE   = "x_test.txt";
localparam string LABEL_FILE   = "y_test.txt";
localparam string WEIGHT_FILE0 = "layer_0_weights_biases.txt";
localparam string WEIGHT_FILE1 = "layer_1_weights_biases.txt";

// Timing
localparam int CLOCK_PERIOD = 10;  // 100 MHz → 10 ns

`endif
