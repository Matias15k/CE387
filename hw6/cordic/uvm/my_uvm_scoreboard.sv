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

    // Error tracking
    int total_samples;
    int sin_errors;
    int cos_errors;
    real max_sin_err;
    real max_cos_err;
    real sum_sin_err_sq;
    real sum_cos_err_sq;
    real sum_sin_err_abs;
    real sum_cos_err_abs;

    // Floating-point error tracking (vs ideal sin/cos)
    real max_sin_fp_err;
    real max_cos_fp_err;
    real sum_sin_fp_err;
    real sum_cos_fp_err;

    // Theta index for tracking which angle we're at
    int theta_deg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out = new("tx_out");
        tx_cmp = new("tx_cmp");
        total_samples   = 0;
        sin_errors      = 0;
        cos_errors      = 0;
        max_sin_err     = 0.0;
        max_cos_err     = 0.0;
        sum_sin_err_sq  = 0.0;
        sum_cos_err_sq  = 0.0;
        sum_sin_err_abs = 0.0;
        sum_cos_err_abs = 0.0;
        max_sin_fp_err  = 0.0;
        max_cos_fp_err  = 0.0;
        sum_sin_fp_err  = 0.0;
        sum_cos_fp_err  = 0.0;
        theta_deg       = -360;
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
        shortint signed out_sin, out_cos;
        shortint signed exp_sin, exp_cos;
        real sin_err_f, cos_err_f;
        real ideal_sin, ideal_cos;
        real fp_sin_err, fp_cos_err;
        real theta_rad;

        out_sin = shortint'(tx_out.sin_val);
        out_cos = shortint'(tx_out.cos_val);
        exp_sin = shortint'(tx_cmp.sin_val);
        exp_cos = shortint'(tx_cmp.cos_val);

        total_samples++;

        // =====================================================================
        // Check 1: Bit-true comparison against C software reference
        // =====================================================================
        if (out_sin != exp_sin) begin
            sin_errors++;
            `uvm_error("SB_CMP", $sformatf("SIN mismatch at theta=%0d deg (sample %0d): RTL=0x%04x, C_ref=0x%04x (diff=%0d)",
                theta_deg, total_samples, tx_out.sin_val, tx_cmp.sin_val, int'(out_sin) - int'(exp_sin)))
        end

        if (out_cos != exp_cos) begin
            cos_errors++;
            `uvm_error("SB_CMP", $sformatf("COS mismatch at theta=%0d deg (sample %0d): RTL=0x%04x, C_ref=0x%04x (diff=%0d)",
                theta_deg, total_samples, tx_out.cos_val, tx_cmp.cos_val, int'(out_cos) - int'(exp_cos)))
        end

        // Track bit-level error magnitude (RTL vs C reference)
        sin_err_f = $itor(int'(out_sin) - int'(exp_sin)) / $itor(CORDIC_QUANT);
        cos_err_f = $itor(int'(out_cos) - int'(exp_cos)) / $itor(CORDIC_QUANT);
        if (sin_err_f < 0) sin_err_f = -sin_err_f;
        if (cos_err_f < 0) cos_err_f = -cos_err_f;
        if (sin_err_f > max_sin_err) max_sin_err = sin_err_f;
        if (cos_err_f > max_cos_err) max_cos_err = cos_err_f;
        sum_sin_err_abs += sin_err_f;
        sum_cos_err_abs += cos_err_f;

        // =====================================================================
        // Check 2: Quantization precision vs ideal floating-point sin/cos
        // =====================================================================
        theta_rad = $itor(theta_deg) * 3.14159265358979323846 / 180.0;
        ideal_sin = $sin(theta_rad);
        ideal_cos = $cos(theta_rad);

        // Convert RTL fixed-point to floating-point and compare with ideal
        fp_sin_err = ($itor(out_sin) / $itor(CORDIC_QUANT)) - ideal_sin;
        fp_cos_err = ($itor(out_cos) / $itor(CORDIC_QUANT)) - ideal_cos;
        if (fp_sin_err < 0) fp_sin_err = -fp_sin_err;
        if (fp_cos_err < 0) fp_cos_err = -fp_cos_err;
        if (fp_sin_err > max_sin_fp_err) max_sin_fp_err = fp_sin_err;
        if (fp_cos_err > max_cos_fp_err) max_cos_fp_err = fp_cos_err;
        sum_sin_fp_err += fp_sin_err;
        sum_cos_fp_err += fp_cos_err;

        theta_deg++;
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        real avg_sin_fp_err, avg_cos_fp_err;
        real throughput;

        super.report_phase(phase);

        avg_sin_fp_err = (total_samples > 0) ? (sum_sin_fp_err / $itor(total_samples)) : 0.0;
        avg_cos_fp_err = (total_samples > 0) ? (sum_cos_fp_err / $itor(total_samples)) : 0.0;

        // Throughput: pipelined design produces 1 sample per clock at 100MHz
        throughput = 100000000.0;

        `uvm_info("SB_REPORT", "================================================================", UVM_LOW);
        `uvm_info("SB_REPORT", "              CORDIC Verification Report                        ", UVM_LOW);
        `uvm_info("SB_REPORT", "================================================================", UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("Total samples compared:     %0d", total_samples), UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", "  Bit-True Accuracy (RTL vs C Software Reference)               ", UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  SIN bit-true errors:      %0d / %0d", sin_errors, total_samples), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  COS bit-true errors:      %0d / %0d", cos_errors, total_samples), UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", "  Quantization Precision (Fixed-Point vs Ideal Float)           ", UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Fixed-point format:       Q1.%0d (%0d fractional bits)", CORDIC_BITS, CORDIC_BITS), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Quantization step size:   %0.10f", 1.0 / $itor(CORDIC_QUANT)), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Max SIN quant error:      %0.10f", max_sin_fp_err), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Max COS quant error:      %0.10f", max_cos_fp_err), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Avg SIN quant error:      %0.10f", avg_sin_fp_err), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Avg COS quant error:      %0.10f", avg_cos_fp_err), UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", "  Throughput                                                    ", UVM_LOW);
        `uvm_info("SB_REPORT", "----------------------------------------------------------------", UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Pipeline stages:          16"), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Pipeline latency:         16 clock cycles (160 ns)"), UVM_LOW);
        `uvm_info("SB_REPORT", $sformatf("  Throughput @ 100MHz:      %0.0f samples/sec", throughput), UVM_LOW);
        `uvm_info("SB_REPORT", "================================================================", UVM_LOW);

        if (sin_errors == 0 && cos_errors == 0) begin
            `uvm_info("SB_REPORT", "  RESULT: PASSED - Design is bit-true accurate vs C reference!", UVM_LOW);
        end else begin
            `uvm_info("SB_REPORT", $sformatf("  RESULT: FAILED - %0d total bit-true mismatches", sin_errors + cos_errors), UVM_LOW);
        end
        `uvm_info("SB_REPORT", "================================================================", UVM_LOW);
    endfunction: report_phase

endclass: my_uvm_scoreboard
