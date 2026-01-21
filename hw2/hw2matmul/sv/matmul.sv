module matmul
#(  parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter N = 8 
)
(
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  start,
    output logic                  done,
    input  logic [DATA_WIDTH-1:0] a_dout,
    output logic [ADDR_WIDTH-1:0] a_addr,
    input  logic [DATA_WIDTH-1:0] b_dout,
    output logic [ADDR_WIDTH-1:0] b_addr,
    output logic [DATA_WIDTH-1:0] c_din,
    output logic [ADDR_WIDTH-1:0] c_addr,
    output logic                  c_wr_en
);

    typedef enum logic [1:0] {
        s_idle, 
        s_setup, 
        s_calc, 
        s_write
    } state_t;

    state_t state, state_c;

    logic [3:0] i, i_c; //rows
    logic [3:0] j, j_c; //cols
    logic [3:0] k, k_c; //product
    
    logic [DATA_WIDTH-1:0] accum, accum_c;
    logic done_c, done_o;

    assign done = done_o;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state   <= s_idle;
            done_o  <= 1'b0;
            i       <= '0;
            j       <= '0;
            k       <= '0;
            accum   <= '0;
        end else begin
            state   <= state_c;
            done_o  <= done_c;
            i       <= i_c;
            j       <= j_c;
            k       <= k_c;
            accum   <= accum_c;
        end
    end

    always_comb begin

        state_c   = state;
        done_c    = done_o;
        i_c       = i;
        j_c       = j;
        k_c       = k;
        accum_c   = accum;

        a_addr    = '0;
        b_addr    = '0;
        c_addr    = '0;
        c_din     = '0;
        c_wr_en   = 1'b0;

        case (state)
            s_idle: begin
                i_c = '0;
                j_c = '0;
                if (start) begin
                    state_c = s_setup;
                    done_c  = 1'b0;
                end else begin
                    state_c = s_idle;
                end
            end

            s_setup: begin
                accum_c = '0;
                k_c     = '0;
                
                a_addr = {i[2:0], 3'b000}; 
                b_addr = {3'b000, j[2:0]};
                
                state_c = s_calc;
            end

            s_calc: begin

                accum_c = accum + ($signed(a_dout) * $signed(b_dout));
                
                if (k < N) begin
                    
                    k_c = k + 1'b1;
    
                    if (k < (N - 1)) begin
                        a_addr = {i[2:0], k_c[2:0]}; 
                        b_addr = {k_c[2:0], j[2:0]};
                        state_c = s_calc;
                    end else begin
                        state_c = s_write;
                    end

                end 
            end

            s_write: begin
                c_wr_en = 1'b1;
                c_addr  = {i[2:0], j[2:0]}; 
                c_din   = accum;

                if (j < (N - 1)) begin
                    j_c = j + 1'b1;
                    state_c = s_setup;
                end else begin
                    j_c = '0;
                    if (i < (N - 1)) begin
                        i_c = i + 1'b1;
                        state_c = s_setup;
                    end else begin
                        done_c  = 1'b1;
                        state_c = s_idle;
                    end
                end
            end

            default: state_c = s_idle;
        endcase
    end

endmodule