add wave -noupdate -group motion_detect_tb
add wave -noupdate -group motion_detect_tb -radix hexadecimal /motion_detect_tb/*

add wave -noupdate -group dut
add wave -noupdate -group dut -radix hexadecimal /motion_detect_tb/dut/*

add wave -noupdate -group dut/fifo_bg_in
add wave -noupdate -group dut/fifo_bg_in -radix hexadecimal /motion_detect_tb/dut/fifo_bg_in/*

add wave -noupdate -group dut/fifo_fr_proc
add wave -noupdate -group dut/fifo_fr_proc -radix hexadecimal /motion_detect_tb/dut/fifo_fr_proc/*

add wave -noupdate -group dut/fifo_fr_copy
add wave -noupdate -group dut/fifo_fr_copy -radix hexadecimal /motion_detect_tb/dut/fifo_fr_copy/*

add wave -noupdate -group dut/bg_gray_inst
add wave -noupdate -group dut/bg_gray_inst -radix hexadecimal /motion_detect_tb/dut/bg_gray_inst/*

add wave -noupdate -group dut/fr_gray_inst
add wave -noupdate -group dut/fr_gray_inst -radix hexadecimal /motion_detect_tb/dut/fr_gray_inst/*

add wave -noupdate -group dut/sub_inst
add wave -noupdate -group dut/sub_inst -radix hexadecimal /motion_detect_tb/dut/sub_inst/*

add wave -noupdate -group dut/hl_inst
add wave -noupdate -group dut/hl_inst -radix hexadecimal /motion_detect_tb/dut/hl_inst/*

add wave -noupdate -group dut/fifo_out
add wave -noupdate -group dut/fifo_out -radix hexadecimal /motion_detect_tb/dut/fifo_out/*