module edge_detection_top #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
)(
    input  logic        clock,
    input  logic        reset,
    output logic        in_full,
    input  logic        in_wr_en,
    input  logic [23:0] in_din,
    output logic        out_empty,
    input  logic        out_rd_en,
    output logic [7:0]  out_dout
);

logic [23:0] rgb_dout;
logic        rgb_empty;
logic        rgb_rd_en;
logic [7:0]  gs_result;
logic        gs_wr_en;
logic        gs_full; 

// Between Sobel FIFO and Sobel Filter
logic [7:0]  sobel_in_dout;
logic        sobel_in_empty;
logic        sobel_in_rd_en;

// Between Sobel Filter and Output FIFO
logic [7:0]  final_edge_data;
logic        final_wr_en;
logic        final_full;


fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(24)
) fifo_rgb_in (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(in_din),
    .full(in_full),
    .rd_clk(clock),
    .rd_en(rgb_rd_en),
    .dout(rgb_dout),
    .empty(rgb_empty)
);

grayscale grayscale_inst (
    .clock(clock),
    .reset(reset),
    .in_dout(rgb_dout),
    .in_rd_en(rgb_rd_en),
    .in_empty(rgb_empty),
    .out_din(gs_result),
    .out_full(gs_full),
    .out_wr_en(gs_wr_en)
);


fifo #(
    .FIFO_BUFFER_SIZE(1024),
    .FIFO_DATA_WIDTH(8)
) fifo_gs_to_sobel (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(gs_wr_en),
    .din(gs_result),
    .full(gs_full),
    .rd_clk(clock),
    .rd_en(sobel_in_rd_en),
    .dout(sobel_in_dout),
    .empty(sobel_in_empty)
);

sobel_filter #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) sobel_inst (
    .clock(clock),
    .reset(reset),
    .in_dout(sobel_in_dout),
    .in_rd_en(sobel_in_rd_en),
    .in_empty(sobel_in_empty),
    .out_din(final_edge_data),
    .out_full(final_full),
    .out_wr_en(final_wr_en)
);

fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(8)
) fifo_out_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(final_wr_en),
    .din(final_edge_data),
    .full(final_full),
    .rd_clk(clock),
    .rd_en(out_rd_en),
    .dout(out_dout),
    .empty(out_empty)
);


endmodule