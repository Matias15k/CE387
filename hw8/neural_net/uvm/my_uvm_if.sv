import uvm_pkg::*;

interface my_uvm_if;
    logic                          clock;
    logic                          reset;
    // Input FIFO write interface
    logic                          in_full;
    logic                          in_wr_en;
    logic signed [DATA_WIDTH-1:0]  in_din;
    // Output FIFO read interface
    logic                          out_empty;
    logic                          out_rd_en;
    logic [3:0]                    out_dout;
    // Exposed monitoring signals
    logic signed [DATA_WIDTH-1:0]  layer0_out [NUM_L0_OUT];
    logic signed [DATA_WIDTH-1:0]  layer1_out [NUM_L1_OUT];
    logic [3:0]                    predicted_digit;
    logic                          inference_done;
endinterface
