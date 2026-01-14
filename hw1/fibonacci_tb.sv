`timescale 1ns/1ns

module fibonacci_tb;

  logic clk; 
  logic reset = 1'b0;
  logic [15:0] din = 16'h0;
  logic start = 1'b0;
  logic [15:0] dout;
  logic done;

  // instantiate your design
  fibonacci fib(clk, reset, din, start, dout, done);

  // Clock Generator
  always
  begin
	clk = 1'b0;
	#5;
	clk = 1'b1;
	#5;
  end

  integer cycle_count = 0;

  // Increment cycle count on every positive edge
  always @(posedge clk) begin
    if (!reset) begin
        cycle_count <= cycle_count + 1;
    end
  end

  initial
  begin
	// Reset
	#0 reset = 0;
	#10 reset = 1;
	#10 reset = 0;
	
	/* ------------- Input of 5 ------------- */
	// Inputs into module/ Assert start
	#10;
	din = 16'd5;
	start = 1'b1;
	#10 start = 1'b0;
	
	// Wait until calculation is done	
	#10 wait (done == 1'b1);

	// Display Result
	$display("-----------------------------------------");
	$display("Input: %d", din);
	if (dout === 5)
	    $display("CORRECT RESULT: %d, GOOD JOB!", dout);
	else
	    $display("INCORRECT RESULT: %d, SHOULD BE: 5", dout);




	/* ------------- Input of 0 ------------- */
	// Inputs into module/ Assert start
    #20;
    din = 16'd0;
    start = 1'b1;
    #10 start = 1'b0;
    
    #10 wait (done == 1'b1); 

    $display("-----------------------------------------");
    $display("Input: %d", din);
    if (dout === 0)
        $display("CORRECT RESULT: %d, GOOD JOB!", dout);
    else
        $display("INCORRECT RESULT: %d, SHOULD BE: 0", dout);


	/* ------------- Input of 8 ------------- */
	// Inputs into module/ Assert start
    #20; 
    din = 16'd8;
    start = 1'b1;
    #10 start = 1'b0;
    
    #10 wait (done == 1'b1); 

    $display("-----------------------------------------");
    $display("Input: %d", din);
    if (dout === 21)
        $display("CORRECT RESULT: %d, GOOD JOB!", dout);
    else
        $display("INCORRECT RESULT: %d, SHOULD BE: 21", dout);

    // Done
    $display("Total cycles for this test: %d", cycle_count);
    $stop;
  end
endmodule

