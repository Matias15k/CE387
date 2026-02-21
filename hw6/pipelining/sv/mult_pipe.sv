
module mult_pipe 
#(parameter STAGES = 6) 
(
    input  logic clock,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    output logic [31:0] dout
);
    logic [0:STAGES-1] [31:0] prod;

    generate if (STAGES > 1)
        always_ff @(posedge clock) begin
            prod[1:STAGES-1] = prod[0:STAGES-2];
        end
    endgenerate

    always_ff @(posedge clock) begin
        prod[0] <= $signed(in1) * $signed(in2);
    end

    assign dout = prod[STAGES-1];
endmodule

/*
module shift_8x64 (
  input logic clk, 
  input logic shift,
  input logic [7:0] sr_in
  output logic [7:0] sr_out
);
  reg [63:0] [7:0] shift_reg;
  always @ (posedge clk)
  begin
      if (shift == 1'b1)
      begin
        shift_reg[63:1] <= shift_reg[62:0];
        shift_reg[0] <= sr_in;
      end
  end
  assign sr_out = shift_reg[63];
endmodule
*/
