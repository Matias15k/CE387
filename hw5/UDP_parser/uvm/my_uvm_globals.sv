`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string PCAP_FILE_NAME    = "test.pcap";
localparam string CMP_OUTPUT_NAME   = "test_output.txt";
localparam string SIM_OUTPUT_NAME   = "output.txt";
localparam int    PCAP_GLOBAL_HDR   = 24;
localparam int    PCAP_PKT_HDR      = 16;
localparam int    CLOCK_PERIOD      = 10;
localparam int    MAX_PKT_SIZE      = 2048;

`endif
