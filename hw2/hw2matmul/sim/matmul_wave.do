add wave -noupdate -group matmul_tb
add wave -noupdate -group matmul_tb -radix hexadecimal /matmul_tb/*

add wave -noupdate -group matmul_tb/matmul_top_inst
add wave -noupdate -group matmul_tb/matmul_top_inst -radix hexadecimal /matmul_tb/matmul_top_inst/*

add wave -noupdate -group matmul_tb/matmul_top_inst/matmul_inst
add wave -noupdate -group matmul_tb/matmul_top_inst/matmul_inst -radix hexadecimal /matmul_tb/matmul_top_inst/matmul_inst/*

add wave -noupdate -group matmul_tb/matmul_top_inst/bram_a
add wave -noupdate -group matmul_tb/matmul_top_inst/bram_a -radix hexadecimal /matmul_tb/matmul_top_inst/bram_a/*

add wave -noupdate -group matmul_tb/matmul_top_inst/bram_b
add wave -noupdate -group matmul_tb/matmul_top_inst/bram_b -radix hexadecimal /matmul_tb/matmul_top_inst/bram_b/*

add wave -noupdate -group matmul_tb/matmul_top_inst/bram_c
add wave -noupdate -group matmul_tb/matmul_top_inst/bram_c -radix hexadecimal /matmul_tb/matmul_top_inst/bram_c/*