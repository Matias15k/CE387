
module udp_parser (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    input  logic        in_sof,
    input  logic        in_eof,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din,
    output logic        out_wr_sof,
    output logic        out_wr_eof
);

    // Protocol constants
    localparam [15:0] ETH_PROTO_IP  = 16'h0800;
    localparam [3:0]  IP_VERSION_4  = 4'h4;
    localparam [7:0]  IP_PROTO_UDP  = 8'h11;

    // Header field sizes
    localparam ETH_HDR_BYTES = 14;
    localparam IP_HDR_BYTES  = 20;
    localparam UDP_HDR_BYTES = 8;

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_ETH_HDR,
        S_IP_HDR,
        S_UDP_HDR,
        S_UDP_DATA,
        S_FLUSH
    } state_t;

    state_t state, state_c;

    // Byte counter for header parsing and data output
    logic [15:0] byte_cnt, byte_cnt_c;

    // Stored header fields for validation and length calculation
    logic [15:0] eth_proto, eth_proto_c;
    logic [3:0]  ip_version, ip_version_c;
    logic [7:0]  ip_proto, ip_proto_c;
    logic [15:0] udp_length, udp_length_c;
    logic [15:0] udp_data_len, udp_data_len_c;

    // Sequential logic
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state        <= S_IDLE;
            byte_cnt     <= '0;
            eth_proto    <= '0;
            ip_version   <= '0;
            ip_proto     <= '0;
            udp_length   <= '0;
            udp_data_len <= '0;
        end else begin
            state        <= state_c;
            byte_cnt     <= byte_cnt_c;
            eth_proto    <= eth_proto_c;
            ip_version   <= ip_version_c;
            ip_proto     <= ip_proto_c;
            udp_length   <= udp_length_c;
            udp_data_len <= udp_data_len_c;
        end
    end

    // Combinational logic
    always_comb begin
        // Default outputs
        in_rd_en     = 1'b0;
        out_wr_en    = 1'b0;
        out_din      = 8'h00;
        out_wr_sof   = 1'b0;
        out_wr_eof   = 1'b0;

        // Default next-state
        state_c        = state;
        byte_cnt_c     = byte_cnt;
        eth_proto_c    = eth_proto;
        ip_version_c   = ip_version;
        ip_proto_c     = ip_proto;
        udp_length_c   = udp_length;
        udp_data_len_c = udp_data_len;

        case (state)

            S_IDLE: begin
                if (in_empty == 1'b0) begin
                    // Wait for SOF to begin packet parsing
                    if (in_sof == 1'b1) begin
                        // First byte of ethernet header is on in_dout
                        in_rd_en     = 1'b1;
                        byte_cnt_c   = 16'd1; // We just consumed byte 0
                        eth_proto_c  = '0;
                        ip_version_c = '0;
                        ip_proto_c   = '0;
                        udp_length_c = '0;
                        udp_data_len_c = '0;
                        state_c      = S_ETH_HDR;
                    end else begin
                        // Discard non-SOF data
                        in_rd_en = 1'b1;
                    end
                end
            end

            S_ETH_HDR: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;

                    // Capture EtherType bytes
                    if (byte_cnt == 16'd12)
                        eth_proto_c[15:8] = in_dout;
                    if (byte_cnt == 16'd13)
                        eth_proto_c[7:0] = in_dout;

                    byte_cnt_c = byte_cnt + 16'd1;

                    // After last Ethernet header byte (byte 13)
                    if (byte_cnt == 16'd13) begin
                        // Validate EtherType (combine stored high byte with current low byte)
                        if ({eth_proto[15:8], in_dout} == ETH_PROTO_IP) begin
                            byte_cnt_c = 16'd0;
                            state_c    = S_IP_HDR;
                        end else begin
                            state_c = S_FLUSH;
                        end
                    end

                    // If EOF arrives early, go back to idle
                    if (in_eof == 1'b1) begin
                        state_c    = S_IDLE;
                        byte_cnt_c = '0;
                    end
                end
            end

            S_IP_HDR: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;

                    // Capture IP Version from byte 0
                    if (byte_cnt == 16'd0)
                        ip_version_c = in_dout[7:4];

                    // Capture IP Protocol from byte 9
                    if (byte_cnt == 16'd9)
                        ip_proto_c = in_dout;

                    byte_cnt_c = byte_cnt + 16'd1;

                    // After last IP header byte (byte 19)
                    if (byte_cnt == 16'd19) begin
                        // Validate IP version (already stored) and protocol
                        if (ip_version == IP_VERSION_4 && ip_proto == IP_PROTO_UDP) begin
                            byte_cnt_c = 16'd0;
                            state_c    = S_UDP_HDR;
                        end else begin
                            state_c = S_FLUSH;
                        end
                    end

                    // If EOF arrives early, go back to idle
                    if (in_eof == 1'b1) begin
                        state_c    = S_IDLE;
                        byte_cnt_c = '0;
                    end
                end
            end

            S_UDP_HDR: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;

                    // Capture UDP Length bytes
                    if (byte_cnt == 16'd4)
                        udp_length_c[15:8] = in_dout;
                    if (byte_cnt == 16'd5) begin
                        udp_length_c[7:0] = in_dout;
                        // Calculate data length = UDP length - 8 (header)
                        udp_data_len_c = {udp_length[15:8], in_dout} - 16'd8;
                    end

                    byte_cnt_c = byte_cnt + 16'd1;

                    // After last UDP header byte (byte 7)
                    if (byte_cnt == 16'd7) begin
                        byte_cnt_c = 16'd0;
                        if (udp_data_len > 16'd0) begin
                            state_c = S_UDP_DATA;
                        end else begin
                            state_c = S_IDLE;
                        end
                    end

                    // If EOF arrives early, go back to idle
                    if (in_eof == 1'b1) begin
                        state_c    = S_IDLE;
                        byte_cnt_c = '0;
                    end
                end
            end

            S_UDP_DATA: begin
                if (in_empty == 1'b0 && out_full == 1'b0) begin
                    in_rd_en   = 1'b1;
                    out_wr_en  = 1'b1;
                    out_din    = in_dout;

                    // SOF on first data byte
                    if (byte_cnt == 16'd0)
                        out_wr_sof = 1'b1;

                    // EOF on last data byte
                    if (byte_cnt == udp_data_len - 16'd1)
                        out_wr_eof = 1'b1;

                    byte_cnt_c = byte_cnt + 16'd1;

                    // After last data byte
                    if (byte_cnt == udp_data_len - 16'd1) begin
                        byte_cnt_c = '0;
                        state_c    = S_IDLE;
                    end
                end
            end

            S_FLUSH: begin
                if (in_empty == 1'b0) begin
                    in_rd_en = 1'b1;
                    if (in_eof == 1'b1) begin
                        state_c    = S_IDLE;
                        byte_cnt_c = '0;
                    end
                end
            end

            default: begin
                state_c    = S_IDLE;
                byte_cnt_c = '0;
            end

        endcase
    end

endmodule
