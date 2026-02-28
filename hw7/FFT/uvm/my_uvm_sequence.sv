import uvm_pkg::*;

// -----------------------------------------------------------
// Transaction: one complex FFT sample (real + imaginary)
// plus a sample index for coverage tracking
// -----------------------------------------------------------
class my_uvm_transaction extends uvm_sequence_item;
    logic signed [DATA_WIDTH-1:0] data_real;
    logic signed [DATA_WIDTH-1:0] data_imag;
    int                           sample_index;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(data_real,     UVM_ALL_ON)
        `uvm_field_int(data_imag,     UVM_ALL_ON)
        `uvm_field_int(sample_index,  UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction

// -----------------------------------------------------------
// Sequence: reads N complex input samples from hex text files
// -----------------------------------------------------------
class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_real_file, in_imag_file;
        int scan_r, scan_i;
        logic [DATA_WIDTH-1:0] val_real, val_imag;
        int i;

        `uvm_info("SEQ_RUN", $sformatf("Loading files %s and %s...",
                  FFT_IN_REAL_NAME, FFT_IN_IMAG_NAME), UVM_LOW);

        in_real_file = $fopen(FFT_IN_REAL_NAME, "r");
        in_imag_file = $fopen(FFT_IN_IMAG_NAME, "r");

        if (!in_real_file)
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s", FFT_IN_REAL_NAME));
        if (!in_imag_file)
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s", FFT_IN_IMAG_NAME));

        i = 0;
        while (i < FFT_N) begin
            tx = my_uvm_transaction::type_id::create(
                .name("tx"), .contxt(get_full_name()));
            start_item(tx);

            scan_r = $fscanf(in_real_file, "%h", val_real);
            scan_i = $fscanf(in_imag_file, "%h", val_imag);

            tx.data_real     = $signed(val_real);
            tx.data_imag     = $signed(val_imag);
            tx.sample_index  = i;

            `uvm_info("SEQ_RUN", $sformatf("Input[%0d]: real=%08x imag=%08x",
                      i, tx.data_real, tx.data_imag), UVM_MEDIUM);

            finish_item(tx);
            i++;
        end

        `uvm_info("SEQ_RUN", "Closing input files...", UVM_LOW);
        $fclose(in_real_file);
        $fclose(in_imag_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
