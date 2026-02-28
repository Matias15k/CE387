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

    int total_samples;
    int error_count;
    longint unsigned first_output_time;
    longint unsigned last_output_time;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out        = new("tx_out");
        tx_cmp        = new("tx_cmp");
        total_samples = 0;
        error_count   = 0;
        first_output_time = 0;
        last_output_time  = 0;
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
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run

    virtual function void comparison();
        // Timestamp tracking
        if (total_samples == 0)
            first_output_time = $time;
        last_output_time = $time;

        total_samples++;

        if (tx_out.data_real != tx_cmp.data_real ||
            tx_out.data_imag != tx_cmp.data_imag) begin
            error_count++;
            `uvm_error("SB_CMP", $sformatf(
                "Y[%0d] MISMATCH: Exp real=%08x imag=%08x, Got real=%08x imag=%08x",
                tx_cmp.sample_index,
                tx_cmp.data_real, tx_cmp.data_imag,
                tx_out.data_real, tx_out.data_imag))
        end else begin
            `uvm_info("SB_CMP", $sformatf(
                "Y[%0d] MATCH: real=%08x imag=%08x",
                tx_out.sample_index,
                tx_out.data_real, tx_out.data_imag), UVM_MEDIUM)
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        longint unsigned output_cycles;
        super.report_phase(phase);

        output_cycles = (last_output_time - first_output_time) / CLOCK_PERIOD;

        `uvm_info("SB_REPORT", $sformatf({"\n",
            "========================================\n",
            "  FFT Verification Summary\n",
            "========================================\n",
            "  Total samples compared: %0d\n",
            "  Errors (mismatches):    %0d\n",
            "  Bit-true accuracy:      %s\n",
            "----------------------------------------\n",
            "  Throughput & Latency\n",
            "----------------------------------------\n",
            "  FFT size (N):           %0d\n",
            "  Pipeline stages:        %0d\n",
            "  Clock period:           %0d ns (100 MHz)\n",
            "  Pipeline fill latency:  %0d cycles\n",
            "    (N load + stages+1 compute)\n",
            "  Output streaming:       1 sample/cycle\n",
            "  Output cycles:          %0d\n",
            "  Throughput:             %0d Msamples/sec\n",
            "========================================"},
            total_samples,
            error_count,
            (error_count == 0) ? "PASS - 100%% bit-exact" : "FAIL",
            FFT_N,
            NUM_STAGES,
            CLOCK_PERIOD,
            FFT_N + NUM_STAGES + 1,
            output_cycles,
            1000 / CLOCK_PERIOD), UVM_LOW);
    endfunction: report_phase

endclass: my_uvm_scoreboard
