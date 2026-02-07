module sobel_filter #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
)(
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

    typedef enum logic [0:0] {s0, s1} state_types;
    state_types state, state_c;

    logic        lb0_wr_en, lb1_wr_en;
    logic        lb0_rd_en, lb1_rd_en;
    logic [7:0]  lb0_din,   lb1_din;
    logic [7:0]  lb0_dout,  lb1_dout;
    logic        lb0_full,  lb1_full;
    logic        lb0_empty, lb1_empty;

    logic [10:0] x_cnt, x_cnt_c;
    logic [10:0] y_cnt, y_cnt_c;

    logic [7:0] window [2:0][2:0]; 
    logic [7:0] window_c [2:0][2:0];
    logic [7:0] output_reg, output_reg_c;
    logic       valid_data, valid_data_c;

    // Line Buffers
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

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state <= s0;
            x_cnt <= '0; y_cnt <= '0;
            output_reg <= '0; valid_data <= '0;
            for(int i=0; i<3; i++) for(int j=0; j<3; j++) window[i][j] <= '0;
        end else begin
            state <= state_c;
            x_cnt <= x_cnt_c; y_cnt <= y_cnt_c;
            output_reg <= output_reg_c; valid_data <= valid_data_c;
            window <= window_c;
        end
    end

    int gx, gy, abs_gx, abs_gy, total;

    always_comb begin
        in_rd_en = 0; out_wr_en = 0; out_din = output_reg; 
        lb0_wr_en = 0; lb0_din = 0; lb0_rd_en = 0;
        lb1_wr_en = 0; lb1_din = 0; lb1_rd_en = 0;

        state_c = state; x_cnt_c = x_cnt; y_cnt_c = y_cnt;
        output_reg_c = output_reg; window_c = window; valid_data_c = valid_data;

        case (state)
            s0: begin 
                if (!in_empty && !lb0_full && !lb1_full) begin

                    for(int i=0; i<3; i++) begin
                        window_c[i][0] = window[i][1];
                        window_c[i][1] = window[i][2];
                    end

                    in_rd_en = 1;
                    window_c[2][2] = in_dout;

                    lb0_din = in_dout;
                    lb0_wr_en = 1;

                    if (y_cnt >= 1) begin
                        lb0_rd_en = 1;
                        window_c[1][2] = lb0_dout;
                        lb1_din = lb0_dout;
                        lb1_wr_en = 1;
                    end
                    if (y_cnt >= 2) begin
                        lb1_rd_en = 1;
                        window_c[0][2] = lb1_dout;
                    end

                    output_reg_c = 0; 
                    
                    if (y_cnt >= 2 && x_cnt >= 2 && x_cnt < WIDTH) begin
                         gx = ($signed({1'b0, window_c[0][2]}) - $signed({1'b0, window_c[0][0]})) + 
                              ($signed({1'b0, window_c[1][2]}) - $signed({1'b0, window_c[1][0]}) ) * 2 + 
                              ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[2][0]}));

                         gy = ($signed({1'b0, window_c[2][0]}) - $signed({1'b0, window_c[0][0]})) + 
                              ($signed({1'b0, window_c[2][1]}) - $signed({1'b0, window_c[0][1]}) ) * 2 + 
                              ($signed({1'b0, window_c[2][2]}) - $signed({1'b0, window_c[0][2]}));

                        abs_gx = (gx < 0) ? -gx : gx;
                        abs_gy = (gy < 0) ? -gy : gy;
                        total = (abs_gx + abs_gy) / 2;
                        if (total > 255) total = 255;
                        output_reg_c = 8'(total);
                    end 

                    if (x_cnt == WIDTH - 1) begin
                        x_cnt_c = 0;
                        if (y_cnt == HEIGHT - 1) y_cnt_c = 0; else y_cnt_c = y_cnt + 1;
                    end else begin
                        x_cnt_c = x_cnt + 1;
                    end

                    valid_data_c = 1;
                    state_c = s1;
                end
            end

            s1: begin // WRITE
                if (!out_full) begin
                    if (valid_data) begin
                        out_din = output_reg;
                        out_wr_en = 1;
                    end
                    state_c = s0;
                end
            end
        endcase
    end
endmodule