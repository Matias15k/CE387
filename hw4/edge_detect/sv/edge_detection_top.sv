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


// ----------------------------------------------------------------
    // DEBUG: Intermediate Grayscale Image Capture
    // ----------------------------------------------------------------
    // This block snoops the data leaving the grayscale module and 
    // writes it to a BMP file so you can view the intermediate stage.
    
    integer f_in, f_out, r_dbg;
    logic [7:0] bmp_header [0:53];

    initial begin
        // 1. Open the original input to steal the BMP Header (54 bytes)
        f_in = $fopen("copper_720_540.bmp", "rb");
        if (f_in == 0) $display("Error: Could not open copper_720_540.bmp for debug header");
        
        // 2. Open the new output file
        f_out = $fopen("intermediate_grayscale.bmp", "wb");
        
        // 3. Copy Header
        r_dbg = $fread(bmp_header, f_in, 0, 54);
        for(int i=0; i<54; i++) $fwrite(f_out, "%c", bmp_header[i]);
        
        $fclose(f_in);
    end

    // 4. Snoop the valid grayscale data
    always @(posedge clock) begin
        if (gs_wr_en) begin
            // Write 3 bytes (R=G=B) so standard image viewers recognize it as grayscale
            $fwrite(f_out, "%c%c%c", gs_result, gs_result, gs_result);
        end
    end

    // 5. Close file at end of simulation
    final begin
        $fclose(f_out);
    end


endmodule