import uvm_pkg::*;

// =============================================================================
// Environment: instantiates agent, scoreboard, and coverage subscribers.
// Connects analysis ports following the coverage PDF example.
// =============================================================================
class my_uvm_env extends uvm_env;
    `uvm_component_utils(my_uvm_env)

    my_uvm_agent           agent;
    my_uvm_scoreboard      sb;
    my_uvm_coverage        cov;
    my_uvm_layer_coverage  layer_cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent     = my_uvm_agent::type_id::create(.name("agent"),     .parent(this));
        sb        = my_uvm_scoreboard::type_id::create(.name("sb"),   .parent(this));
        cov       = my_uvm_coverage::type_id::create("cov",           this);
        layer_cov = my_uvm_layer_coverage::type_id::create("layer_cov", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Scoreboard connections
        agent.agent_ap_output.connect(sb.sb_export_output);
        agent.agent_ap_compare.connect(sb.sb_export_compare);
        // Coverage connections (passive subscribers)
        agent.agent_ap_output.connect(cov.analysis_export);
        agent.agent_ap_output.connect(layer_cov.analysis_export);
    endfunction: connect_phase

endclass: my_uvm_env
