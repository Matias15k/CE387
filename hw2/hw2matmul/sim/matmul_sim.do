setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/bram.sv"
vlog -work work "../sv/matmul.sv"
vlog -work work "../sv/matmul_top.sv"
vlog -work work "../sv/matmul_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.matmul_tb -wlf matmul.wlf

do matmul_wave.do

run -all