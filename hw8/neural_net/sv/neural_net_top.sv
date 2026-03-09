module neural_net_top #(
    parameter DATA_WIDTH   = 32,
    parameter NUM_INPUTS   = 784,
    parameter NUM_L0_OUT   = 10,
    parameter NUM_L1_OUT   = 10,
    parameter BITS         = 14,
    parameter FIFO_DEPTH   = 16,
    parameter string WEIGHT_FILE0 = "layer_0_weights_biases.txt",
    parameter string WEIGHT_FILE1 = "layer_1_weights_biases.txt"
)(
    input  logic                          clock,
    input  logic                          reset,
    output logic                          in_full,
    input  logic                          in_wr_en,
    input  logic signed [DATA_WIDTH-1:0]  in_din,
    output logic                          out_empty,
    input  logic                          out_rd_en,
    output logic [3:0]                    out_dout,
    output logic signed [DATA_WIDTH-1:0]  layer0_out [NUM_L0_OUT],
    output logic signed [DATA_WIDTH-1:0]  layer1_out [NUM_L1_OUT],
    output logic [3:0]                    predicted_digit,
    output logic                          inference_done
);

    logic signed [DATA_WIDTH-1:0] fifo_in_dout;
    logic                         fifo_in_empty;
    logic                         fifo_in_rd_en;
    logic [3:0]                   fifo_out_din;
    logic                         fifo_out_full;
    logic                         fifo_out_wr_en;


    fifo #(
        .FIFO_BUFFER_SIZE (FIFO_DEPTH),
        .FIFO_DATA_WIDTH  (DATA_WIDTH)
    ) fifo_in (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (in_wr_en),
        .din    (in_din),
        .full   (in_full),
        .rd_clk (clock),
        .rd_en  (fifo_in_rd_en),
        .dout   (fifo_in_dout),
        .empty  (fifo_in_empty)
    );

    neural_net #(
        .DATA_WIDTH   (DATA_WIDTH),
        .NUM_INPUTS   (NUM_INPUTS),
        .NUM_L0_OUT   (NUM_L0_OUT),
        .NUM_L1_OUT   (NUM_L1_OUT),
        .BITS         (BITS),
        .WEIGHT_FILE0 (WEIGHT_FILE0),
        .WEIGHT_FILE1 (WEIGHT_FILE1)
    ) nn_core (
        .clock           (clock),
        .reset           (reset),
        .in_rd_en        (fifo_in_rd_en),
        .in_empty        (fifo_in_empty),
        .in_dout         (fifo_in_dout),
        .out_wr_en       (fifo_out_wr_en),
        .out_full        (fifo_out_full),
        .out_din         (fifo_out_din),
        .layer0_out      (layer0_out),
        .layer1_out      (layer1_out),
        .predicted_digit (predicted_digit),
        .inference_done  (inference_done)
    );

    fifo #(
        .FIFO_BUFFER_SIZE (FIFO_DEPTH),
        .FIFO_DATA_WIDTH  (4)
    ) fifo_out (
        .reset  (reset),
        .wr_clk (clock),
        .wr_en  (fifo_out_wr_en),
        .din    (fifo_out_din),
        .full   (fifo_out_full),
        .rd_clk (clock),
        .rd_en  (out_rd_en),
        .dout   (out_dout),
        .empty  (out_empty)
    );

endmodule
