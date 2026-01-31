module motion_detect_top #(
    parameter DATA_WIDTH = 24,
    parameter FIFO_DEPTH = 1024
)(
    input  logic clock,
    input  logic reset,
    
    // Background Stream Input
    output logic bg_full,
    input  logic bg_wr_en,
    input  logic [DATA_WIDTH-1:0] bg_din,
    
    // Frame Stream Input
    output logic fr_full,
    input  logic fr_wr_en,
    input  logic [DATA_WIDTH-1:0] fr_din,
    
    // Final Output Stream
    output logic out_empty,
    input  logic out_rd_en,
    output logic [DATA_WIDTH-1:0] out_dout
);

    // --- Internal Signals ---
    
    // Background Path
    logic [23:0] bg_fifo_dout;
    logic bg_fifo_empty, bg_fifo_rd_en;
    logic [7:0] gray_bg_dout;
    logic gray_bg_wr_en, gray_bg_full;
    logic [7:0] gray_bg_fifo_dout;
    logic gray_bg_fifo_empty, gray_bg_fifo_rd_en;

    // Frame Processing Path (to Grayscale)
    logic [23:0] fr_proc_fifo_dout;
    logic fr_proc_fifo_empty, fr_proc_fifo_rd_en;
    logic [7:0] gray_fr_dout;
    logic gray_fr_wr_en, gray_fr_full;
    logic [7:0] gray_fr_fifo_dout;
    logic gray_fr_fifo_empty, gray_fr_fifo_rd_en;

    // Frame Copy Path (to Highlight)
    logic [23:0] fr_copy_fifo_dout;
    logic fr_copy_fifo_empty, fr_copy_fifo_rd_en;
    
    // Mask Path
    logic [7:0] mask_dout;
    logic mask_wr_en, mask_full;
    logic [7:0] mask_fifo_dout;
    logic mask_fifo_empty, mask_fifo_rd_en;
    
    // Final Output Path
    logic [23:0] final_din;
    logic final_wr_en, final_full;

    // --- Input Logic: Splitting Frame Stream ---
    // The frame input writes to TWO FIFOs simultaneously.
    // If either is full, we report full upstream.
    logic fr_proc_full, fr_copy_full;
    assign fr_full = fr_proc_full | fr_copy_full;
    
    // We only write if neither is full
    logic internal_fr_wr_en;
    assign internal_fr_wr_en = fr_wr_en & ~fr_full;


    // --- 1. FIFOs for Inputs ---

    fifo #(.FIFO_DATA_WIDTH(24), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_bg_in (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(bg_wr_en), .din(bg_din), .full(bg_full),
        .rd_en(bg_fifo_rd_en), .dout(bg_fifo_dout), .empty(bg_fifo_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(24), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_fr_proc (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(internal_fr_wr_en), .din(fr_din), .full(fr_proc_full),
        .rd_en(fr_proc_fifo_rd_en), .dout(fr_proc_fifo_dout), .empty(fr_proc_fifo_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(24), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_fr_copy (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(internal_fr_wr_en), .din(fr_din), .full(fr_copy_full),
        .rd_en(fr_copy_fifo_rd_en), .dout(fr_copy_fifo_dout), .empty(fr_copy_fifo_empty)
    );


    // --- 2. Grayscale Modules ---

    grayscale bg_gray_inst (
        .clock(clock), .reset(reset),
        .in_dout(bg_fifo_dout), .in_empty(bg_fifo_empty), .in_rd_en(bg_fifo_rd_en),
        .out_din(gray_bg_dout), .out_full(gray_bg_full), .out_wr_en(gray_bg_wr_en)
    );

    grayscale fr_gray_inst (
        .clock(clock), .reset(reset),
        .in_dout(fr_proc_fifo_dout), .in_empty(fr_proc_fifo_empty), .in_rd_en(fr_proc_fifo_rd_en),
        .out_din(gray_fr_dout), .out_full(gray_fr_full), .out_wr_en(gray_fr_wr_en)
    );


    // --- 3. FIFOs after Grayscale (Buffers for Subtraction) ---

    fifo #(.FIFO_DATA_WIDTH(8), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_gray_bg (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(gray_bg_wr_en), .din(gray_bg_dout), .full(gray_bg_full),
        .rd_en(gray_bg_fifo_rd_en), .dout(gray_bg_fifo_dout), .empty(gray_bg_fifo_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(8), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_gray_fr (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(gray_fr_wr_en), .din(gray_fr_dout), .full(gray_fr_full),
        .rd_en(gray_fr_fifo_rd_en), .dout(gray_fr_fifo_dout), .empty(gray_fr_fifo_empty)
    );


    // --- 4. Subtract Background Module ---

    subtract_background #(.THRESHOLD(50)) sub_inst (
        .clock(clock), .reset(reset),
        .bg_dout(gray_bg_fifo_dout), .bg_empty(gray_bg_fifo_empty), .bg_rd_en(gray_bg_fifo_rd_en),
        .fr_dout(gray_fr_fifo_dout), .fr_empty(gray_fr_fifo_empty), .fr_rd_en(gray_fr_fifo_rd_en),
        .mask_din(mask_dout), .mask_full(mask_full), .mask_wr_en(mask_wr_en)
    );


    // --- 5. FIFO for Mask ---

    fifo #(.FIFO_DATA_WIDTH(8), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_mask (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(mask_wr_en), .din(mask_dout), .full(mask_full),
        .rd_en(mask_fifo_rd_en), .dout(mask_fifo_dout), .empty(mask_fifo_empty)
    );


    // --- 6. Highlight Module ---

    highlight_image hl_inst (
        .clock(clock), .reset(reset),
        .orig_dout(fr_copy_fifo_dout), .orig_empty(fr_copy_fifo_empty), .orig_rd_en(fr_copy_fifo_rd_en),
        .mask_dout(mask_fifo_dout), .mask_empty(mask_fifo_empty), .mask_rd_en(mask_fifo_rd_en),
        .out_din(final_din), .out_full(final_full), .out_wr_en(final_wr_en)
    );


    // --- 7. Final Output FIFO ---

    fifo #(.FIFO_DATA_WIDTH(24), .FIFO_BUFFER_SIZE(FIFO_DEPTH)) 
    fifo_out (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(final_wr_en), .din(final_din), .full(final_full),
        .rd_en(out_rd_en), .dout(out_dout), .empty(out_empty)
    );

endmodule