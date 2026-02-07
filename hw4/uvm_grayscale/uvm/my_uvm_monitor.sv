import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        out_file = $fopen(IMG_OUT_NAME, "wb");
        if ( !out_file ) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", IMG_OUT_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int n_bytes;
        logic [0:BMP_HEADER_SIZE-1][7:0] bmp_header;
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        // get the stored BMP header as packed array
        if ( !uvm_config_db#(logic[0:BMP_HEADER_SIZE-1][7:0])::get(null, "*", "bmp_header", bmp_header) ) begin
            `uvm_fatal("MON_OUT_RUN", $sformatf("Failed to retrieve BMP header data for file %s...", IMG_CMP_NAME));
        end

        // copy the BMP header to the output file
        for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
            $fwrite(out_file, "%c", bmp_header[i]);
        end

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    $fwrite(out_file, "%c%c%c", vif.out_dout, vif.out_dout, vif.out_dout);
                    tx_out.image_pixel = {3{vif.out_dout}};
                    mon_ap_output.write(tx_out);
                    vif.out_rd_en = 1'b1;
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", IMG_OUT_NAME), UVM_LOW);
        $fclose(out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int cmp_file, n_bytes;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        cmp_file = $fopen(IMG_CMP_NAME, "rb");
        if ( !cmp_file ) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", IMG_CMP_NAME));
        end

        // store the BMP header as packed array
        n_bytes = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
        uvm_config_db#(logic[0:BMP_HEADER_SIZE-1][7:0])::set(null, "*", "bmp_header", {>> 8{bmp_header}});
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int n_bytes;
        int latency_count = 0; // Counter to track discarded pixels
        logic [0:BMP_HEADER_SIZE-1][7:0] bmp_header;
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset)
        @(negedge vif.reset)

        tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

        // get the stored BMP header
        if ( !uvm_config_db#(logic[0:BMP_HEADER_SIZE-1][7:0])::get(null, "*", "bmp_header", bmp_header) ) begin
            `uvm_fatal("MON_OUT_RUN", $sformatf("Failed to retrieve BMP header data for file %s...", IMG_CMP_NAME));
        end

        // copy the BMP header to the output file
        for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
            $fwrite(out_file, "%c", bmp_header[i]);
        end

        vif.out_rd_en = 1'b0;

        forever begin
            @(negedge vif.clock)
            begin
                if (vif.out_empty == 1'b0) begin
                    
                    // ALIGNMENT FIX:
                    // Discard the first 'IMG_WIDTH + 1' outputs. 
                    // These are the "0" values generated while the pipeline was filling.
                    if (latency_count < IMG_WIDTH + 1) begin
                        latency_count++;
                        vif.out_rd_en = 1'b1; // Pop from FIFO but DO NOT write to file
                    end else begin
                        // Valid data - Write to file and Scoreboard
                        $fwrite(out_file, "%c%c%c", vif.out_dout, vif.out_dout, vif.out_dout);
                        tx_out.image_pixel = {3{vif.out_dout}};
                        mon_ap_output.write(tx_out);
                        vif.out_rd_en = 1'b1;
                    end
                end else begin
                    vif.out_rd_en = 1'b0;
                end
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", IMG_CMP_NAME), UVM_LOW);
        $fclose(cmp_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
