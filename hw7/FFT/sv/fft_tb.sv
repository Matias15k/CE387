
`timescale 1 ns / 1 ns

module fft_tb;

localparam DATA_WIDTH  = 32;
localparam FFT_N       = 16;
localparam FIFO_DEPTH  = 16;
localparam QUANT_BITS  = 14;
localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;

logic                          in_real_full;
logic                          in_imag_full;
logic                          in_wr_en  = '0;
logic signed [DATA_WIDTH-1:0]  in_real_din = '0;
logic signed [DATA_WIDTH-1:0]  in_imag_din = '0;

logic                          out_real_empty;
logic                          out_imag_empty;
logic                          out_rd_en = '0;
logic signed [DATA_WIDTH-1:0]  out_real_dout;
logic signed [DATA_WIDTH-1:0]  out_imag_dout;

logic   in_write_done = '0;
logic   out_read_done = '0;
integer out_errors    = '0;

fft_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .FFT_N(FFT_N),
    .FIFO_DEPTH(FIFO_DEPTH),
    .QUANT_BITS(QUANT_BITS)
) fft_top_inst (
    .clock(clock),
    .reset(reset),
    .in_real_full(in_real_full),
    .in_imag_full(in_imag_full),
    .in_wr_en(in_wr_en),
    .in_real_din(in_real_din),
    .in_imag_din(in_imag_din),
    .out_real_empty(out_real_empty),
    .out_imag_empty(out_imag_empty),
    .out_rd_en(out_rd_en),
    .out_real_dout(out_real_dout),
    .out_imag_dout(out_imag_dout)
);

// Clock generation
always begin
    clock = 1'b1;
    #(CLOCK_PERIOD/2);
    clock = 1'b0;
    #(CLOCK_PERIOD/2);
end

// Reset
initial begin
    @(posedge clock);
    reset = 1'b1;
    @(posedge clock);
    reset = 1'b0;
end

// Main test process
initial begin : tb_process
    longint unsigned start_time, end_time;

    @(negedge reset);
    @(posedge clock);
    start_time = $time;

    $display("@ %0t: Beginning FFT simulation...", start_time);

    wait(out_read_done);
    end_time = $time;

    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total error count: %0d", out_errors);

    $finish;
end

// Input process: read from hex files and write to input FIFOs
initial begin : input_process
    int in_real_file, in_imag_file;
    int scan_r, scan_i;
    logic [DATA_WIDTH-1:0] val_real, val_imag;
    int i;

    @(negedge reset);
    $display("@ %0t: Loading input files...", $time);

    in_real_file = $fopen("fft_in_real.txt", "r");
    in_imag_file = $fopen("fft_in_imag.txt", "r");
    in_wr_en = 1'b0;

    i = 0;
    while (i < FFT_N) begin
        @(negedge clock);
        in_wr_en = 1'b0;
        if (in_real_full == 1'b0 && in_imag_full == 1'b0) begin
            scan_r = $fscanf(in_real_file, "%h", val_real);
            scan_i = $fscanf(in_imag_file, "%h", val_imag);
            in_real_din = $signed(val_real);
            in_imag_din = $signed(val_imag);
            in_wr_en = 1'b1;
            i++;
        end
    end

    @(negedge clock);
    in_wr_en = 1'b0;
    $fclose(in_real_file);
    $fclose(in_imag_file);
    in_write_done = 1'b1;
end

// Output process: read from output FIFOs and compare with reference
initial begin : output_process
    int ref_real_file, ref_imag_file;
    int scan_r, scan_i;
    logic [DATA_WIDTH-1:0] exp_real, exp_imag;
    int i;

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing FFT output...", $time);

    ref_real_file = $fopen("fft_out_real.txt", "r");
    ref_imag_file = $fopen("fft_out_imag.txt", "r");
    out_rd_en = 1'b0;

    i = 0;
    while (i < FFT_N) begin
        @(negedge clock);
        out_rd_en = 1'b0;
        if (out_real_empty == 1'b0 && out_imag_empty == 1'b0) begin
            scan_r = $fscanf(ref_real_file, "%h", exp_real);
            scan_i = $fscanf(ref_imag_file, "%h", exp_imag);

            if (out_real_dout != $signed(exp_real) || out_imag_dout != $signed(exp_imag)) begin
                out_errors++;
                $display("@ %0t: ERROR Y[%0d]: exp=(%08x,%08x) got=(%08x,%08x)",
                    $time, i, exp_real, exp_imag, out_real_dout, out_imag_dout);
            end else begin
                $display("@ %0t: PASS  Y[%0d]: (%08x,%08x)",
                    $time, i, out_real_dout, out_imag_dout);
            end

            out_rd_en = 1'b1;
            i++;
        end
    end

    @(negedge clock);
    out_rd_en = 1'b0;
    $fclose(ref_real_file);
    $fclose(ref_imag_file);
    out_read_done = 1'b1;
end

endmodule
