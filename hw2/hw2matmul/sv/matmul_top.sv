module matmul_top 
#(  parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter N = 8
)
(
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  start,
    output logic                  done,
    input  logic [DATA_WIDTH-1:0] a_din,
    input  logic [ADDR_WIDTH-1:0] a_wr_addr,
    input  logic                  a_wr_en,
    input  logic [DATA_WIDTH-1:0] b_din,
    input  logic [ADDR_WIDTH-1:0] b_wr_addr,
    input  logic                  b_wr_en,
    output logic [DATA_WIDTH-1:0] c_dout,
    input  logic [ADDR_WIDTH-1:0] c_rd_addr
);

    logic [DATA_WIDTH-1:0] a_dout_internal;
    logic [ADDR_WIDTH-1:0] a_addr_internal;
    
    logic [DATA_WIDTH-1:0] b_dout_internal;
    logic [ADDR_WIDTH-1:0] b_addr_internal;
    
    logic [DATA_WIDTH-1:0] c_din_internal;
    logic [ADDR_WIDTH-1:0] c_addr_internal;
    logic                  c_wr_en_internal;

    matmul #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .N(N)
    ) matmul_inst (
        .clock(clock),
        .reset(reset),
        .start(start),
        .done(done),
        
        .a_dout(a_dout_internal),
        .a_addr(a_addr_internal),
        
        .b_dout(b_dout_internal),
        .b_addr(b_addr_internal),
        
        .c_din(c_din_internal),
        .c_addr(c_addr_internal),
        .c_wr_en(c_wr_en_internal)
    );

    bram #(
        .BRAM_DATA_WIDTH(DATA_WIDTH),
        .BRAM_ADDR_WIDTH(ADDR_WIDTH)
    ) bram_a (
        .clock(clock),
        .rd_addr(a_addr_internal),  
        .wr_addr(a_wr_addr),         
        .wr_en(a_wr_en),             
        .dout(a_dout_internal),      
        .din(a_din)                  
    );

    bram #(
        .BRAM_DATA_WIDTH(DATA_WIDTH),
        .BRAM_ADDR_WIDTH(ADDR_WIDTH)
    ) bram_b (
        .clock(clock),
        .rd_addr(b_addr_internal),   
        .wr_addr(b_wr_addr),         
        .wr_en(b_wr_en),             
        .dout(b_dout_internal),      
        .din(b_din)                 
    );

    bram #(
        .BRAM_DATA_WIDTH(DATA_WIDTH),
        .BRAM_ADDR_WIDTH(ADDR_WIDTH)
    ) bram_c (
        .clock(clock),
        .rd_addr(c_rd_addr),         
        .wr_addr(c_addr_internal),   
        .wr_en(c_wr_en_internal),    
        .dout(c_dout),               
        .din(c_din_internal)         
    );

endmodule