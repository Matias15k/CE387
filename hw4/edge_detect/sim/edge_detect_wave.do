add wave -noupdate -group my_uvm_tb
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

# Top Level DUT Signals
add wave -noupdate -group DUT
add wave -noupdate -group DUT -radix hexadecimal /my_uvm_tb/dut/*

# Grayscale Stage
add wave -noupdate -group DUT/Grayscale
add wave -noupdate -group DUT/Grayscale -radix hexadecimal /my_uvm_tb/dut/grayscale_inst/*

# Intermediate FIFO (GS -> Sobel)
add wave -noupdate -group DUT/FIFO_Mid
add wave -noupdate -group DUT/FIFO_Mid -radix hexadecimal /my_uvm_tb/dut/fifo_gs_to_sobel/*

# Sobel Stage (Detailed)
add wave -noupdate -group DUT/Sobel
add wave -noupdate -group DUT/Sobel -radix hexadecimal /my_uvm_tb/dut/sobel_inst/*

# Sobel Line Buffers
add wave -noupdate -group DUT/Sobel/LineBuffer0
add wave -noupdate -group DUT/Sobel/LineBuffer0 -radix hexadecimal /my_uvm_tb/dut/sobel_inst/lb0/*

add wave -noupdate -group DUT/Sobel/LineBuffer1
add wave -noupdate -group DUT/Sobel/LineBuffer1 -radix hexadecimal /my_uvm_tb/dut/sobel_inst/lb1/*