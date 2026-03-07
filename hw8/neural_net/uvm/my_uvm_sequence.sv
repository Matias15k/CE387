import uvm_pkg::*;


// ---------------------------------------------------------------
// Transaction: carries either an input pixel or an output digit
// ---------------------------------------------------------------
class my_uvm_transaction extends uvm_sequence_item;
    logic [DATA_WIDTH-1:0] pixel;    // input data value
    logic [3:0]            digit;    // output classification

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(pixel, UVM_ALL_ON)
        `uvm_field_int(digit, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


// ---------------------------------------------------------------
// Sequence: reads x_test.txt and sends 784 input values
// ---------------------------------------------------------------
class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_file;
        int n_items = 0;
        logic [DATA_WIDTH-1:0] value;

        `uvm_info("SEQ_RUN", $sformatf("Loading input file %s...", INPUT_FILE), UVM_LOW);

        in_file = $fopen(INPUT_FILE, "r");
        if (!in_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s", INPUT_FILE));
        end

        while (!$feof(in_file) && n_items < NUM_INPUTS) begin
            if ($fscanf(in_file, "%08x", value) == 1) begin
                tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
                start_item(tx);
                tx.pixel = value;
                tx.digit = 4'b0;
                finish_item(tx);
                n_items++;
            end
        end

        `uvm_info("SEQ_RUN", $sformatf("Sent %0d input values. Closing file %s.", n_items, INPUT_FILE), UVM_LOW);
        $fclose(in_file);
    endtask: body
endclass: my_uvm_sequence


typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
