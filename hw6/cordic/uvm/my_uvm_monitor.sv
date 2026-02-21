import uvm_pkg::*;


// =========================================================================
// Output Monitor: reads sin and cos values from RTL output FIFOs
// and writes them to out_sin.txt / out_cos.txt for visual comparison
// Bounded to exactly NUM_THETA samples to prevent extra reads during drain
// =========================================================================
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;
    virtual my_uvm_if vif;
    int sin_out_file;
    int cos_out_file;
    int sample_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        // Open output files for RTL results
        sin_out_file = $fopen(OUT_SIN_FILE_NAME, "w");
        if (!sin_out_file) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s", OUT_SIN_FILE_NAME));
        end

        cos_out_file = $fopen(OUT_COS_FILE_NAME, "w");
        if (!cos_out_file) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s", OUT_COS_FILE_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        vif.sin_rd_en = 1'b0;
        vif.cos_rd_en = 1'b0;
        sample_count = 0;

        // Bounded loop: read exactly NUM_THETA samples, then stop
        while (sample_count < NUM_THETA) begin
            @(negedge vif.clock);
            begin
                if (vif.sin_empty == 1'b0 && vif.cos_empty == 1'b0) begin
                    tx_out.sin_val = vif.sin_dout;
                    tx_out.cos_val = vif.cos_dout;

                    // Write RTL output to files (same format as C: %04x)
                    $fwrite(sin_out_file, "%04x\n", vif.sin_dout);
                    $fwrite(cos_out_file, "%04x\n", vif.cos_dout);

                    mon_ap_output.write(tx_out);
                    vif.sin_rd_en = 1'b1;
                    vif.cos_rd_en = 1'b1;
                    sample_count++;
                end else begin
                    vif.sin_rd_en = 1'b0;
                    vif.cos_rd_en = 1'b0;
                end
            end
        end

        // De-assert rd_en after all samples collected
        @(negedge vif.clock);
        vif.sin_rd_en = 1'b0;
        vif.cos_rd_en = 1'b0;

        `uvm_info("MON_OUT_RUN", $sformatf("Finished reading %0d RTL output samples.", sample_count), UVM_LOW);
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing files %s and %s...", OUT_SIN_FILE_NAME, OUT_COS_FILE_NAME), UVM_LOW);
        $fclose(sin_out_file);
        $fclose(cos_out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output


// =========================================================================
// Compare Monitor: reads expected sin/cos from C-generated reference files
// Synchronized with output FIFO availability to stay in lockstep
// =========================================================================
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int sin_file, cos_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        // Open reference files
        sin_file = $fopen(SIN_FILE_NAME, "r");
        if (!sin_file) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s", SIN_FILE_NAME));
        end

        cos_file = $fopen(COS_FILE_NAME, "r");
        if (!cos_file) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s", COS_FILE_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int r, i;
        logic [15:0] exp_sin, exp_cos;
        my_uvm_transaction tx_cmp;

        // extend the run_phase for pipeline drain
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 100));

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

        i = 0;
        while (!$feof(sin_file) && !$feof(cos_file) && i < NUM_THETA) begin
            // Read expected values from C reference files (16-bit hex: "%04x\n")
            r = $fscanf(sin_file, "%h\n", exp_sin);
            r = $fscanf(cos_file, "%h\n", exp_cos);

            // Wait for output data to be available (synchronized with output monitor)
            while (1) begin
                @(negedge vif.clock);
                if (vif.sin_empty == 1'b0 && vif.cos_empty == 1'b0) begin
                    tx_cmp.sin_val = exp_sin;
                    tx_cmp.cos_val = exp_cos;
                    mon_ap_compare.write(tx_cmp);
                    break;
                end
            end

            i++;
        end

        `uvm_info("MON_CMP_RUN", $sformatf("Finished reading %0d reference values.", i), UVM_LOW);

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing files %s and %s...", SIN_FILE_NAME, COS_FILE_NAME), UVM_LOW);
        $fclose(sin_file);
        $fclose(cos_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
