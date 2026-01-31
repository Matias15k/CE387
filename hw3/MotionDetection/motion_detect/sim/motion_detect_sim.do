setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# Compile the shared FIFO
vlog -work work "../sv/fifo.sv"

# Compile the sub-modules
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/subtract_background.sv"
vlog -work work "../sv/highlight_image.sv"

# Compile the Top Level and Testbench
vlog -work work "../sv/motion_detect_top.sv"
vlog -work work "../sv/motion_detect_tb.sv"

# Run Simulation
vsim -voptargs=+acc +notimingchecks -L work work.motion_detect_tb -wlf motion_detect_tb.wlf

do motion_detect_wave.do

run -all