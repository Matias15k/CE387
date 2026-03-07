import uvm_pkg::*;

class my_uvm_coverage extends uvm_subscriber #(my_uvm_transaction);
    `uvm_component_utils(my_uvm_coverage)

    my_uvm_transaction tx;
    virtual my_uvm_if  vif;

    // Variables for coverage sampling
    logic [3:0]  sampled_digit;
    logic [9:0]  l0_active;  // bitmask: which layer-0 neurons fired (>0)
    logic [9:0]  l1_active;  // bitmask: which layer-1 neurons fired (>0)
    logic [31:0] sampled_pixel;

    // -------------------------------------------------------
    // Covergroup: input pixel value distribution
    // -------------------------------------------------------
    covergroup cg_input;
        coverpoint sampled_pixel {
            bins zero       = {32'h00000000};
            bins low        = {[32'h00000001 : 32'h00003FFF]};
            bins mid        = {[32'h00004000 : 32'h0000BFFF]};
            bins high       = {[32'h0000C000 : 32'h0000FFFF]};
        }
    endgroup

    // -------------------------------------------------------
    // Covergroup: output classification digit
    // -------------------------------------------------------
    covergroup cg_output;
        coverpoint sampled_digit {
            bins digit[] = {[0:9]};
        }
    endgroup

    // -------------------------------------------------------
    // Covergroup: layer 0 neuron activations (post-ReLU)
    // -------------------------------------------------------
    covergroup cg_layer0;
        coverpoint l0_active {
            bins no_active    = {10'b0000000000};
            bins some_active  = {[10'b0000000001 : 10'b1111111110]};
            bins all_active   = {10'b1111111111};
        }
        // Per-neuron coverage
        coverpoint l0_active[0] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[1] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[2] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[3] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[4] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[5] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[6] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[7] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[8] { bins inactive = {0}; bins active = {1}; }
        coverpoint l0_active[9] { bins inactive = {0}; bins active = {1}; }
    endgroup

    // -------------------------------------------------------
    // Covergroup: layer 1 neuron activations (post-ReLU)
    // -------------------------------------------------------
    covergroup cg_layer1;
        coverpoint l1_active {
            bins no_active    = {10'b0000000000};
            bins some_active  = {[10'b0000000001 : 10'b1111111110]};
            bins all_active   = {10'b1111111111};
        }
        coverpoint l1_active[0] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[1] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[2] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[3] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[4] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[5] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[6] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[7] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[8] { bins inactive = {0}; bins active = {1}; }
        coverpoint l1_active[9] { bins inactive = {0}; bins active = {1}; }
    endgroup

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_input  = new();
        cg_output = new();
        cg_layer0 = new();
        cg_layer1 = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
    endfunction: build_phase

    // -------------------------------------------------------
    // write() – called by analysis port on each transaction
    // (Subscriber interface requirement; actual sampling in run_phase)
    // -------------------------------------------------------
    function void write(my_uvm_transaction t);
        tx = t;
    endfunction

    // -------------------------------------------------------
    // run_phase – samples all coverage through the vif
    // -------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        @(posedge vif.reset)
        @(negedge vif.reset)

        forever begin
            @(posedge vif.clock);

            // Sample input pixel coverage when data is being written to FIFO
            if (vif.in_wr_en == 1'b1 && vif.in_full == 1'b0) begin
                sampled_pixel = vif.in_din;
                cg_input.sample();
            end

            // Sample layer & output coverage when inference completes
            if (vif.inference_done == 1'b1) begin
                // Sample output digit
                sampled_digit = vif.predicted_digit;
                cg_output.sample();

                // Sample layer 0 activations
                for (int i = 0; i < NUM_L0_OUT; i++)
                    l0_active[i] = (vif.layer0_out[i] > 0) ? 1'b1 : 1'b0;
                cg_layer0.sample();

                // Sample layer 1 activations
                for (int i = 0; i < NUM_L1_OUT; i++)
                    l1_active[i] = (vif.layer1_out[i] > 0) ? 1'b1 : 1'b0;
                cg_layer1.sample();
            end
        end
    endtask: run_phase

    // -------------------------------------------------------
    // Report coverage
    // -------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Input Coverage:   %0.2f%%", cg_input.get_coverage()), UVM_LOW);
        `uvm_info("COV", $sformatf("Output Coverage:  %0.2f%%", cg_output.get_coverage()), UVM_LOW);
        `uvm_info("COV", $sformatf("Layer 0 Coverage: %0.2f%%", cg_layer0.get_coverage()), UVM_LOW);
        `uvm_info("COV", $sformatf("Layer 1 Coverage: %0.2f%%", cg_layer1.get_coverage()), UVM_LOW);
    endfunction

endclass
