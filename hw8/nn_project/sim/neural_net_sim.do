
# ============================================================
# neural_net_sim.do
# Questa/ModelSim simulation script for neural network UVM TB
# Run from the sim/ directory:  vsim -do neural_net_sim.do
# ============================================================

setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# ----------------------------------------------------------
# Compile RTL: fifo, neuron, layer, argmax, neural_net, top
# ----------------------------------------------------------
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/neuron.sv"
vlog -work work "../sv/layer.sv"
vlog -work work "../sv/argmax.sv"
vlog -work work "../sv/neural_net.sv"
vlog -work work "../sv/neural_net_top.sv"

# ----------------------------------------------------------
# Compile UVM library
# ----------------------------------------------------------
vlog -work work +incdir+$env(UVM_HOME)/src \
    $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src \
    $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src \
    $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# ----------------------------------------------------------
# Compile UVM package and testbench
# ----------------------------------------------------------
vlog -work work +incdir+$env(UVM_HOME)/src \
    +incdir+../uvm "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src \
    +incdir+../uvm "../uvm/my_uvm_tb.sv"

# ----------------------------------------------------------
# Launch UVM simulation with coverage
# ----------------------------------------------------------
vsim -classdebug \
     -voptargs=+acc \
     +notimingchecks \
     -L work work.my_uvm_tb \
     -wlf neural_net_tb.wlf \
     -sv_lib lib/uvm_dpi \
     -dpicpppath /usr/bin/gcc \
     +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/ \
     -coverage

# Save coverage database on exit
coverage save -onexit coverage.ucdb

# Load waveform configuration
do neural_net_wave.do

# Run simulation to completion
run -all

# Generate coverage report
coverage report -details -output coverage_report.txt
