
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1ns / 1ns

module my_uvm_tb;

    // ---- Interface instance -------------------------------------------------
    my_uvm_if vif();

    // ---- DUT: neural network top -------------------------------------------
    neural_net_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_INPUTS (NUM_INPUTS),
        .L0_NEURONS (10),
        .L1_NEURONS (10),
        .FIFO_DEPTH (16),
        .BITS       (14),
        .ACC_WIDTH  (64),
        .OUT_WIDTH  (OUT_WIDTH),
        .L0_FILE    ("layer_0_weights_biases.txt"),
        .L1_FILE    ("layer_1_weights_biases.txt")
    ) dut (
        .clock     (vif.clock),
        .reset     (vif.reset),
        .in_full   (vif.in_full),
        .in_wr_en  (vif.in_wr_en),
        .in_din    (vif.in_din),
        .out_empty (vif.out_empty),
        .out_rd_en (vif.out_rd_en),
        .out_dout  (vif.out_dout)
    );

    // ---- Register interface and launch UVM test ----------------------------
    initial begin
        uvm_resource_db #(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));
        run_test("my_uvm_test");
    end

    // ---- Reset sequence ----------------------------------------------------
    initial begin
        vif.clock   <= 1'b1;
        vif.reset   <= 1'b0;
        vif.in_wr_en <= 1'b0;
        vif.in_din   <= '0;
        vif.out_rd_en <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // ---- 100 MHz clock (10 ns period) ---------------------------------------
    always #(CLOCK_PERIOD / 2) vif.clock = ~vif.clock;

endmodule
