import uvm_pkg::*;

// -----------------------------------------------------------
// Output monitor: reads DUT output from FIFOs, writes to files
// -----------------------------------------------------------
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int hw_out_real_file;
    int hw_out_imag_file;
    int sample_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        hw_out_real_file = $fopen(FFT_HW_OUT_REAL, "w");
        hw_out_imag_file = $fopen(FFT_HW_OUT_IMAG, "w");
        if (!hw_out_real_file)
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open %s", FFT_HW_OUT_REAL));
        if (!hw_out_imag_file)
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open %s", FFT_HW_OUT_IMAG));

        sample_count = 0;
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(
            .name("tx_out"), .contxt(get_full_name()));

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_real_empty == 1'b0 && vif.out_imag_empty == 1'b0) begin
                    tx_out.data_real     = vif.out_real_dout;
                    tx_out.data_imag     = vif.out_imag_dout;
                    tx_out.sample_index  = sample_count;

                    // Write to hardware output files
                    $fdisplay(hw_out_real_file, "%08x", vif.out_real_dout);
                    $fdisplay(hw_out_imag_file, "%08x", vif.out_imag_dout);

                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                    sample_count++;
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf(
            "Closing output files. Total samples captured: %0d", sample_count), UVM_LOW);
        $fclose(hw_out_real_file);
        $fclose(hw_out_imag_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output

// -----------------------------------------------------------
// Compare monitor: reads expected output from C reference files
// -----------------------------------------------------------
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;

    int ref_real_file, ref_imag_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        ref_real_file = $fopen(FFT_OUT_REAL_NAME, "r");
        ref_imag_file = $fopen(FFT_OUT_IMAG_NAME, "r");
        if (!ref_real_file)
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open %s", FFT_OUT_REAL_NAME));
        if (!ref_imag_file)
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open %s", FFT_OUT_IMAG_NAME));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int i, scan_r, scan_i;
        logic [DATA_WIDTH-1:0] val_real, val_imag;
        my_uvm_transaction tx_cmp;

        // extend the run_phase 20 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 20));

        // raise objection to keep sim running
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_cmp = my_uvm_transaction::type_id::create(
            .name("tx_cmp"), .contxt(get_full_name()));

        i = 0;
        while (i < FFT_N) begin
            @(negedge vif.clock)
            begin
                if (vif.out_real_empty == 1'b0 && vif.out_imag_empty == 1'b0) begin
                    scan_r = $fscanf(ref_real_file, "%h", val_real);
                    scan_i = $fscanf(ref_imag_file, "%h", val_imag);
                    tx_cmp.data_real    = $signed(val_real);
                    tx_cmp.data_imag    = $signed(val_imag);
                    tx_cmp.sample_index = i;
                    mon_ap_compare.write(tx_cmp);
                    i++;
                end
            end
        end

        // drop objection
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", "Closing reference files...", UVM_LOW);
        $fclose(ref_real_file);
        $fclose(ref_imag_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
