
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    my_uvm_if vif();

    fft_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FFT_N(FFT_N),
        .FIFO_DEPTH(FIFO_DEPTH),
        .QUANT_BITS(QUANT_BITS)
    ) fft_top_inst (
        .clock(vif.clock),
        .reset(vif.reset),
        .in_real_full(vif.in_real_full),
        .in_imag_full(vif.in_imag_full),
        .in_wr_en(vif.in_wr_en),
        .in_real_din(vif.in_real_din),
        .in_imag_din(vif.in_imag_din),
        .out_real_empty(vif.out_real_empty),
        .out_imag_empty(vif.out_imag_empty),
        .out_rd_en(vif.out_rd_en),
        .out_real_dout(vif.out_real_dout),
        .out_imag_dout(vif.out_imag_dout)
    );

    initial begin
        // store the vif so it can be retrieved by the driver & monitor
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        // run the test
        run_test("my_uvm_test");
    end

    // reset
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 10ns clock (100 MHz)
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;

endmodule
