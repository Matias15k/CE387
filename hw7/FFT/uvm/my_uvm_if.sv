import uvm_pkg::*;

interface my_uvm_if;
    logic                          clock;
    logic                          reset;
    // Input side (write to input FIFOs)
    logic                          in_real_full;
    logic                          in_imag_full;
    logic                          in_wr_en;
    logic signed [DATA_WIDTH-1:0]  in_real_din;
    logic signed [DATA_WIDTH-1:0]  in_imag_din;
    // Output side (read from output FIFOs)
    logic                          out_real_empty;
    logic                          out_imag_empty;
    logic                          out_rd_en;
    logic signed [DATA_WIDTH-1:0]  out_real_dout;
    logic signed [DATA_WIDTH-1:0]  out_imag_dout;
endinterface
