module sobel_filter #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

    typedef enum logic [1:0] {IDLE, FILL, RUN} state_t;
    state_t state, state_c;

    // Line buffers
    logic [7:0] line_buf0 [0:WIDTH-1];
    logic [7:0] line_buf1 [0:WIDTH-1];
    logic [7:0] line_buf2 [0:WIDTH-1];

    // Position tracking
    logic [$clog2(WIDTH)-1:0] in_x, in_x_c;
    logic [$clog2(WIDTH)-1:0] out_x, out_x_c;
    logic [$clog2(HEIGHT)-1:0] out_y, out_y_c;

    localparam TOTAL_PIXELS = WIDTH * HEIGHT;
    logic [$clog2(TOTAL_PIXELS):0] in_count, in_count_c;
    logic [$clog2(TOTAL_PIXELS):0] out_count, out_count_c;

    // 3x3 window
    logic [7:0] win_tl, win_tc, win_tr;
    logic [7:0] win_ml, win_mc, win_mr;
    logic [7:0] win_bl, win_bc, win_br;

    // Gradients
    logic signed [11:0] h_grad, v_grad;
    logic [11:0] abs_h, abs_v;
    logic [12:0] sum_grad;
    logic [7:0] sobel_out;
    logic valid_window;
    
    // Control signals
    logic do_read, do_write;

    // Window extraction and gradient (combinational)
    always_comb begin
        win_tl = 8'd0; win_tc = 8'd0; win_tr = 8'd0;
        win_ml = 8'd0; win_mc = 8'd0; win_mr = 8'd0;
        win_bl = 8'd0; win_bc = 8'd0; win_br = 8'd0;
        valid_window = 1'b0;

        if (out_y > 0 && out_y < HEIGHT - 1 && out_x > 0 && out_x < WIDTH - 1) begin
            valid_window = 1'b1;
            win_tl = line_buf0[out_x - 1]; win_tc = line_buf0[out_x]; win_tr = line_buf0[out_x + 1];
            win_ml = line_buf1[out_x - 1]; win_mc = line_buf1[out_x]; win_mr = line_buf1[out_x + 1];
            win_bl = line_buf2[out_x - 1]; win_bc = line_buf2[out_x]; win_br = line_buf2[out_x + 1];
        end

        h_grad = -$signed({4'b0, win_tl}) - $signed({3'b0, win_tc, 1'b0}) - $signed({4'b0, win_tr})
                 +$signed({4'b0, win_bl}) + $signed({3'b0, win_bc, 1'b0}) + $signed({4'b0, win_br});
        v_grad = -$signed({4'b0, win_tl}) + $signed({4'b0, win_tr})
                 -$signed({3'b0, win_ml, 1'b0}) + $signed({3'b0, win_mr, 1'b0})
                 -$signed({4'b0, win_bl}) + $signed({4'b0, win_br});

        abs_h = (h_grad < 0) ? 12'($unsigned(-h_grad)) : 12'($unsigned(h_grad));
        abs_v = (v_grad < 0) ? 12'($unsigned(-v_grad)) : 12'($unsigned(v_grad));
        sum_grad = {1'b0, abs_h} + {1'b0, abs_v};

        sobel_out = valid_window ? ((sum_grad[12:1] > 255) ? 8'd255 : sum_grad[8:1]) : 8'd0;
    end

    // Sequential
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            in_x <= '0;
            out_x <= '0;
            out_y <= '0;
            in_count <= '0;
            out_count <= '0;
            for (int i = 0; i < WIDTH; i++) begin
                line_buf0[i] <= 8'd0;
                line_buf1[i] <= 8'd0;
                line_buf2[i] <= 8'd0;
            end
        end else begin
            state <= state_c;
            in_x <= in_x_c;
            out_x <= out_x_c;
            out_y <= out_y_c;
            in_count <= in_count_c;
            out_count <= out_count_c;

            // Update line buffers on read
            if (do_read) begin
                if (in_x == 0 && in_count > 0) begin
                    for (int i = 0; i < WIDTH; i++) begin
                        line_buf0[i] <= line_buf1[i];
                        line_buf1[i] <= line_buf2[i];
                    end
                end
                line_buf2[in_x] <= in_dout;
            end
        end
    end

    // State machine - read and write can happen in parallel
    always_comb begin
        in_rd_en = 1'b0;
        out_wr_en = 1'b0;
        out_din = 8'd0;
        do_read = 1'b0;
        do_write = 1'b0;
        state_c = state;
        in_x_c = in_x;
        out_x_c = out_x;
        out_y_c = out_y;
        in_count_c = in_count;
        out_count_c = out_count;

        case (state)
            IDLE: begin
                if (!in_empty)
                    state_c = FILL;
            end

            FILL: begin
                // Fill line buffers before starting output
                if (!in_empty) begin
                    in_rd_en = 1'b1;
                    do_read = 1'b1;
                    in_x_c = (in_x == WIDTH - 1) ? '0 : in_x + 1'b1;
                    in_count_c = in_count + 1'b1;
                    if (in_count >= WIDTH + 1)
                        state_c = RUN;
                end
            end

            RUN: begin
                // Read if input available and not done
                if (!in_empty && in_count < TOTAL_PIXELS) begin
                    in_rd_en = 1'b1;
                    do_read = 1'b1;
                    in_x_c = (in_x == WIDTH - 1) ? '0 : in_x + 1'b1;
                    in_count_c = in_count + 1'b1;
                end

                // Write if output space available, not done, and have enough data
                if (!out_full && out_count < TOTAL_PIXELS && 
                    (in_count >= TOTAL_PIXELS || in_count > out_count + WIDTH + 1)) begin
                    out_din = sobel_out;
                    out_wr_en = 1'b1;
                    do_write = 1'b1;
                    out_x_c = (out_x == WIDTH - 1) ? '0 : out_x + 1'b1;
                    out_y_c = (out_x == WIDTH - 1) ? out_y + 1'b1 : out_y;
                    out_count_c = out_count + 1'b1;
                end

                // Done
                if (out_count >= TOTAL_PIXELS - 1 && do_write) begin
                    state_c = IDLE;
                    in_x_c = '0;
                    out_x_c = '0;
                    out_y_c = '0;
                    in_count_c = '0;
                    out_count_c = '0;
                end
            end

            default: state_c = IDLE;
        endcase
    end

endmodule