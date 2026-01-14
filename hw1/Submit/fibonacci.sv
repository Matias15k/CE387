module fibonacci(
  input logic clk, 
  input logic reset,
  input logic [15:0] din,
  input logic start,
  output logic [15:0] dout,
  output logic done 
);

  // Defined states for the FSM
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state;

  state cur_state, next_state;

  // Local signals 
  logic [15:0] count;
  logic [15:0] num1; // F(n-2)
  logic [15:0] num2; // F(n-1)


  always_ff @(posedge clk, posedge reset) begin
    if (reset == 1'b1) begin
      cur_state <= IDLE;
      dout  <= 16'b0;
      done  <= 1'b0;
      count <= 16'b0;
      num1  <= 16'b0;
      num2  <= 16'b0;
    end else begin
      cur_state <= next_state;

      case (cur_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize
            num1  <= 16'd0;
            num2  <= 16'd1;
            count <= 16'd2; // We start calculating from index 2
            
            // For base cases
            if (din == 16'd0)      dout <= 16'd0;
            else if (din == 16'd1) dout <= 16'd1;
          end
        end

        COMPUTE: begin
          if (count <= din) begin
             num2  <= num1 + num2; // Next value
             num1  <= num2;        // Shift value
             count <= count + 1'b1;
          end
          
          if (count == din) begin
             dout <= num1 + num2;
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end


  always_comb begin
    next_state = cur_state;

    case (cur_state)
      IDLE: begin
        if (start) begin
          if (din <= 16'd1) 
            next_state = DONE;
          else 
            next_state = COMPUTE;
        end
      end

      COMPUTE: begin
        if (count == din) 
          next_state = DONE;
        else 
          next_state = COMPUTE;
      end

      DONE: begin
         next_state = IDLE;
      end
    endcase
  end

endmodule
