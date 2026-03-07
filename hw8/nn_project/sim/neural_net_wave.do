
# Neural Network waveform configuration

add wave -noupdate -group my_uvm_tb/dut
add wave -noupdate -group my_uvm_tb/dut -radix hexadecimal /my_uvm_tb/dut/*

add wave -noupdate -group my_uvm_tb/dut/nn_inst
add wave -noupdate -group my_uvm_tb/dut/nn_inst -radix hexadecimal /my_uvm_tb/dut/nn_inst/*

add wave -noupdate -group my_uvm_tb/dut/nn_inst/layer_0
add wave -noupdate -group my_uvm_tb/dut/nn_inst/layer_0 -radix hexadecimal /my_uvm_tb/dut/nn_inst/layer_0/*

add wave -noupdate -group my_uvm_tb/dut/nn_inst/layer_1
add wave -noupdate -group my_uvm_tb/dut/nn_inst/layer_1 -radix hexadecimal /my_uvm_tb/dut/nn_inst/layer_1/*

add wave -noupdate -group my_uvm_tb/dut/nn_inst/argmax_inst
add wave -noupdate -group my_uvm_tb/dut/nn_inst/argmax_inst -radix hexadecimal /my_uvm_tb/dut/nn_inst/argmax_inst/*

add wave -noupdate -group my_uvm_tb/dut/fifo_in_inst
add wave -noupdate -group my_uvm_tb/dut/fifo_in_inst -radix hexadecimal /my_uvm_tb/dut/fifo_in_inst/*

add wave -noupdate -group my_uvm_tb/dut/fifo_out_inst
add wave -noupdate -group my_uvm_tb/dut/fifo_out_inst -radix hexadecimal /my_uvm_tb/dut/fifo_out_inst/*
