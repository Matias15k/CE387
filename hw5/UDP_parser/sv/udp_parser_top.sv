
module udp_parser_top (
    input  logic        clock,
    input  logic        reset,
    output logic        in_full,
    input  logic        in_wr_en,
    input  logic [7:0]  in_din,
    input  logic        in_wr_sof,
    input  logic        in_wr_eof,
    output logic        out_empty,
    input  logic        out_rd_en,
    output logic [7:0]  out_dout,
    output logic        out_rd_sof,
    output logic        out_rd_eof
);

    // Internal signals between input FIFO and parser
    logic [7:0] in_fifo_dout;
    logic       in_fifo_empty;
    logic       in_fifo_rd_en;
    logic       in_fifo_rd_sof;
    logic       in_fifo_rd_eof;

    // Internal signals between parser and output FIFO
    logic [7:0] out_fifo_din;
    logic       out_fifo_full;
    logic       out_fifo_wr_en;
    logic       out_fifo_wr_sof;
    logic       out_fifo_wr_eof;

    // Input FIFO with SOF/EOF control
    fifo_ctrl #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(2048)
    ) fifo_in (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(in_wr_en),
        .wr_data(in_din),
        .wr_sof(in_wr_sof),
        .wr_eof(in_wr_eof),
        .full(in_full),
        .rd_clk(clock),
        .rd_en(in_fifo_rd_en),
        .rd_data(in_fifo_dout),
        .rd_sof(in_fifo_rd_sof),
        .rd_eof(in_fifo_rd_eof),
        .empty(in_fifo_empty)
    );

    // UDP Parser FSM
    udp_parser udp_parser_inst (
        .clock(clock),
        .reset(reset),
        .in_rd_en(in_fifo_rd_en),
        .in_empty(in_fifo_empty),
        .in_dout(in_fifo_dout),
        .in_sof(in_fifo_rd_sof),
        .in_eof(in_fifo_rd_eof),
        .out_wr_en(out_fifo_wr_en),
        .out_full(out_fifo_full),
        .out_din(out_fifo_din),
        .out_wr_sof(out_fifo_wr_sof),
        .out_wr_eof(out_fifo_wr_eof)
    );

    // Output FIFO with SOF/EOF control
    fifo_ctrl #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(2048)
    ) fifo_out (
        .reset(reset),
        .wr_clk(clock),
        .wr_en(out_fifo_wr_en),
        .wr_data(out_fifo_din),
        .wr_sof(out_fifo_wr_sof),
        .wr_eof(out_fifo_wr_eof),
        .full(out_fifo_full),
        .rd_clk(clock),
        .rd_en(out_rd_en),
        .rd_data(out_dout),
        .rd_sof(out_rd_sof),
        .rd_eof(out_rd_eof),
        .empty(out_empty)
    );

endmodule
