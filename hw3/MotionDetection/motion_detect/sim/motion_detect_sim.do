setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"

vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/subtract_background.sv"
vlog -work work "../sv/highlight_image.sv"

vlog -work work "../sv/motion_detect_top.sv"
vlog -work work "../sv/motion_detect_tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.motion_detect_tb -wlf motion_detect_tb.wlf

do motion_detect_wave.do

run -all