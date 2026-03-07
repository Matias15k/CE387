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

    // Performance counters
    longint unsigned start_time;
    longint unsigned end_time;
    int              num_correct;
    int              num_total;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out      = new("tx_out");
        tx_cmp      = new("tx_cmp");
        start_time  = 0;
        end_time    = 0;
        num_correct = 0;
        num_total   = 0;
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_export_output  = new("sb_export_output", this);
        sb_export_compare = new("sb_export_compare", this);
        output_fifo       = new("output_fifo", this);
        compare_fifo      = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        // Record start time
        start_time = $time;

        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run

    virtual function void comparison();
        end_time = $time;
        num_total++;

        if (tx_out.digit == tx_cmp.digit) begin
            num_correct++;
            `uvm_info("SB_CMP", $sformatf("PASS: Predicted=%0d, Expected=%0d", tx_out.digit, tx_cmp.digit), UVM_LOW);
        end else begin
            `uvm_error("SB_CMP", $sformatf("FAIL: Predicted=%0d, Expected=%0d", tx_out.digit, tx_cmp.digit));
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        longint unsigned total_cycles;
        super.report_phase(phase);

        total_cycles = (end_time - start_time) / CLOCK_PERIOD;

        `uvm_info("SB_REPORT", "========================================", UVM_LOW);
        `uvm_info("SB_REPORT", "     Neural Network Scoreboard Report   ", UVM_LOW);
        `uvm_info("SB_REPORT", "========================================", UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Total inferences:  %0d", num_total), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Correct:           %0d", num_correct), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Accuracy:          %0.1f%%", (num_total > 0) ? (100.0 * num_correct / num_total) : 0.0), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Clock cycles:      %0d", total_cycles), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Latency:           %0d ns", end_time - start_time), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Throughput:         %0.2f inferences/sec @ 100 MHz",
                  (num_total > 0 && total_cycles > 0) ? (1.0e9 / (total_cycles * CLOCK_PERIOD)) : 0.0), UVM_LOW);
        `uvm_info("SB_REPORT", "========================================", UVM_LOW);
    endfunction: report_phase

endclass: my_uvm_scoreboard
