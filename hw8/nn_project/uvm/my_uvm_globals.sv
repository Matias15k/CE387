`ifndef __NN_GLOBALS__
`define __NN_GLOBALS__

// File paths (relative to sim/ working directory)
localparam string INPUT_FILE   = "x_test.txt";
localparam string LABEL_FILE   = "y_test.txt";

// Neural network dimensions
localparam int NUM_INPUTS    = 784;
localparam int NUM_CLASSES   = 10;
localparam int DATA_WIDTH    = 32;
localparam int OUT_WIDTH     = 4;

// Testbench timing
localparam int CLOCK_PERIOD  = 10;   // 100 MHz → 10 ns period

// Latency measurement
localparam int LOAD_LATENCY  = NUM_INPUTS;          // cycles to load inputs
localparam int L0_LATENCY    = NUM_INPUTS + 3;      // compute + relu + wait cycles
localparam int L1_LATENCY    = NUM_CLASSES + 3;
localparam int TOTAL_LATENCY = LOAD_LATENCY + L0_LATENCY + L1_LATENCY + 4;

`endif
