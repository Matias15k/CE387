

# Top-level testbench signals
add wave -noupdate -group my_uvm_tb
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/clock
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/reset
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/in_wr_en
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/in_full
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/in_din
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/out_empty
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/out_rd_en
add wave -noupdate -group my_uvm_tb -radix unsigned    /my_uvm_tb/vif/out_dout
add wave -noupdate -group my_uvm_tb -radix unsigned    /my_uvm_tb/vif/predicted_digit
add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/vif/inference_done

# Neural net top
add wave -noupdate -group nn_top
add wave -noupdate -group nn_top -radix hexadecimal /my_uvm_tb/nn_top_inst/*

# Neural net core (FSM)
add wave -noupdate -group nn_core
add wave -noupdate -group nn_core -radix hexadecimal /my_uvm_tb/nn_top_inst/nn_core/*

# Input FIFO
add wave -noupdate -group fifo_in
add wave -noupdate -group fifo_in -radix hexadecimal /my_uvm_tb/nn_top_inst/fifo_in/*

# Output FIFO
add wave -noupdate -group fifo_out
add wave -noupdate -group fifo_out -radix hexadecimal /my_uvm_tb/nn_top_inst/fifo_out/*

# Layer 0
add wave -noupdate -group layer0
add wave -noupdate -group layer0 -radix hexadecimal /my_uvm_tb/nn_top_inst/nn_core/layer0/*

# Layer 1
add wave -noupdate -group layer1
add wave -noupdate -group layer1 -radix hexadecimal /my_uvm_tb/nn_top_inst/nn_core/layer1/*

