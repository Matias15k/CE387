
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# Neural network RTL architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/neuron.sv"
vlog -work work "../sv/layer.sv"
vlog -work work "../sv/argmax.sv"
vlog -work work "../sv/neural_net.sv"
vlog -work work "../sv/neural_net_top.sv"

# UVM library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# UVM package and testbench
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# Start UVM simulation with coverage enabled
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/ -coverage

# Save coverage database on exit
coverage save -onexit coverage.ucdb

do neural_net_wave.do

run -all

# Generate coverage report
coverage report -details -output coverage_report.txt
#quit;
