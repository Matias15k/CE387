module sobel_filter #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
)(
    input  logic        clock,
    input  logic        reset,
    // Input Interface
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    // Output Interface
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

    // FSM States
    typedef enum logic [0:0] {s0, s1} state_types;
    state_types state, state_c;

    // Line Buffer Signals
    logic        lb0_wr_en, lb1_wr_en;
    logic        lb0_rd_en, lb1_rd_en;
    logic [7:0]  lb0_din,   lb1_din;
    logic [7:0]  lb0_dout,  lb1_dout;
    logic        lb0_full,  lb1_full;
    logic        lb0_empty, lb1_empty;

    // Pixel Counters
    logic [10:0] x_cnt, x_cnt_c;
    logic [10:0] y_cnt, y_cnt_c;

    // 3x3 Window: window[row][col]
    // window[0] is the oldest row (top), window[2] is newest (bottom)
    logic [7:0] window [2:0][2:0]; 
    logic [7:0] window_c [2:0][2:0];

    // Calculated Sobel Result
    logic [7:0] sobel_result;
    logic [7:0] output_reg, output_reg_c;
    logic       valid_data, valid_data_c; // To handle priming/borders

    // --------------------------------------------------------
    // Instantiate Line Buffers (FIFOs)
    // --------------------------------------------------------
    // Line Buffer 0: Stores Row N-1
    fifo #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(1024) // Must be > WIDTH
    ) lb0 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb0_wr_en), .din(lb0_din), .full(lb0_full),
        .rd_en(lb0_rd_en), .dout(lb0_dout), .empty(lb0_empty)
    );

    // Line Buffer 1: Stores Row N-2
    fifo #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(1024)
    ) lb1 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb1_wr_en), .din(lb1_din), .full(lb1_full),
        .rd_en(lb1_rd_en), .dout(lb1_dout), .empty(lb1_empty)
    );

    // --------------------------------------------------------
    // Sequential Logic (Flip-Flops)
    // --------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state      <= s0;
            x_cnt      <= '0;
            y_cnt      <= '0;
            output_reg <= '0;
            valid_data <= '0;
            for(int i=0; i<3; i++) begin
                for(int j=0; j<3; j++) window[i][j] <= '0;
            end
        end else begin
            state      <= state_c;
            x_cnt      <= x_cnt_c;
            y_cnt      <= y_cnt_c;
            output_reg <= output_reg_c;
            valid_data <= valid_data_c;
            window     <= window_c;
        end
    end

    // --------------------------------------------------------
    // Combinational Logic (FSM & Math)
    // --------------------------------------------------------
    // Variables for math calculation
    int gx, gy, abs_gx, abs_gy, total;

    always_comb begin
        // Defaults
        in_rd_en     = 1'b0;
        out_wr_en    = 1'b0;
        out_din      = output_reg; 
        
        lb0_wr_en    = 1'b0; 
        lb0_din      = 8'b0; 
        lb0_rd_en    = 1'b0;
        
        lb1_wr_en    = 1'b0; 
        lb1_din      = 8'b0; 
        lb1_rd_en    = 1'b0;

        state_c      = state;
        x_cnt_c      = x_cnt;
        y_cnt_c      = y_cnt;
        output_reg_c = output_reg;
        window_c     = window;
        valid_data_c = valid_data;

        case (state)
            s0: begin // PROCESS / READ STATE
                // We need input data AND space in our line buffers to proceed
                if (!in_empty && !lb0_full && !lb1_full) begin
                    
                    // 1. Shift Window Columns
                    // Move col 1 to 0, col 2 to 1 for all rows
                    for(int i=0; i<3; i++) begin
                        window_c[i][0] = window[i][1];
                        window_c[i][1] = window[i][2];
                    end

                    // 2. Read new pixel -> Bottom-Right of window (2,2)
                    in_rd_en = 1'b1;
                    window_c[2][2] = in_dout;

                    // 3. Manage Line Buffers
                    // Input pixel goes into LB0 (for next row usage)
                    lb0_din   = in_dout;
                    lb0_wr_en = 1'b1;

                    // LB0 feeds LB1 and Middle-Right of window (1,2)
                    // Only read if we have passed the first row
                    if (y_cnt > 0 || (y_cnt == 0 && x_cnt == WIDTH-1)) begin // Simplified logic check
                        // We actually read continuously once primed
                        // Ideally: if !lb0_empty
                    end
                    
                    // Explicit Read Logic based on Counters
                    // Row 0 is entering window[2]. 
                    // To get window[1], we need data from LB0.
                    if (y_cnt >= 1) begin
                        lb0_rd_en = 1'b1;
                        window_c[1][2] = lb0_dout;
                        
                        // Pass LB0 data to LB1
                        lb1_din   = lb0_dout;
                        lb1_wr_en = 1'b1;
                    end

                    // To get window[0], we need data from LB1.
                    if (y_cnt >= 2) begin
                        lb1_rd_en = 1'b1;
                        window_c[0][2] = lb1_dout;
                    end

                    // 4. Calculate Sobel (on the updated window 'window_c' effectively)
                    // Note: In this clock cycle, we just shifted in new data into col 2.
                    // The valid window for (x,y) is now in columns 0,1,2.
                    
                    // Default 0 for borders
                    output_reg_c = 8'h00;

                    // Boundary checks (C code: if y!=0 && x!=0 && y!=h-1 && x!=w-1)
                    // Note: Our counters track the *incoming* pixel. 
                    // The window center is at (x_cnt - 1, y_cnt - 1) if using simple stream counting.
                    // Due to line buffer latency, effectively:
                    // window[1][1] is the center pixel.
                    
                    if (y_cnt >= 2 && x_cnt >= 2 && x_cnt < WIDTH) begin
                        // Horizontal Mask (Gx)
                        // -1  0  1
                        // -2  0  2
                        // -1  0  1
                        gx = ($signed({1'b0, window_c[0][2]}) - $signed({1'b0, window_c[0][0]})) + 
                             ($signed({1'b0, window_c[1][2]}) - $signed({1'b0, window_c[1][0]}) ) * 2 + 
                             ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[2][0]}));

                        // Vertical Mask (Gy)
                        //  -1 -2 -1
                        //   0  0  0
                        //   1  2  1
                        gy = ($signed({1'b0, window_c[2][0]}) - $signed({1'b0, window_c[0][0]})) + 
                             ($signed({1'b0, window_c[2][1]}) - $signed({1'b0, window_c[0][1]}) ) * 2 + 
                             ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[0][2]}));

                        abs_gx = (gx < 0) ? -gx : gx;
                        abs_gy = (gy < 0) ? -gy : gy;
                        total = (abs_gx + abs_gy) / 2;

                        if (total > 255) total = 255;
                        output_reg_c = 8'(total);
                    end 
                    
                    // Note on border alignment:
                    // The C code sets borders to 0. Our logic naturally yields 0 
                    // until the window is fully populated (y >= 2).
                    // We must ensure we output exactly 1 pixel per input pixel to match stream rate.

                    // 5. Update Counters
                    if (x_cnt == WIDTH - 1) begin
                        x_cnt_c = 0;
                        if (y_cnt == HEIGHT - 1) y_cnt_c = 0;
                        else y_cnt_c = y_cnt + 1;
                    end else begin
                        x_cnt_c = x_cnt + 1;
                    end

                    // 6. Transition
                    valid_data_c = 1'b1; // We always produce a pixel (even if 0 at border)
                    state_c = s1;
                end
            end

            s1: begin // OUTPUT STATE
                if (!out_full) begin
                    if (valid_data) begin
                        out_din   = output_reg;
                        out_wr_en = 1'b1;
                    end
                    state_c = s0;
                end
            end
        endcase
    end

endmodule