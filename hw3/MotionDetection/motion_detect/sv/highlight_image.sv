module highlight_image (
    input  logic        clock,
    input  logic        reset,
    // Interface to Original Frame Copy FIFO
    output logic        orig_rd_en,
    input  logic        orig_empty,
    input  logic [23:0] orig_dout,
    // Interface to Mask FIFO
    output logic        mask_rd_en,
    input  logic        mask_empty,
    input  logic [7:0]  mask_dout,
    // Interface to Output FIFO
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [23:0] out_din
);

    typedef enum logic [0:0] {s0, s1} state_t;
    state_t state, state_c;
    logic [23:0] pixel_out, pixel_out_c;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state     <= s0;
            pixel_out <= '0;
        end else begin
            state     <= state_c;
            pixel_out <= pixel_out_c;
        end
    end

    always_comb begin
        orig_rd_en = 1'b0;
        mask_rd_en = 1'b0;
        out_wr_en  = 1'b0;
        out_din    = 24'b0;
        state_c    = state;
        pixel_out_c = pixel_out;

        case (state)
            s0: begin
                // Wait for BOTH the mask and the buffered original frame
                if (!orig_empty && !mask_empty) begin
                    if (mask_dout == 8'hFF) begin
                        // Highlight Red: R=0xFF, G=0x00, B=0x00
                        // Assuming [23:16]=R
                        pixel_out_c = 24'h0000FF;
                    end else begin
                        // Keep original pixel
                        pixel_out_c = orig_dout;
                    end
                    
                    orig_rd_en = 1'b1;
                    mask_rd_en = 1'b1;
                    state_c = s1;
                end
            end

            s1: begin
                // Write final pixel to output
                if (!out_full) begin
                    out_din = pixel_out;
                    out_wr_en = 1'b1;
                    state_c = s0;
                end
            end
        endcase
    end
endmodule