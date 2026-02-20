
module cordic_top #(
    parameter FIFO_DEPTH = 16
) (
    input  logic        clock,
    input  logic        reset,
    // Input interface (32-bit radians)
    output logic        in_full,
    input  logic        in_wr_en,
    input  logic [31:0] in_din,
    // Sin output interface (16-bit)
    output logic        sin_empty,
    input  logic        sin_rd_en,
    output logic [15:0] sin_dout,
    // Cos output interface (16-bit)
    output logic        cos_empty,
    input  logic        cos_rd_en,
    output logic [15:0] cos_dout
);

    // Internal wires between cordic core and FIFOs
    logic [31:0] in_fifo_dout;
    logic        in_fifo_empty;
    logic        in_fifo_rd_en;

    logic [15:0] sin_fifo_din;
    logic        sin_fifo_full;
    logic        sin_fifo_wr_en;

    logic [15:0] cos_fifo_din;
    logic        cos_fifo_full;
    logic        cos_fifo_wr_en;

    // =========================================================================
    // Input FIFO: 32-bit wide, FIFO_DEPTH deep
    // =========================================================================
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(32)
    ) fifo_in_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(in_wr_en),
        .din(in_din),
        .full(in_full),
        .rd_clk(clock),
        .rd_en(in_fifo_rd_en),
        .dout(in_fifo_dout),
        .empty(in_fifo_empty)
    );

    // =========================================================================
    // CORDIC core (16-stage pipeline)
    // =========================================================================
    cordic cordic_inst (
        .clock(clock),
        .reset(reset),
        .in_rd_en(in_fifo_rd_en),
        .in_empty(in_fifo_empty),
        .in_dout(in_fifo_dout),
        .sin_wr_en(sin_fifo_wr_en),
        .sin_full(sin_fifo_full),
        .sin_din(sin_fifo_din),
        .cos_wr_en(cos_fifo_wr_en),
        .cos_full(cos_fifo_full),
        .cos_din(cos_fifo_din)
    );

    // =========================================================================
    // Sin output FIFO: 16-bit wide, FIFO_DEPTH deep
    // =========================================================================
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(16)
    ) fifo_sin_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(sin_fifo_wr_en),
        .din(sin_fifo_din),
        .full(sin_fifo_full),
        .rd_clk(clock),
        .rd_en(sin_rd_en),
        .dout(sin_dout),
        .empty(sin_empty)
    );

    // =========================================================================
    // Cos output FIFO: 16-bit wide, FIFO_DEPTH deep
    // =========================================================================
    fifo #(
        .FIFO_BUFFER_SIZE(FIFO_DEPTH),
        .FIFO_DATA_WIDTH(16)
    ) fifo_cos_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(cos_fifo_wr_en),
        .din(cos_fifo_din),
        .full(cos_fifo_full),
        .rd_clk(clock),
        .rd_en(cos_rd_en),
        .dout(cos_dout),
        .empty(cos_empty)
    );

endmodule
