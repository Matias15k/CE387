
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    my_uvm_if vif();

    neural_net_top #(
        .DATA_WIDTH   (DATA_WIDTH),
        .NUM_INPUTS   (NUM_INPUTS),
        .NUM_L0_OUT   (NUM_L0_OUT),
        .NUM_L1_OUT   (NUM_L1_OUT),
        .BITS         (BITS),
        .FIFO_DEPTH   (FIFO_DEPTH),
        .WEIGHT_FILE0 (WEIGHT_FILE0),
        .WEIGHT_FILE1 (WEIGHT_FILE1)
    ) nn_top_inst (
        .clock           (vif.clock),
        .reset           (vif.reset),
        .in_full         (vif.in_full),
        .in_wr_en        (vif.in_wr_en),
        .in_din          (vif.in_din),
        .out_empty       (vif.out_empty),
        .out_rd_en       (vif.out_rd_en),
        .out_dout        (vif.out_dout),
        .layer0_out      (vif.layer0_out),
        .layer1_out      (vif.layer1_out),
        .predicted_digit (vif.predicted_digit),
        .inference_done  (vif.inference_done)
    );

    initial begin
        // Store the vif so it can be retrieved by driver, monitors, coverage
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        // Run the test
        run_test("my_uvm_test");
    end

    // Reset sequence
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 10 ns clock (100 MHz)
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;

endmodule
