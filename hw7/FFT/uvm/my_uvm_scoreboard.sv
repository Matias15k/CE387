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

    // Functional coverage
    covergroup fft_coverage;
        coverpoint tx_out.data_real {
            bins negative = {[$signed(-32'h80000000):$signed(-32'h1)]};
            bins zero     = {0};
            bins positive = {[$signed(32'h1):$signed(32'h7FFFFFFF)]};
        }
        coverpoint tx_out.data_imag {
            bins negative = {[$signed(-32'h80000000):$signed(-32'h1)]};
            bins zero     = {0};
            bins positive = {[$signed(32'h1):$signed(32'h7FFFFFFF)]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out = new("tx_out");
        tx_cmp = new("tx_cmp");
        total_samples = 0;
        error_count   = 0;
        fft_coverage = new();
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sb_export_output  = new("sb_export_output", this);
        sb_export_compare = new("sb_export_compare", this);

        output_fifo  = new("output_fifo", this);
        compare_fifo = new("compare_fifo", this);
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
        total_samples++;
        fft_coverage.sample();

        if (tx_out.data_real != tx_cmp.data_real ||
            tx_out.data_imag != tx_cmp.data_imag) begin
            error_count++;
            `uvm_error("SB_CMP", $sformatf(
                "Sample %0d MISMATCH: Expected real=%08x imag=%08x, Got real=%08x imag=%08x",
                total_samples - 1,
                tx_cmp.data_real, tx_cmp.data_imag,
                tx_out.data_real, tx_out.data_imag))
        end else begin
            `uvm_info("SB_CMP", $sformatf(
                "Sample %0d MATCH: real=%08x imag=%08x",
                total_samples - 1,
                tx_out.data_real, tx_out.data_imag), UVM_MEDIUM)
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB_REPORT", $sformatf(
            "\n========================================\n" +
            "  FFT Verification Summary\n" +
            "========================================\n" +
            "  Total samples compared: %0d\n" +
            "  Errors:                 %0d\n" +
            "  Status:                 %s\n" +
            "========================================",
            total_samples, error_count,
            (error_count == 0) ? "PASS" : "FAIL"), UVM_LOW);
    endfunction: report_phase

endclass: my_uvm_scoreboard
