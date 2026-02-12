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

    // Counters for reporting
    int total_bytes;
    int error_count;
    int packet_count;

    // Functional coverage
    covergroup udp_cov;
        // Cover output data values
        data_byte: coverpoint tx_out.data {
            bins zero     = {0};
            bins low      = {[1:63]};
            bins mid_low  = {[64:127]};
            bins mid_high = {[128:191]};
            bins high     = {[192:254]};
            bins max_val  = {255};
        }
        // Cover SOF signal
        sof_signal: coverpoint tx_out.sof {
            bins no_sof  = {0};
            bins has_sof = {1};
        }
        // Cover EOF signal
        eof_signal: coverpoint tx_out.eof {
            bins no_eof  = {0};
            bins has_eof = {1};
        }
        // Cross coverage of SOF and EOF
        sof_eof_cross: cross sof_signal, eof_signal;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out = new("tx_out");
        tx_cmp = new("tx_cmp");
        udp_cov = new();
        total_bytes  = 0;
        error_count  = 0;
        packet_count = 0;
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

            // Sample functional coverage
            udp_cov.sample();

            // Track packets via SOF
            if (tx_out.sof == 1'b1) begin
                packet_count++;
                `uvm_info("SB_CMP", $sformatf("Start of packet %0d", packet_count), UVM_MEDIUM);
            end

            // Byte-wise comparison
            comparison();
            total_bytes++;

            // Track end of packets
            if (tx_out.eof == 1'b1) begin
                `uvm_info("SB_CMP", $sformatf("End of packet %0d (total bytes so far: %0d)", packet_count, total_bytes), UVM_MEDIUM);
            end
        end
    endtask: run

    virtual function void comparison();
        if (tx_out.data != tx_cmp.data) begin
            error_count++;
            `uvm_error("SB_CMP", $sformatf("MISMATCH at byte %0d: Expected 0x%02x, Received 0x%02x",
                total_bytes, tx_cmp.data, tx_out.data))
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB_REPORT", $sformatf("------- UDP Parser Scoreboard Report -------"), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Total bytes compared: %0d", total_bytes), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Total packets:        %0d", packet_count), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Total errors:         %0d", error_count), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Functional coverage:  %0.2f%%", udp_cov.get_coverage()), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("--------------------------------------------"), UVM_LOW);

        if (error_count == 0) begin
            `uvm_info("SB_REPORT", "*** TEST PASSED ***", UVM_LOW);
        end else begin
            `uvm_error("SB_REPORT", $sformatf("*** TEST FAILED with %0d errors ***", error_count));
        end
    endfunction: report_phase

endclass: my_uvm_scoreboard
