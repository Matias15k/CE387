// Edge detection top module
// Pipeline: Input FIFO -> Grayscale -> FIFO -> Sobel -> Output FIFO

module edge_detection_top #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_full,
    input  logic        in_wr_en,
    input  logic [23:0] in_din,
    output logic        out_empty,
    input  logic        out_rd_en,
    output logic [7:0]  out_dout
);

    // Grayscale interface
    logic [23:0] gs_in_dout;
    logic        gs_in_empty;
    logic        gs_in_rd_en;
    logic [7:0]  gs_out_din;
    logic        gs_out_full;
    logic        gs_out_wr_en;

    // Sobel interface
    logic [7:0]  sobel_in_dout;
    logic        sobel_in_empty;
    logic        sobel_in_rd_en;
    logic [7:0]  sobel_out_din;
    logic        sobel_out_full;
    logic        sobel_out_wr_en;

    // Input FIFO (24-bit RGB)
    fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(24)
    ) fifo_in_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(in_wr_en),
        .din(in_din),
        .full(in_full),
        .rd_clk(clock),
        .rd_en(gs_in_rd_en),
        .dout(gs_in_dout),
        .empty(gs_in_empty)
    );

    // Grayscale conversion
    grayscale grayscale_inst (
        .clock(clock),
        .reset(reset),
        .in_dout(gs_in_dout),
        .in_rd_en(gs_in_rd_en),
        .in_empty(gs_in_empty),
        .out_din(gs_out_din),
        .out_full(gs_out_full),
        .out_wr_en(gs_out_wr_en)
    );

    // Mid FIFO (8-bit grayscale)
    fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(8)
    ) fifo_mid_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(gs_out_wr_en),
        .din(gs_out_din),
        .full(gs_out_full),
        .rd_clk(clock),
        .rd_en(sobel_in_rd_en),
        .dout(sobel_in_dout),
        .empty(sobel_in_empty)
    );

    // Sobel filter
    sobel #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) sobel_inst (
        .clock(clock),
        .reset(reset),
        .in_dout(sobel_in_dout),
        .in_rd_en(sobel_in_rd_en),
        .in_empty(sobel_in_empty),
        .out_din(sobel_out_din),
        .out_full(sobel_out_full),
        .out_wr_en(sobel_out_wr_en)
    );

    // Output FIFO (8-bit sobel)
    fifo #(
        .FIFO_BUFFER_SIZE(256),
        .FIFO_DATA_WIDTH(8)
    ) fifo_out_inst (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(sobel_out_wr_en),
        .din(sobel_out_din),
        .full(sobel_out_full),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .dout(out_dout),
        .empty(out_empty)
    );

endmodule
