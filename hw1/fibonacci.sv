module fibonacci(
  input logic clk, 
  input logic reset,
  input logic [15:0] din,
  input logic start,
  output logic [15:0] dout,
  output logic done );

  // TODO: Add local logic signals
  enum logic [1:0] {...} state;

  always_ff @(posedge clk, posedge reset)
  begin
    if ( reset == 1'b1 ) begin
       // TODO: Implement reset signals
    end else begin
       // TODO: Implement clocked signals
    end
  end

  always_comb 
  begin
    case (state)
       // TODO: Implement FSM
    endcase
  end
endmodule
