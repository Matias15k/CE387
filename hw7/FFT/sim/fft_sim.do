
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# FFT RTL architecture (compile with coverage enabled)
vlog -work work +cover "../sv/fifo.sv"
vlog -work work +cover "../sv/butterfly.sv"
vlog -work work +cover "../sv/fft.sv"
vlog -work work +cover "../sv/fft_top.sv"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# start uvm simulation with coverage enabled
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/ -coverage

# save coverage database on exit
coverage save -onexit coverage.ucdb

do fft_wave.do

run -all

# generate coverage report
coverage report -details -output coverage_report.txt
#quit;
