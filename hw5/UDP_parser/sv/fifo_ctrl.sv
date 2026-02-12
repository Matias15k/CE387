
module fifo_ctrl #(
    parameter FIFO_DATA_WIDTH = 8,
    parameter FIFO_BUFFER_SIZE = 1024
) (
    input  logic reset,
    input  logic wr_clk,
    input  logic wr_en,
    input  logic [FIFO_DATA_WIDTH-1:0] wr_data,
    input  logic wr_sof,
    input  logic wr_eof,
    output logic full,
    input  logic rd_clk,
    input  logic rd_en,
    output logic [FIFO_DATA_WIDTH-1:0] rd_data,
    output logic rd_sof,
    output logic rd_eof,
    output logic empty
);

    logic data_full, data_empty;
    logic ctrl_full, ctrl_empty;

    // 8-bit data FIFO
    fifo #(
        .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
        .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
    ) data_fifo (
        .reset(reset),
        .wr_clk(wr_clk),
        .wr_en(wr_en),
        .din(wr_data),
        .full(data_full),
        .rd_clk(rd_clk),
        .rd_en(rd_en),
        .dout(rd_data),
        .empty(data_empty)
    );

    // 2-bit control FIFO for {sof, eof}
    fifo #(
        .FIFO_DATA_WIDTH(2),
        .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
    ) ctrl_fifo (
        .reset(reset),
        .wr_clk(wr_clk),
        .wr_en(wr_en),
        .din({wr_sof, wr_eof}),
        .full(ctrl_full),
        .rd_clk(rd_clk),
        .rd_en(rd_en),
        .dout({rd_sof, rd_eof}),
        .empty(ctrl_empty)
    );

    // Both FIFOs are synchronized; use data FIFO status signals
    assign full  = data_full | ctrl_full;
    assign empty = data_empty | ctrl_empty;

endmodule
