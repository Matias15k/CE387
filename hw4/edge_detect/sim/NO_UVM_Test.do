# 1. Initialize Simulation Library
vlib work
vmap work work

# 2. Compile RTL Files (Design)
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/sobel_filter.sv"
vlog -work work "../sv/edge_detection_top.sv"

# 3. Compile Testbench
vlog -work work "../sv/edge_detection_tb.sv"

# 4. Load Simulation
# We load 'edge_detection_tb' directly. 
# -voptargs=+acc ensures signals are visible in the waveform
vsim -voptargs=+acc work.edge_detection_tb

# 5. Add Waves
# Simple command to add all signals in the testbench
add wave -noupdate /edge_detection_tb/*
add wave -noupdate -group DUT /edge_detection_tb/dut/*
add wave -noupdate -group Sobel /edge_detection_tb/dut/sobel_inst/*

# 6. Run
run -all