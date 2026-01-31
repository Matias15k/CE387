`timescale 1 ns / 1 ns

module motion_detect_tb;

    // --- Configuration ---
    localparam string BASE_IN_NAME   = "base.bmp";
    localparam string PED_IN_NAME    = "pedestrians.bmp";
    
    // Golden References (from C code)
    localparam string GOLD_OUT_NAME  = "img_out.bmp";
    localparam string GOLD_BASE_GS   = "base_grayscale.bmp";
    localparam string GOLD_IMG_GS    = "img_grayscale.bmp";
    localparam string GOLD_MASK      = "img_mask.bmp";

    // Simulation Outputs
    localparam string SIM_OUT_NAME   = "sim_out.bmp";
    localparam string SIM_BASE_GS    = "sim_base_gs.bmp";
    localparam string SIM_IMG_GS     = "sim_img_gs.bmp";
    localparam string SIM_MASK       = "sim_mask.bmp";

    localparam CLOCK_PERIOD = 10;
    localparam WIDTH = 768;
    localparam HEIGHT = 576;
    localparam BMP_HEADER_SIZE = 54;
    localparam BYTES_PER_PIXEL = 3; // 24-bit color
    localparam BMP_DATA_SIZE = WIDTH * HEIGHT * BYTES_PER_PIXEL;
    localparam TOTAL_PIXELS = WIDTH * HEIGHT;

    // --- Signals ---
    logic clock = 1'b1;
    logic reset = '0;
    
    // Inputs to DUT
    logic        bg_full, fr_full;
    logic        bg_wr_en = '0, fr_wr_en = '0;
    logic [23:0] bg_din = '0, fr_din = '0;
    
    // Outputs from DUT
    logic        out_empty;
    logic        out_rd_en = '0;
    logic [23:0] out_dout;

    // Error Counters
    integer err_final = 0;
    integer err_base_gs = 0;
    integer err_img_gs = 0;
    integer err_mask = 0;

    // Completion Flags
    logic inputs_done = 0;
    logic out_done = 0;
    logic base_gs_done = 0;
    logic img_gs_done = 0;
    logic mask_done = 0;

    // --- Clock Generation ---
    always begin
        clock = 1'b1;
        #(CLOCK_PERIOD/2);
        clock = 1'b0;
        #(CLOCK_PERIOD/2);
    end

    // --- DUT Instantiation ---
    motion_detect_top #(
        .DATA_WIDTH(24),
        .FIFO_DEPTH(64)
    ) dut (
        .clock(clock),
        .reset(reset),
        .bg_full(bg_full),
        .bg_wr_en(bg_wr_en),
        .bg_din(bg_din),
        .fr_full(fr_full),
        .fr_wr_en(fr_wr_en),
        .fr_din(fr_din),
        .out_empty(out_empty),
        .out_rd_en(out_rd_en),
        .out_dout(out_dout)
    );

    // --- Main Control Block ---
    initial begin
        longint unsigned start_time, end_time;

        // Reset Sequence
        @(posedge clock);
        reset = 1'b1;
        @(posedge clock);
        reset = 1'b0;
        
        start_time = $time;
        $display("@ %0t: Simulation Started.", start_time);

        // Wait for all verification processes to finish
        wait(out_done && base_gs_done && img_gs_done && mask_done);
        
        end_time = $time;
        $display("@ %0t: Simulation Completed.", end_time);
        $display("Total Cycles: %0d", (end_time - start_time) / CLOCK_PERIOD);
        $display("Errors - Final Output: %0d", err_final);
        $display("Errors - Base Grayscale: %0d", err_base_gs);
        $display("Errors - Img Grayscale:  %0d", err_img_gs);
        $display("Errors - Mask:           %0d", err_mask);
        
        if (err_final + err_base_gs + err_img_gs + err_mask == 0)
            $display("SUCCESS: All outputs match references!");
        else
            $display("FAILURE: Errors detected.");
        $finish;
    end

    // -----------------------------------------------------------------------
    // PROCESS 1: Input Driver (Reads Base & Pedestrian BMPs)
    // -----------------------------------------------------------------------
    initial begin : img_read_process
        int i, r;
        int file_base, file_ped;
        logic [7:0] header_dump [0:BMP_HEADER_SIZE-1];

        @(negedge reset);
        
        file_base = $fopen(BASE_IN_NAME, "rb");
        file_ped  = $fopen(PED_IN_NAME, "rb");

        if (!file_base || !file_ped) begin
            $display("Error: Could not open input files!");
            $stop;
        end

        // Skip Headers (we assume 54 bytes)
        r = $fread(header_dump, file_base, 0, BMP_HEADER_SIZE);
        r = $fread(header_dump, file_ped,  0, BMP_HEADER_SIZE);

        $display("Feeding inputs...");

        i = 0;
        while (i < BMP_DATA_SIZE) begin
            @(negedge clock);
            bg_wr_en = 1'b0;
            fr_wr_en = 1'b0;

            // Only write if BOTH FIFOs have space (simplifies synchronization)
            if (!bg_full && !fr_full) begin
                // Read 3 bytes (B, G, R) into the 24-bit bus
                // Note: SystemVerilog $fread on 24-bit logic reads big-endian by default on some tools,
                // but BMP is Little Endian. Usually requires byte swapping if strict BGR order matters.
                // For this testbench, we treat 24-bits as a chunk.
                r = $fread(bg_din, file_base, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
                r = $fread(fr_din, file_ped,  BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
                
                bg_wr_en = 1'b1;
                fr_wr_en = 1'b1;
                i += BYTES_PER_PIXEL;
            end
        end

        @(negedge clock);
        bg_wr_en = 1'b0;
        fr_wr_en = 1'b0;
        $fclose(file_base);
        $fclose(file_ped);
        inputs_done = 1'b1;
    end

    // -----------------------------------------------------------------------
    // PROCESS 2: Final Output Monitor (Compare vs img_out.bmp)
    // -----------------------------------------------------------------------
    initial begin : output_check_process
        int i, r;
        int file_gold, file_sim;
        logic [23:0] gold_data;
        logic [7:0] header [0:BMP_HEADER_SIZE-1];

        @(negedge reset);
        
        file_gold = $fopen(GOLD_OUT_NAME, "rb");
        file_sim  = $fopen(SIM_OUT_NAME, "wb");

        // Copy Header from Golden to Sim Output
        r = $fread(header, file_gold, 0, BMP_HEADER_SIZE);
        for (i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(file_sim, "%c", header[i]);

        i = 0;
        while (i < BMP_DATA_SIZE) begin
            @(negedge clock);
            out_rd_en = 1'b0;

            if (!out_empty) begin
                // Read Golden Pixel
                r = $fread(gold_data, file_gold, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
                
                // Write Simulation Pixel (splitting 24-bit logic into 3 bytes for file)
                $fwrite(file_sim, "%c%c%c", out_dout[23:16], out_dout[15:8], out_dout[7:0]);

                // Compare
                if (out_dout !== gold_data) begin
                    if (err_final < 10) // Limit error printout
                        $display("Error (Final) @ Pixel %0d: Expected %h, Got %h", i/3, gold_data, out_dout);
                    err_final++;
                end

                out_rd_en = 1'b1;
                i += BYTES_PER_PIXEL;
            end
        end
        
        $fclose(file_gold);
        $fclose(file_sim);
        out_done = 1'b1;
    end

    // -----------------------------------------------------------------------
    // PROCESS 3: Spy on Base Grayscale (Internal Signal)
    // -----------------------------------------------------------------------
    initial begin : spy_base_gray
        int i, r;
        int file_gold, file_sim;
        logic [23:0] gold_pixel_24; // Grayscale BMPs are still 24-bit files
        logic [7:0]  gold_val_8;
        logic [7:0]  header [0:BMP_HEADER_SIZE-1];
        
        @(negedge reset);
        file_gold = $fopen(GOLD_BASE_GS, "rb");
        file_sim  = $fopen(SIM_BASE_GS, "wb");

        // Header
        r = $fread(header, file_gold, 0, BMP_HEADER_SIZE);
        for (i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(file_sim, "%c", header[i]);

        i = 0;
        while (i < TOTAL_PIXELS) begin
            @(negedge clock);
            // HIERARCHICAL REFERENCE to internal write enable
            if (dut.gray_bg_wr_en) begin
                // Read Golden (read 3 bytes, take one since R=G=B)
                r = $fread(gold_pixel_24, file_gold, BMP_HEADER_SIZE + (i*3), 3);
                gold_val_8 = gold_pixel_24[7:0]; // Take Blue byte (or any)

                // Write Sim (replicate 8-bit internal val to R,G,B)
                $fwrite(file_sim, "%c%c%c", dut.gray_bg_dout, dut.gray_bg_dout, dut.gray_bg_dout);

                if (dut.gray_bg_dout !== gold_val_8) begin
                    if (err_base_gs < 10) 
                        $display("Error (BaseGS) @ Pixel %0d: Expected %h, Got %h", i, gold_val_8, dut.gray_bg_dout);
                    err_base_gs++;
                end
                i++;
            end
        end
        $fclose(file_gold);
        $fclose(file_sim);
        base_gs_done = 1'b1;
    end

    // -----------------------------------------------------------------------
    // PROCESS 4: Spy on Frame Grayscale (Internal Signal)
    // -----------------------------------------------------------------------
    initial begin : spy_img_gray
        int i, r;
        int file_gold, file_sim;
        logic [23:0] gold_pixel_24;
        logic [7:0]  gold_val_8;
        logic [7:0]  header [0:BMP_HEADER_SIZE-1];
        
        @(negedge reset);
        file_gold = $fopen(GOLD_IMG_GS, "rb");
        file_sim  = $fopen(SIM_IMG_GS, "wb");

        r = $fread(header, file_gold, 0, BMP_HEADER_SIZE);
        for (i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(file_sim, "%c", header[i]);

        i = 0;
        while (i < TOTAL_PIXELS) begin
            @(negedge clock);
            if (dut.gray_fr_wr_en) begin
                r = $fread(gold_pixel_24, file_gold, BMP_HEADER_SIZE + (i*3), 3);
                gold_val_8 = gold_pixel_24[7:0];

                $fwrite(file_sim, "%c%c%c", dut.gray_fr_dout, dut.gray_fr_dout, dut.gray_fr_dout);

                if (dut.gray_fr_dout !== gold_val_8) begin
                    if (err_img_gs < 10)
                        $display("Error (ImgGS) @ Pixel %0d: Expected %h, Got %h", i, gold_val_8, dut.gray_fr_dout);
                    err_img_gs++;
                end
                i++;
            end
        end
        $fclose(file_gold);
        $fclose(file_sim);
        img_gs_done = 1'b1;
    end

    // -----------------------------------------------------------------------
    // PROCESS 5: Spy on Mask (Internal Signal)
    // -----------------------------------------------------------------------
    initial begin : spy_mask
        int i, r;
        int file_gold, file_sim;
        logic [23:0] gold_pixel_24;
        logic [7:0]  gold_val_8;
        logic [7:0]  header [0:BMP_HEADER_SIZE-1];
        
        @(negedge reset);
        file_gold = $fopen(GOLD_MASK, "rb");
        file_sim  = $fopen(SIM_MASK, "wb");

        r = $fread(header, file_gold, 0, BMP_HEADER_SIZE);
        for (i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(file_sim, "%c", header[i]);

        i = 0;
        while (i < TOTAL_PIXELS) begin
            @(negedge clock);
            if (dut.mask_wr_en) begin
                r = $fread(gold_pixel_24, file_gold, BMP_HEADER_SIZE + (i*3), 3);
                gold_val_8 = gold_pixel_24[7:0];

                $fwrite(file_sim, "%c%c%c", dut.mask_dout, dut.mask_dout, dut.mask_dout);

                if (dut.mask_dout !== gold_val_8) begin
                    if (err_mask < 10)
                        $display("Error (Mask) @ Pixel %0d: Expected %h, Got %h", i, gold_val_8, dut.mask_dout);
                    err_mask++;
                end
                i++;
            end
        end
        $fclose(file_gold);
        $fclose(file_sim);
        mask_done = 1'b1;
    end

endmodule