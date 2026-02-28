module fft_top #(
    parameter DATA_WIDTH = 32,
    parameter FFT_N      = 16,
    parameter FIFO_DEPTH = 16,
    parameter QUANT_BITS = 14
) (
    input  logic                          clock,
    input  logic                          reset,
    // External write interface (input side)
    output logic                          in_real_full,
    output logic                          in_imag_full,
    input  logic                          in_wr_en,
    input  logic signed [DATA_WIDTH-1:0]  in_real_din,
    input  logic signed [DATA_WIDTH-1:0]  in_imag_din,
    // External read interface (output side)
    output logic                          out_real_empty,
    output logic                          out_imag_empty,
    input  logic                          out_rd_en,
    output logic signed [DATA_WIDTH-1:0]  out_real_dout,
    output logic signed [DATA_WIDTH-1:0]  out_imag_dout
);

    // Internal wires: input FIFOs -> FFT core
    logic signed [DATA_WIDTH-1:0] fifo_in_real_dout;
    logic signed [DATA_WIDTH-1:0] fifo_in_imag_dout;
    logic                         fifo_in_real_empty;
    logic                         fifo_in_imag_empty;
    logic                         fft_in_rd_en;

    // Internal wires: FFT core -> output FIFOs
    logic signed [DATA_WIDTH-1:0] fft_out_real_din;
    logic signed [DATA_WIDTH-1:0] fft_out_imag_din;
    logic                         fifo_out_real_full;
    logic                         fifo_out_imag_full;
    logic                         fft_out_wr_en;

    // Combined empty/full for lockstep FIFO operation
    logic in_empty_combined;
    logic out_full_combined;
    assign in_empty_combined = fifo_in_real_empty | fifo_in_imag_empty;
    assign out_full_combined = fifo_out_real_full  | fifo_out_imag_full;

    fft #(
        .DATA_WIDTH(DATA_WIDTH),
        .FFT_N(FFT_N),
        .QUANT_BITS(QUANT_BITS)
    ) fft_inst (
        .clock(clock),
        .reset(reset),
        .in_rd_en(fft_in_rd_en),
        .in_empty(in_empty_combined),
        .in_real_dout(fifo_in_real_dout),
        .in_imag_dout(fifo_in_imag_dout),
        .out_wr_en(fft_out_wr_en),
        .out_full(out_full_combined),
        .out_real_din(fft_out_real_din),
        .out_imag_din(fft_out_imag_din)
    );

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
        .rd_en(fft_in_rd_en),
        .dout(fifo_in_real_dout),
        .empty(fifo_in_real_empty)
    );

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
        .rd_en(fft_in_rd_en),
        .dout(fifo_in_imag_dout),
        .empty(fifo_in_imag_empty)
    );

    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_out_real (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(fft_out_wr_en),
        .din(fft_out_real_din),
        .full(fifo_out_real_full),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .dout(out_real_dout),
        .empty(out_real_empty)
    );

    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(DATA_WIDTH)
    ) fifo_out_imag (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(fft_out_wr_en),
        .din(fft_out_imag_din),
        .full(fifo_out_imag_full),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .dout(out_imag_dout),
        .empty(out_imag_empty)
    );

endmodule
