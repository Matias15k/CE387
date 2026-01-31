module subtract_background #(
    parameter THRESHOLD = 50
)(
    input  logic       clock,
    input  logic       reset,
    // Interface to Background FIFO
    output logic       bg_rd_en,
    input  logic       bg_empty,
    input  logic [7:0] bg_dout,
    // Interface to Frame FIFO
    output logic       fr_rd_en,
    input  logic       fr_empty,
    input  logic [7:0] fr_dout,
    // Interface to Mask FIFO
    output logic       mask_wr_en,
    input  logic       mask_full,
    output logic [7:0] mask_din
);

    typedef enum logic [0:0] {s0, s1} state_t;
    state_t state, state_c;
    logic [7:0] mask_val, mask_val_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state    <= s0;
            mask_val <= '0;
        end else begin
            state    <= state_c;
            mask_val <= mask_val_c;
        end
    end

    always_comb begin
        bg_rd_en   = 1'b0;
        fr_rd_en   = 1'b0;
        mask_wr_en = 1'b0;
        mask_din   = 8'b0;
        state_c    = state;
        mask_val_c = mask_val;

        case (state)
            s0: begin
                if (!bg_empty && !fr_empty) begin
                    logic [7:0] diff;
                    if (fr_dout > bg_dout)
                        diff = fr_dout - bg_dout;
                    else
                        diff = bg_dout - fr_dout;

                    mask_val_c = (diff > THRESHOLD) ? 8'hFF : 8'h00;
                    
                    bg_rd_en = 1'b1;
                    fr_rd_en = 1'b1;
                    state_c = s1;
                end
            end

            s1: begin
                if (!mask_full) begin
                    mask_din = mask_val;
                    mask_wr_en = 1'b1;
                    state_c = s0;
                end
            end
        endcase
    end
endmodule