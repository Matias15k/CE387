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

    // ----------------------------------------------------------------
    // 4-Phase FSM for Alignment
    // ----------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,   // Wait for data
        PRIME,  // Fill buffers, NO OUTPUT (Absorb latency)
        STEADY, // Read 1, Write 1 (Aligned Output)
        FLUSH   // Write remaining zeros (Restore file size)
    } state_t;

    state_t state, state_c;

    // Counters
    logic [10:0] x_cnt, x_cnt_c;
    logic [10:0] y_cnt, y_cnt_c;
    logic [10:0] flush_cnt, flush_cnt_c;

    // Line Buffers
    logic        lb0_wr_en;
    logic        lb0_rd_en;
    logic [7:0]  lb0_din;
    logic [7:0]  lb0_dout;
    logic        lb0_full, lb0_empty;

    logic        lb1_wr_en;
    logic        lb1_rd_en;
    logic [7:0]  lb1_din;
    logic [7:0]  lb1_dout;
    logic        lb1_full, lb1_empty;

    // Window & Math
    logic [7:0] window [2:0][2:0]; 
    logic [7:0] window_c [2:0][2:0];
    logic [7:0] sobel_out;

    // Constants
    // Latency is 1 full row + 1 pixel (to get center of 3x3 window)
    localparam LATENCY = WIDTH + 1;

    // --------------------------------------------------------
    // FIFO Instantiation
    // --------------------------------------------------------
    fifo #(.FIFO_DATA_WIDTH(8), .FIFO_BUFFER_SIZE(1024)) lb0 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb0_wr_en), .din(lb0_din), .full(lb0_full),
        .rd_en(lb0_rd_en), .dout(lb0_dout), .empty(lb0_empty)
    );

    fifo #(.FIFO_DATA_WIDTH(8), .FIFO_BUFFER_SIZE(1024)) lb1 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb1_wr_en), .din(lb1_din), .full(lb1_full),
        .rd_en(lb1_rd_en), .dout(lb1_dout), .empty(lb1_empty)
    );

    // --------------------------------------------------------
    // Sobel Computation Function (Combinational)
    // --------------------------------------------------------
    function logic [7:0] calc_sobel(logic [7:0] w[2:0][2:0]);
        int gx, gy, abs_gx, abs_gy, total;
        
        // Horizontal Mask (Gx)
        // -1  0  1
        // -2  0  2
        // -1  0  1
        gx = ($signed({1'b0, w[0][2]}) - $signed({1'b0, w[0][0]})) + 
             ($signed({1'b0, w[1][2]}) - $signed({1'b0, w[1][0]}) ) * 2 + 
             ($signed({1'b0, w[2][2]}) - $signed({1'b0, w[2][0]}));

        // Vertical Mask (Gy)
        //  -1 -2 -1
        //   0  0  0
        //   1  2  1
        gy = ($signed({1'b0, w[2][0]}) - $signed({1'b0, w[0][0]})) + 
             ($signed({1'b0, w[2][1]}) - $signed({1'b0, w[0][1]}) ) * 2 + 
             ($signed({1'b0, w[2][2]}) - $signed({1'b0, w[0][2]}));

        abs_gx = (gx < 0) ? -gx : gx;
        abs_gy = (gy < 0) ? -gy : gy;
        total = (abs_gx + abs_gy) / 2;
        
        if (total > 255) total = 255;
        return 8'(total);
    endfunction

    // --------------------------------------------------------
    // Sequential Logic
    // --------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            x_cnt     <= '0;
            y_cnt     <= '0;
            flush_cnt <= '0;
            for(int i=0; i<3; i++) for(int j=0; j<3; j++) window[i][j] <= '0;
        end else begin
            state     <= state_c;
            x_cnt     <= x_cnt_c;
            y_cnt     <= y_cnt_c;
            flush_cnt <= flush_cnt_c;
            window    <= window_c;
        end
    end

    // --------------------------------------------------------
    // Combinational Logic (FSM & Datapath)
    // --------------------------------------------------------
    always_comb begin
        // Defaults
        in_rd_en    = 0;
        out_wr_en   = 0;
        out_din     = 0;
        lb0_wr_en   = 0; lb0_din = 0; lb0_rd_en = 0;
        lb1_wr_en   = 0; lb1_din = 0; lb1_rd_en = 0;
        
        state_c     = state;
        x_cnt_c     = x_cnt;
        y_cnt_c     = y_cnt;
        flush_cnt_c = flush_cnt;
        window_c    = window;

        case (state)
            
            // -------------------------------------------------------
            // 1. IDLE: Wait for initial data
            // -------------------------------------------------------
            IDLE: begin
                if (!in_empty) state_c = PRIME;
            end

            // -------------------------------------------------------
            // 2. PRIME: Read 'LATENCY' pixels to fill buffers.
            //    DO NOT WRITE output yet.
            // -------------------------------------------------------
            PRIME: begin
                if (!in_empty && !lb0_full && !lb1_full) begin
                    // Read Input
                    in_rd_en = 1;
                    
                    // Shift Window
                    for(int i=0; i<3; i++) begin
                        window_c[i][0] = window[i][1];
                        window_c[i][1] = window[i][2];
                    end
                    window_c[2][2] = in_dout; // New pixel

                    // Manage Line Buffers (Store & Shift)
                    lb0_din = in_dout; 
                    lb0_wr_en = 1;

                    // Read from LB0 if we have enough data (Row 1)
                    if (y_cnt >= 1) begin
                        lb0_rd_en = 1;
                        window_c[1][2] = lb0_dout;
                        
                        lb1_din = lb0_dout;
                        lb1_wr_en = 1;
                    end
                    // Read from LB1 if we have enough data (Row 2)
                    if (y_cnt >= 2) begin
                        lb1_rd_en = 1;
                        window_c[0][2] = lb1_dout;
                    end

                    // Increment Counters
                    if (x_cnt == WIDTH - 1) begin
                        x_cnt_c = 0;
                        y_cnt_c = y_cnt + 1;
                    end else begin
                        x_cnt_c = x_cnt + 1;
                    end

                    // Check Transition
                    // We need to read LATENCY (WIDTH+1) pixels before we start writing
                    // Since counters start at 0, (y=1, x=1) is the (WIDTH+1)th pixel.
                    if (y_cnt == 1 && x_cnt == 1) begin
                        state_c = STEADY;
                    end
                end
            end

            // -------------------------------------------------------
            // 3. STEADY: Read 1, Compute, Write 1.
            //    Output is now aligned: Output[0] = Sobel(0,0)
            // -------------------------------------------------------
            STEADY: begin
                if (!in_empty && !out_full && !lb0_full && !lb1_full) begin
                    // --- READ SIDE ---
                    in_rd_en = 1;

                    for(int i=0; i<3; i++) begin
                        window_c[i][0] = window[i][1];
                        window_c[i][1] = window[i][2];
                    end
                    window_c[2][2] = in_dout;

                    lb0_din = in_dout; lb0_wr_en = 1;
                    lb0_rd_en = 1;     window_c[1][2] = lb0_dout;
                    lb1_din = lb0_dout; lb1_wr_en = 1;
                    lb1_rd_en = 1;     window_c[0][2] = lb1_dout;

                    // --- COMPUTE SIDE ---
                    // Compute Sobel on the *current* window
                    // We need to border check based on OUTPUT coordinates.
                    // Since we shifted the stream, the current window produces
                    // the result for a pixel that is 1 row/col "behind" the input.
                    // But effectively, we just calculate on the valid window.
                    // The C-code sets borders to 0.
                    // The valid window for Sobel(y,x) is available now.
                    // We output 0 if the 'center' of the window (window[1][1]) is a border.
                    
                    // Actually, simpler logic:
                    // If we are in steady state, we are generating the image body.
                    // We just need to check if we are at the border of the *output* frame.
                    // But the FSM structure handles the top/left lag.
                    // We handle borders by checking if the *window center* is valid.
                    // The result of `calc_sobel` is valid.
                    
                    // Note: Borders (Row 0, Col 0) were processed during PRIME/STEADY transition?
                    // Actually, in Prime, we processed Input(0,0) to Input(1,1).
                    // The first output (now) corresponds to Input(1,1) -> Center(0,0).
                    // Center(0,0) is a border. So Output should be 0.
                    
                    // Logic:
                    // x_cnt, y_cnt track INPUT.
                    // Current Input is (y,x). Center is (y-1, x-1).
                    // We output result for (y-1, x-1).
                    // If (y-1) == 0 or (y-1) == H-1 or (x-1) == 0 or (x-1) == W-1: Output 0.
                    
                    if ((y_cnt - 1) == 0 || (y_cnt - 1) == HEIGHT - 1 || 
                        (x_cnt - 1) == 0 || (x_cnt - 1) == WIDTH - 1) begin
                        out_din = 8'h00;
                    end else begin
                        out_din = calc_sobel(window_c);
                    end
                    
                    out_wr_en = 1;

                    // --- COUNTERS ---
                    if (x_cnt == WIDTH - 1) begin
                        x_cnt_c = 0;
                        if (y_cnt == HEIGHT - 1) begin
                            // End of Input Image
                            state_c = FLUSH;
                            flush_cnt_c = 0;
                        end else begin
                            y_cnt_c = y_cnt + 1;
                        end
                    end else begin
                        x_cnt_c = x_cnt + 1;
                    end
                end
            end

            // -------------------------------------------------------
            // 4. FLUSH: Input is done. Write remaining zeros.
            //    Restore file size by writing 'LATENCY' zeros.
            // -------------------------------------------------------
            FLUSH: begin
                if (!out_full) begin
                    out_wr_en = 1;
                    out_din   = 8'h00; // Border padding at end of file

                    if (flush_cnt == LATENCY - 1) begin
                        state_c = IDLE;
                        flush_cnt_c = 0;
                        x_cnt_c = 0; y_cnt_c = 0;
                    end else begin
                        flush_cnt_c = flush_cnt + 1;
                    end
                end
            end
        endcase
    end

endmodule