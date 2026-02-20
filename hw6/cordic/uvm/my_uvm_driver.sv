import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);

    `uvm_component_utils(my_uvm_driver)

    virtual my_uvm_if vif;
    int rad_out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));

        // Open output file for rad values driven into DUT
        rad_out_file = $fopen(OUT_RAD_FILE_NAME, "w");
        if (!rad_out_file) begin
            `uvm_fatal("DRVR_BUILD", $sformatf("Failed to open output file %s", OUT_RAD_FILE_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        drive();
    endtask: run_phase

    virtual task drive();
        my_uvm_transaction tx;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        vif.in_din   = 32'b0;
        vif.in_wr_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.in_full == 1'b0) begin
                    seq_item_port.get_next_item(tx);
                    vif.in_din   = tx.rad;
                    vif.in_wr_en = 1'b1;

                    // Log rad value to output file (same format as C: %08x)
                    $fwrite(rad_out_file, "%08x\n", tx.rad);

                    seq_item_port.item_done();
                end else begin
                    vif.in_wr_en = 1'b0;
                    vif.in_din   = 32'b0;
                end
            end
        end
    endtask: drive

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("DRVR_FINAL", $sformatf("Closing file %s...", OUT_RAD_FILE_NAME), UVM_LOW);
        $fclose(rad_out_file);
    endfunction: final_phase

endclass
