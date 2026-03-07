import uvm_pkg::*;

// =============================================================================
// Transaction: carries one 32-bit input pixel driven into the DUT
// =============================================================================
class my_uvm_transaction extends uvm_sequence_item;

    logic [DATA_WIDTH-1:0] pixel;   // one input sample (hex from x_test.txt)

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(pixel, UVM_ALL_ON)
    `uvm_object_utils_end

endclass: my_uvm_transaction


// =============================================================================
// Sequence: reads all NUM_INPUTS pixels from x_test.txt and issues transactions
// =============================================================================
class my_uvm_sequence extends uvm_sequence #(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_file;
        int hex_val;
        int pixel_count;

        `uvm_info("SEQ_RUN", $sformatf("Opening input file: %s", INPUT_FILE), UVM_LOW)

        in_file = $fopen(INPUT_FILE, "r");
        if (!in_file)
            `uvm_fatal("SEQ_RUN", $sformatf("Cannot open %s", INPUT_FILE))

        pixel_count = 0;
        while (!$feof(in_file) && pixel_count < NUM_INPUTS) begin
            if ($fscanf(in_file, "%h", hex_val) == 1) begin
                tx = my_uvm_transaction::type_id::create(
                         .name("tx"), .contxt(get_full_name()));
                start_item(tx);
                tx.pixel = hex_val;
                finish_item(tx);
                pixel_count++;
            end
        end

        $fclose(in_file);
        `uvm_info("SEQ_RUN", $sformatf("Sent %0d pixels to DUT", pixel_count), UVM_LOW)
    endtask: body

endclass: my_uvm_sequence

typedef uvm_sequencer #(my_uvm_transaction) my_uvm_sequencer;
