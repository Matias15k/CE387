import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
    logic [31:0] rad;           // 32-bit quantized radian input
    logic [15:0] sin_val;       // 16-bit sin output
    logic [15:0] cos_val;       // 16-bit cos output

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(rad, UVM_ALL_ON)
        `uvm_field_int(sin_val, UVM_ALL_ON)
        `uvm_field_int(cos_val, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int rad_file, r, i;
        logic [31:0] rad_val;

        `uvm_info("SEQ_RUN", $sformatf("Loading radians from file %s...", RAD_FILE_NAME), UVM_LOW);

        rad_file = $fopen(RAD_FILE_NAME, "r");
        if (!rad_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s", RAD_FILE_NAME));
        end

        i = 0;
        while (!$feof(rad_file) && i < NUM_THETA) begin
            tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
            start_item(tx);

            // Read 32-bit hex value from rad.txt (format: "%08x\n")
            r = $fscanf(rad_file, "%h\n", rad_val);
            tx.rad = rad_val;

            finish_item(tx);
            i++;
        end

        `uvm_info("SEQ_RUN", $sformatf("Finished sending %0d theta values.", i), UVM_LOW);
        $fclose(rad_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
