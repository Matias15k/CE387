
add wave -noupdate -group my_uvm_tb/cordic_inst
add wave -noupdate -group my_uvm_tb/cordic_inst -radix hexadecimal /my_uvm_tb/cordic_inst/*

add wave -noupdate -group my_uvm_tb/cordic_inst/cordic_inst
add wave -noupdate -group my_uvm_tb/cordic_inst/cordic_inst -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/*

add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_in_inst
add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_in_inst -radix hexadecimal /my_uvm_tb/cordic_inst/fifo_in_inst/*

add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_sin_inst
add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_sin_inst -radix hexadecimal /my_uvm_tb/cordic_inst/fifo_sin_inst/*

add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_cos_inst
add wave -noupdate -group my_uvm_tb/cordic_inst/fifo_cos_inst -radix hexadecimal /my_uvm_tb/cordic_inst/fifo_cos_inst/*

add wave -noupdate -group cordic_pipeline
add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe_x
add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe_y
add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe_z
add wave -noupdate -group cordic_pipeline /my_uvm_tb/cordic_inst/cordic_inst/pipe_valid
