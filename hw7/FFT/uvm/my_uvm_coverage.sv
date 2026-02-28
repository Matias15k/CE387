import uvm_pkg::*;

// -----------------------------------------------------------
// Functional coverage subscriber
//
// Passively observes all DUT output transactions via the
// analysis_port. Covers:
//   - All FFT output bin indices (0..N-1)
//   - Real/imaginary output value ranges
//   - Cross coverage: index x value range
// -----------------------------------------------------------
class my_uvm_coverage extends uvm_subscriber #(my_uvm_transaction);
    `uvm_component_utils(my_uvm_coverage)

    my_uvm_transaction tx;

    // --------------------------------------------------------
    // Covergroup: FFT output coverage
    // --------------------------------------------------------
    covergroup fft_cg;

        // Cover all FFT output sample indices (all butterfly operations)
        cp_sample_index: coverpoint tx.sample_index {
            bins fft_bin[] = {[0:FFT_N-1]};
        }

        // Cover real output value ranges
        cp_out_real: coverpoint tx.data_real {
            bins large_neg  = {[$signed(-32'h80000000) : $signed(-32'h00010000)]};
            bins small_neg  = {[$signed(-32'h0000FFFF) : $signed(-32'h00000001)]};
            bins zero       = {32'sh0};
            bins small_pos  = {[$signed(32'h00000001)  : $signed(32'h0000FFFF)]};
            bins large_pos  = {[$signed(32'h00010000)  : $signed(32'h7FFFFFFF)]};
        }

        // Cover imaginary output value ranges
        cp_out_imag: coverpoint tx.data_imag {
            bins large_neg  = {[$signed(-32'h80000000) : $signed(-32'h00010000)]};
            bins small_neg  = {[$signed(-32'h0000FFFF) : $signed(-32'h00000001)]};
            bins zero       = {32'sh0};
            bins small_pos  = {[$signed(32'h00000001)  : $signed(32'h0000FFFF)]};
            bins large_pos  = {[$signed(32'h00010000)  : $signed(32'h7FFFFFFF)]};
        }

        // Cross: which output indices produced which value ranges
        cross_idx_real: cross cp_sample_index, cp_out_real;
        cross_idx_imag: cross cp_sample_index, cp_out_imag;

    endgroup

    // --------------------------------------------------------
    // Constructor
    // --------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        fft_cg = new();
    endfunction

    // --------------------------------------------------------
    // Called automatically when analysis_port writes a tx
    // --------------------------------------------------------
    function void write(my_uvm_transaction t);
        tx = t;
        fft_cg.sample();
    endfunction

    // --------------------------------------------------------
    // Report coverage percentage at end of simulation
    // --------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Functional Coverage: %0.2f%%",
                  fft_cg.get_coverage()), UVM_LOW)
    endfunction

endclass
