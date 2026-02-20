import uvm_pkg::*;

interface my_uvm_if;
    logic        clock;
    logic        reset;
    // Input FIFO interface (32-bit radians)
    logic        in_full;
    logic        in_wr_en;
    logic [31:0] in_din;
    // Sin output FIFO interface (16-bit)
    logic        sin_empty;
    logic        sin_rd_en;
    logic [15:0] sin_dout;
    // Cos output FIFO interface (16-bit)
    logic        cos_empty;
    logic        cos_rd_en;
    logic [15:0] cos_dout;
endinterface
