import uvm_pkg::*;

// =============================================================================
// Output monitor: watches the DUT output FIFO and broadcasts each result
// transaction on the analysis port.  Also measures inference latency.
// =============================================================================
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port #(my_uvm_transaction) mon_ap_output;
    virtual my_uvm_if vif;

    // Latency / throughput counters
    longint unsigned start_cycle;
    longint unsigned end_cycle;
    longint unsigned total_cycles;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db #(virtual my_uvm_if)::read_by_name
                  (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));
        start_cycle   = 0;
        end_cycle     = 0;
        total_cycles  = 0;
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;

        // Wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(
                     .name("tx_out"), .contxt(get_full_name()));

        vif.out_rd_en = 1'b0;
        start_cycle   = 0;

        forever begin
            @(negedge vif.clock)
            begin
                total_cycles++;

                // Track start of inference (first pixel written into DUT FIFO)
                if (vif.in_wr_en && start_cycle == 0)
                    start_cycle = total_cycles;

                if (vif.out_empty == 1'b0) begin
                    // Capture current FIFO head — same cycle as asserting rd_en
                    // (matches grayscale monitor style: read dout, then advance)
                    end_cycle    = total_cycles;
                    tx_out.pixel = {28'b0, vif.out_dout};
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                    `uvm_info("MON_OUT",
                        $sformatf("Result=%0d  cycle=%0d  latency=%0d cycles",
                            vif.out_dout, total_cycles,
                            end_cycle - start_cycle),
                        UVM_LOW)
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

endclass: my_uvm_monitor_output


// =============================================================================
// Compare monitor: reads the expected class from y_test.txt and sends it to
// the scoreboard for comparison.
// =============================================================================
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port #(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db #(virtual my_uvm_if)::read_by_name
                  (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_cmp;
        int label_file;
        int true_label;

        // Extend run_phase to let output monitor finish
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 50));

        // Raise objection: this component controls simulation end
        phase.raise_objection(.obj(this));

        // Wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_cmp = my_uvm_transaction::type_id::create(
                     .name("tx_cmp"), .contxt(get_full_name()));

        // Wait until output is available (out_empty goes low)
        @(negedge vif.out_empty)
        @(negedge vif.clock)

        // Read expected label from file
        label_file = $fopen(LABEL_FILE, "r");
        if (!label_file)
            `uvm_fatal("MON_CMP", $sformatf("Cannot open %s", LABEL_FILE))

        if ($fscanf(label_file, "%d", true_label) != 1)
            `uvm_fatal("MON_CMP", "Failed to read true label")

        $fclose(label_file);

        `uvm_info("MON_CMP",
            $sformatf("True label from %s: %0d", LABEL_FILE, true_label),
            UVM_LOW)

        tx_cmp.pixel = {28'b0, OUT_WIDTH'(true_label)};
        mon_ap_compare.write(tx_cmp);

        // Drop objection — simulation may end after drain time
        phase.drop_objection(.obj(this));
    endtask: run_phase

endclass: my_uvm_monitor_compare
