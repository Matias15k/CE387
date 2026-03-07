import uvm_pkg::*;

interface my_uvm_if;
    logic                   clock;
    logic                   reset;
    // Input FIFO ports
    logic                   in_full;
    logic                   in_wr_en;
    logic [DATA_WIDTH-1:0]  in_din;
    // Output FIFO ports
    logic                   out_empty;
    logic                   out_rd_en;
    logic [OUT_WIDTH-1:0]   out_dout;
endinterface
