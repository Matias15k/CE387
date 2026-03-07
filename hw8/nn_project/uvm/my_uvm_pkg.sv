package my_uvm_package;

import uvm_pkg::*;

// UVM macros and utilities
`include "uvm_macros.svh"

// Globals and parameters
`include "my_uvm_globals.sv"

// Transaction + Sequence (defines my_uvm_transaction, my_uvm_sequence,
// my_uvm_sequencer)
`include "my_uvm_sequence.sv"

// Monitor (defines my_uvm_monitor_output, my_uvm_monitor_compare)
`include "my_uvm_monitor.sv"

// Driver
`include "my_uvm_driver.sv"

// Agent
`include "my_uvm_agent.sv"

// Scoreboard
`include "my_uvm_scoreboard.sv"

// Coverage (must come after scoreboard so uvm_subscriber is known)
`include "my_uvm_coverage.sv"

// Configuration object
`include "my_uvm_config.sv"

// Environment
`include "my_uvm_env.sv"

// Test
`include "my_uvm_test.sv"

endpackage
