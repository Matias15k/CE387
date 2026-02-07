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
    logic [7:0] output_reg, output_reg_c;
    logic       valid_data, valid_data_c;

    // --------------------------------------------------------
    // Instantiate Line Buffers (FIFOs)
    // --------------------------------------------------------
    // Line Buffer 0: Stores Row N-1 (Middle Row Source)
    fifo #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(1024) 
    ) lb0 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb0_wr_en), .din(lb0_din), .full(lb0_full),
        .rd_en(lb0_rd_en), .dout(lb0_dout), .empty(lb0_empty)
    );

    // Line Buffer 1: Stores Row N-2 (Top Row Source)
    fifo #(
        .FIFO_DATA_WIDTH(8),
        .FIFO_BUFFER_SIZE(1024)
    ) lb1 (
        .reset(reset), .wr_clk(clock), .rd_clk(clock),
        .wr_en(lb1_wr_en), .din(lb1_din), .full(lb1_full),
        .rd_en(lb1_rd_en), .dout(lb1_dout), .empty(lb1_empty)
    );

    // --------------------------------------------------------
    // Sequential Logic
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
    // Combinational Logic
    // --------------------------------------------------------
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
                // Proceed only if we have input data and space in line buffers
                if (!in_empty && !lb0_full && !lb1_full) begin
                    
                    // 1. Shift Window Columns Left
                    for(int i=0; i<3; i++) begin
                        window_c[i][0] = window[i][1];
                        window_c[i][1] = window[i][2];
                    end

                    // 2. Read New Pixel -> Bottom-Right (Row 2, Col 2)
                    in_rd_en = 1'b1;
                    window_c[2][2] = in_dout;

                    // 3. Write New Pixel to LB0 (to save for next row)
                    lb0_din   = in_dout;
                    lb0_wr_en = 1'b1;

                    // 4. Read from Line Buffers to populate Window
                    // Note: FIFOs in this design are "Show Ahead". 
                    // 'dout' is valid before 'rd_en' is asserted.
                    
                    // Row 1 (Middle) comes from LB0
                    if (y_cnt >= 1) begin
                        lb0_rd_en = 1'b1;           // Pop FIFO for next cycle
                        window_c[1][2] = lb0_dout;  // Capture current valid pixel
                        
                        // Pass Row 1 pixel to LB1 (to save for Top Row)
                        lb1_din   = lb0_dout;
                        lb1_wr_en = 1'b1;
                    end

                    // Row 0 (Top) comes from LB1
                    if (y_cnt >= 2) begin
                        lb1_rd_en = 1'b1;           // Pop FIFO for next cycle
                        window_c[0][2] = lb1_dout;  // Capture current valid pixel
                    end

                    // 5. Calculate Sobel
                    output_reg_c = 8'h00; // Default to black (0)

                    // Only compute valid Sobel if we are past the borders
                    // y_cnt=2 means we have Rows 0,1,2 in the window.
                    if (y_cnt >= 2 && x_cnt >= 2 && x_cnt < WIDTH - 1) begin
                        // Horizontal Mask (Gx)
                        // -1  0  1  (Row 0)
                        // -2  0  2  (Row 1)
                        // -1  0  1  (Row 2)
                        gx = ($signed({1'b0, window_c[0][2]}) - $signed({1'b0, window_c[0][0]})) + 
                             ($signed({1'b0, window_c[1][2]}) - $signed({1'b0, window_c[1][0]}) ) * 2 + 
                             ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[2][0]}));

                        // Vertical Mask (Gy)
                        //  -1 -2 -1 (Row 0)
                        //   0  0  0 (Row 1)
                        //   1  2  1 (Row 2)
                        gy = ($signed({1'b0, window_c[2][0]}) - $signed({1'b0, window_c[0][0]})) + 
                             ($signed({1'b0, window_c[2][1]}) - $signed({1'b0, window_c[0][1]}) ) * 2 + 
                             ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[0][2]}));

                        abs_gx = (gx < 0) ? -gx : gx;
                        abs_gy = (gy < 0) ? -gy : gy;
                        total = (abs_gx + abs_gy) / 2;

                        if (total > 255) total = 255;
                        output_reg_c = 8'(total);
                    end 

                    // 6. Update Counters
                    if (x_cnt == WIDTH - 1) begin
                        x_cnt_c = 0;
                        if (y_cnt == HEIGHT - 1) y_cnt_c = 0;
                        else y_cnt_c = y_cnt + 1;
                    end else begin
                        x_cnt_c = x_cnt + 1;
                    end

                    // 7. Transition to Write State
                    valid_data_c = 1'b1; 
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