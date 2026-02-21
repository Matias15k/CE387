
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

add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/x
add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/y
add wave -noupdate -group cordic_pipeline -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/z
add wave -noupdate -group cordic_pipeline /my_uvm_tb/cordic_inst/cordic_inst/valid
