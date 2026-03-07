import uvm_pkg::*;


// ---------------------------------------------------------------
// Output Monitor: reads predicted digit from output FIFO
// ---------------------------------------------------------------
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

        // Wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    tx_out.digit = vif.out_dout;
                    tx_out.pixel = {28'b0, vif.out_dout};
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                    `uvm_info("MON_OUT", $sformatf("Predicted digit: %0d", vif.out_dout), UVM_LOW);
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

endclass: my_uvm_monitor_output


// ---------------------------------------------------------------
// Compare Monitor: reads expected label from y_test.txt
// Waits for output FIFO activity then provides expected value
// ---------------------------------------------------------------
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int label_file;
        int true_label;
        my_uvm_transaction tx_cmp;

        // Extend run_phase 20 clock cycles past last activity
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 20));

        // Raise objection to keep simulation running
        phase.raise_objection(.obj(this));

        // Wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        // Read expected label from file
        label_file = $fopen(LABEL_FILE, "r");
        if (!label_file) begin
            `uvm_fatal("MON_CMP", $sformatf("Failed to open file %s", LABEL_FILE));
        end
        if ($fscanf(label_file, "%d", true_label) != 1) begin
            `uvm_fatal("MON_CMP", $sformatf("Failed to read label from %s", LABEL_FILE));
        end
        $fclose(label_file);

        `uvm_info("MON_CMP", $sformatf("Expected label: %0d", true_label), UVM_LOW);

        tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

        // Wait for the output FIFO to have data
        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    tx_cmp.digit = true_label[3:0];
                    tx_cmp.pixel = {28'b0, true_label[3:0]};
                    mon_ap_compare.write(tx_cmp);
                    // Only one inference expected – drop objection
                    phase.drop_objection(.obj(this));
                    return;
                end
            end
        end
    endtask: run_phase

endclass: my_uvm_monitor_compare
