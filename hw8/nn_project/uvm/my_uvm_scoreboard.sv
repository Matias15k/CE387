import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

// =============================================================================
// Scoreboard: compares DUT classification result against software reference.
// Reports accuracy and inference latency.
// =============================================================================
class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(my_uvm_transaction) sb_export_output;
    uvm_analysis_export #(my_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(my_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(my_uvm_transaction) compare_fifo;

    my_uvm_transaction tx_out;
    my_uvm_transaction tx_cmp;

    int pass_count;
    int fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out     = new("tx_out");
        tx_cmp     = new("tx_cmp");
        pass_count = 0;
        fail_count = 0;
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_export_output  = new("sb_export_output",  this);
        sb_export_compare = new("sb_export_compare", this);
        output_fifo       = new("output_fifo",  this);
        compare_fifo      = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run

    virtual function void comparison();
        logic [OUT_WIDTH-1:0] hw_class  = tx_out.pixel[OUT_WIDTH-1:0];
        logic [OUT_WIDTH-1:0] ref_class = tx_cmp.pixel[OUT_WIDTH-1:0];

        if (hw_class == ref_class) begin
            pass_count++;
            `uvm_info("SB_CMP",
                $sformatf("PASS — HW: %0d  REF: %0d", hw_class, ref_class),
                UVM_LOW)
        end else begin
            fail_count++;
            `uvm_error("SB_CMP",
                $sformatf("FAIL — HW: %0d  REF: %0d", hw_class, ref_class))
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB_REPORT",
            $sformatf("=== Accuracy: %0d/%0d correct ===",
                pass_count, pass_count + fail_count),
            UVM_LOW)
    endfunction: report_phase

endclass: my_uvm_scoreboard
