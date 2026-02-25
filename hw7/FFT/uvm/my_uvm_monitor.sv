import uvm_pkg::*;

// -----------------------------------------------------------
// Output monitor: reads FFT output from output FIFOs
// -----------------------------------------------------------
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));
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
                    tx_out.data_real = vif.out_real_dout;
                    tx_out.data_imag = vif.out_imag_dout;
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

endclass: my_uvm_monitor_output

// -----------------------------------------------------------
// Compare monitor: reads expected FFT output from reference files
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
        if (!ref_real_file) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s", FFT_OUT_REAL_NAME));
        end
        if (!ref_imag_file) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s", FFT_OUT_IMAG_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int i, scan_r, scan_i;
        logic [DATA_WIDTH-1:0] val_real, val_imag;
        my_uvm_transaction tx_cmp;

        // extend the run_phase 20 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

        // notify that run_phase has started
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
                    tx_cmp.data_real = $signed(val_real);
                    tx_cmp.data_imag = $signed(val_imag);
                    mon_ap_compare.write(tx_cmp);
                    i++;
                end
            end
        end

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", "Closing reference files...", UVM_LOW);
        $fclose(ref_real_file);
        $fclose(ref_imag_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
