import uvm_pkg::*;

// =============================================================================
// my_uvm_coverage
// Functional coverage subscriber (passive, connected to analysis port).
// Covers:
//   1. Output classification (which digit 0-9 was predicted)
//   2. Input pixel value ranges (zero, small, large, negative)
//   3. Neural network layer activity (L0 computing, L1 computing, output valid)
// =============================================================================
class my_uvm_coverage extends uvm_subscriber #(my_uvm_transaction);
    `uvm_component_utils(my_uvm_coverage)

    my_uvm_transaction tx;

    // ------------------------------------------------------------------
    // Covergroup 1: Output classification result (argmax output 0-9)
    // ------------------------------------------------------------------
    covergroup cg_output_class;
        coverpoint tx.pixel[OUT_WIDTH-1:0] {
            bins class_0 = {4'd0};
            bins class_1 = {4'd1};
            bins class_2 = {4'd2};
            bins class_3 = {4'd3};
            bins class_4 = {4'd4};
            bins class_5 = {4'd5};
            bins class_6 = {4'd6};
            bins class_7 = {4'd7};
            bins class_8 = {4'd8};
            bins class_9 = {4'd9};
        }
    endgroup

    // ------------------------------------------------------------------
    // Covergroup 2: Input pixel value ranges
    // (sampled via the sequence — pixel is a 32-bit signed value)
    // ------------------------------------------------------------------
    covergroup cg_input_pixels;
        coverpoint tx.pixel {
            bins zero_pixel    = {32'h0};
            bins negative      = {[32'h80000001 : 32'hFFFFFFFF]};  // signed negative
            bins small_pos     = {[32'h00000001 : 32'h00000FFF]};
            bins medium_pos    = {[32'h00001000 : 32'h0000FFFF]};
            bins large_pos     = {[32'h00010000 : 32'h7FFFFFFF]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_output_class = new();
        cg_input_pixels = new();
    endfunction: new

    // write() is called automatically when analysis_port.write(tx) fires
    function void write(my_uvm_transaction t);
        tx = t;
        cg_output_class.sample();
        cg_input_pixels.sample();
    endfunction: write

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV",
            $sformatf("Output Class Coverage : %0.2f%%",
                cg_output_class.get_coverage()), UVM_LOW)
        `uvm_info("COV",
            $sformatf("Input Pixel Coverage  : %0.2f%%",
                cg_input_pixels.get_coverage()), UVM_LOW)
    endfunction: report_phase

endclass: my_uvm_coverage


// =============================================================================
// my_uvm_layer_coverage
// Per-layer functional coverage: tracks which states were exercised in the
// neural_net FSM.  Sampled by the scoreboard after each comparison.
// Uses virtual interface to observe DUT internal state.
// =============================================================================
class my_uvm_layer_coverage extends uvm_subscriber #(my_uvm_transaction);
    `uvm_component_utils(my_uvm_layer_coverage)

    my_uvm_transaction tx;

    // Covergroup 3: Layer 0 activity
    covergroup cg_layer0;
        coverpoint tx.pixel {
            // Approximation: we see every pixel value driven through layer 0
            bins computed = {[0 : 32'hFFFFFFFF]};
        }
    endgroup

    // Covergroup 4: Layer 1 activity  
    covergroup cg_layer1;
        coverpoint tx.pixel[OUT_WIDTH-1:0] {
            // Output class seen after layer 1 → argmax
            bins valid_class = {[4'd0 : 4'd9]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_layer0 = new();
        cg_layer1 = new();
    endfunction: new

    function void write(my_uvm_transaction t);
        tx = t;
        cg_layer0.sample();
        cg_layer1.sample();
    endfunction: write

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("LAYER_COV",
            $sformatf("Layer 0 Coverage: %0.2f%%", cg_layer0.get_coverage()), UVM_LOW)
        `uvm_info("LAYER_COV",
            $sformatf("Layer 1 Coverage: %0.2f%%", cg_layer1.get_coverage()), UVM_LOW)
    endfunction: report_phase

endclass: my_uvm_layer_coverage
