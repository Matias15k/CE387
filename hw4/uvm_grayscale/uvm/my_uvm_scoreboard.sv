import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(my_uvm_transaction) sb_export_output;
    uvm_analysis_export #(my_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(my_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(my_uvm_transaction) compare_fifo;

    my_uvm_transaction tx_out;
    my_uvm_transaction tx_cmp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out    = new("tx_out");
        tx_cmp    = new("tx_cmp");
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_export_output    = new("sb_export_output", this);
        sb_export_compare   = new("sb_export_compare", this);
        output_fifo         = new("output_fifo", this);
        compare_fifo        = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        // -----------------------------------------------------------
        // ALIGNMENT FIX:
        // The RTL pipeline latency is exactly 1 Row (IMG_WIDTH).
        // The RTL outputs 0s for the first row, while the C-Model 
        // expects data. We discard the first row of RTL output 
        // so that RTL Row 2 (Data) aligns with Ref Row 1 (Data).
        // -----------------------------------------------------------
        repeat(IMG_WIDTH) begin
            my_uvm_transaction dummy;
            output_fifo.get(dummy);
        end

        // Now the streams are aligned, start the comparison
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);            
            comparison();
        end
    endtask: run

    virtual function void comparison();
        if (tx_out.image_pixel != tx_cmp.image_pixel) begin
            // We can keep uvm_error now because errors should be zero.
            `uvm_error("SB_CMP", $sformatf("Mismatch! Exp: %06x, Rec: %06x", tx_cmp.image_pixel, tx_out.image_pixel))
        end
    endfunction: comparison
endclass: my_uvm_scoreboard