import uvm_pkg::*;


// Reads data from output FIFO to scoreboard
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

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    tx_out.data = vif.out_dout;
                    tx_out.sof  = vif.out_rd_sof;
                    tx_out.eof  = vif.out_rd_eof;
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

endclass: my_uvm_monitor_output


// Reads expected data from test_output.txt and compares to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;

    // Store entire expected output in memory
    logic [7:0] expected_data [0:8191];
    int expected_size;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        int cmp_file;
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        // Read entire expected output file into memory
        cmp_file = $fopen(CMP_OUTPUT_NAME, "rb");
        if (!cmp_file) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", CMP_OUTPUT_NAME));
        end
        expected_size = $fread(expected_data, cmp_file, 0);
        $fclose(cmp_file);

        `uvm_info("MON_CMP_BUILD", $sformatf("Loaded %0d bytes from %s", expected_size, CMP_OUTPUT_NAME), UVM_LOW);
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int byte_index;
        int idle_count;
        my_uvm_transaction tx_cmp;

        // extend the run_phase 50 clock cycles
        phase.phase_done.set_drain_time(this, (CLOCK_PERIOD * 50));

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));
        byte_index = 0;
        idle_count = 0;

        // Synchronize with output FIFO data
        // Stop when we've compared all expected bytes or output is idle too long
        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    if (byte_index < expected_size) begin
                        tx_cmp.data = expected_data[byte_index];
                        tx_cmp.sof  = 1'b0;
                        tx_cmp.eof  = 1'b0;
                        mon_ap_compare.write(tx_cmp);
                        byte_index++;
                    end
                    idle_count = 0;
                end else begin
                    // Track idle cycles after we've started receiving data
                    if (byte_index > 0) begin
                        idle_count++;
                        // Exit after 100 idle cycles (all data processed)
                        if (idle_count > 100) begin
                            `uvm_info("MON_CMP_RUN", $sformatf("Compared %0d bytes total", byte_index), UVM_LOW);
                            break;
                        end
                    end
                end
            end
        end

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

endclass: my_uvm_monitor_compare
