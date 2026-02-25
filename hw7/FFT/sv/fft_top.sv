
module fft_top #(
    parameter DATA_WIDTH  = 32,
    parameter FFT_N       = 16,
    parameter FIFO_DEPTH  = 16,
    parameter QUANT_BITS  = 14
) (
    input  logic                          clock,
    input  logic                          reset,
    // External input interface (write side)
    output logic                          in_real_full,
    output logic                          in_imag_full,
    input  logic                          in_wr_en,
    input  logic signed [DATA_WIDTH-1:0]  in_real_din,
    input  logic signed [DATA_WIDTH-1:0]  in_imag_din,
    // External output interface (read side)
    output logic                          out_real_empty,
    output logic                          out_imag_empty,
    input  logic                          out_rd_en,
    output logic signed [DATA_WIDTH-1:0]  out_real_dout,
    output logic signed [DATA_WIDTH-1:0]  out_imag_dout
);

    // Internal signals between FIFOs and FFT core
    logic signed [DATA_WIDTH-1:0] in_real_dout_i;
    logic signed [DATA_WIDTH-1:0] in_imag_dout_i;
    logic                         in_real_empty_i;
    logic                         in_imag_empty_i;
    logic                         in_rd_en_i;

    logic signed [DATA_WIDTH-1:0] out_real_din_i;
    logic signed [DATA_WIDTH-1:0] out_imag_din_i;
    logic                         out_real_full_i;
    logic                         out_imag_full_i;
    logic                         out_wr_en_i;

    // Combined empty/full for lockstep operation
    logic in_empty_combined;
    logic out_full_combined;
    assign in_empty_combined = in_real_empty_i | in_imag_empty_i;
    assign out_full_combined = out_real_full_i  | out_imag_full_i;

    // -----------------------------------------------------------
    // FFT core
    // -----------------------------------------------------------
    fft #(
        .DATA_WIDTH(DATA_WIDTH),
        .FFT_N(FFT_N),
        .QUANT_BITS(QUANT_BITS)
    ) fft_inst (
        .clock(clock),
        .reset(reset),
        .in_rd_en(in_rd_en_i),
        .in_empty(in_empty_combined),
        .in_real_dout(in_real_dout_i),
        .in_imag_dout(in_imag_dout_i),
        .out_wr_en(out_wr_en_i),
        .out_full(out_full_combined),
        .out_real_din(out_real_din_i),
        .out_imag_din(out_imag_din_i)
    );

    // -----------------------------------------------------------
    // Input FIFO - Real
    // -----------------------------------------------------------
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_in_real (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(in_wr_en),
        .din(in_real_din),
        .full(in_real_full),
        .rd_clk(clock),
        .rd_en(in_rd_en_i),
        .dout(in_real_dout_i),
        .empty(in_real_empty_i)
    );

    // -----------------------------------------------------------
    // Input FIFO - Imaginary
    // -----------------------------------------------------------
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_in_imag (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(in_wr_en),
        .din(in_imag_din),
        .full(in_imag_full),
        .rd_clk(clock),
        .rd_en(in_rd_en_i),
        .dout(in_imag_dout_i),
        .empty(in_imag_empty_i)
    );

    // -----------------------------------------------------------
    // Output FIFO - Real
    // -----------------------------------------------------------
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_out_real (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(out_wr_en_i),
        .din(out_real_din_i),
        .full(out_real_full_i),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .dout(out_real_dout),
        .empty(out_real_empty)
    );

    // -----------------------------------------------------------
    // Output FIFO - Imaginary
    // -----------------------------------------------------------
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_out_imag (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(out_wr_en_i),
        .din(out_imag_din_i),
        .full(out_imag_full_i),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .dout(out_imag_dout),
        .empty(out_imag_empty)
    );

endmodule
