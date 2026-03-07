// =============================================================================
// neural_net_top.sv
// Top-level wrapper: input FIFO → neural_net → output FIFO
// Parameters match hw8 spec: DATA_WIDTH=32, FIFO_DEPTH=16
// =============================================================================

module neural_net_top #(
    parameter int    DATA_WIDTH  = 32,
    parameter int    NUM_INPUTS  = 784,
    parameter int    L0_NEURONS  = 10,
    parameter int    L1_NEURONS  = 10,
    parameter int    FIFO_DEPTH  = 16,
    parameter int    BITS        = 14,
    parameter int    ACC_WIDTH   = 64,
    parameter int    OUT_WIDTH   = 4,
    parameter string L0_FILE     = "layer_0_weights_biases.txt",
    parameter string L1_FILE     = "layer_1_weights_biases.txt"
)(
    input  logic                    clock,
    input  logic                    reset,
    // Input FIFO user interface
    output logic                    in_full,
    input  logic                    in_wr_en,
    input  logic [DATA_WIDTH-1:0]   in_din,
    // Output FIFO user interface
    output logic                    out_empty,
    input  logic                    out_rd_en,
    output logic [OUT_WIDTH-1:0]    out_dout
);

    // ---- Internal wires between neural_net and FIFOs --------------------
    logic [DATA_WIDTH-1:0] in_dout_w;
    logic                  in_empty_w;
    logic                  in_rd_en_w;

    logic [OUT_WIDTH-1:0]  out_din_w;
    logic                  out_full_w;
    logic                  out_wr_en_w;

    // ---- Input FIFO (32-bit wide) ----------------------------------------
    fifo #(
        .FIFO_DATA_WIDTH  (DATA_WIDTH),
        .FIFO_BUFFER_SIZE (FIFO_DEPTH)
    ) fifo_in_inst (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (in_wr_en),
        .din    (in_din),
        .full   (in_full),
        .rd_clk (clock),
        .rd_en  (in_rd_en_w),
        .dout   (in_dout_w),
        .empty  (in_empty_w)
    );

    // ---- Neural network core --------------------------------------------
    neural_net #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_INPUTS (NUM_INPUTS),
        .L0_NEURONS (L0_NEURONS),
        .L1_NEURONS (L1_NEURONS),
        .BITS       (BITS),
        .ACC_WIDTH  (ACC_WIDTH),
        .OUT_WIDTH  (OUT_WIDTH),
        .L0_FILE    (L0_FILE),
        .L1_FILE    (L1_FILE)
    ) nn_inst (
        .clock     (clock),
        .reset     (reset),
        .in_rd_en  (in_rd_en_w),
        .in_empty  (in_empty_w),
        .in_dout   (in_dout_w),
        .out_wr_en (out_wr_en_w),
        .out_full  (out_full_w),
        .out_din   (out_din_w)
    );

    // ---- Output FIFO (4-bit wide) ---------------------------------------
    fifo #(
        .FIFO_DATA_WIDTH  (OUT_WIDTH),
        .FIFO_BUFFER_SIZE (FIFO_DEPTH)
    ) fifo_out_inst (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (out_wr_en_w),
        .din    (out_din_w),
        .full   (out_full_w),
        .rd_clk (clock),
        .rd_en  (out_rd_en),
        .dout   (out_dout),
        .empty  (out_empty)
    );

endmodule
