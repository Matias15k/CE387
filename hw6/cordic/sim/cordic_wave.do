
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

add wave -noupdate -group cordic_stage_0 -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe[0]/stage_inst/*
add wave -noupdate -group cordic_stage_7 -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe[7]/stage_inst/*
add wave -noupdate -group cordic_stage_15 -radix hexadecimal /my_uvm_tb/cordic_inst/cordic_inst/pipe[15]/stage_inst/*
