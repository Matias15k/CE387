# -----------------------------------------------------------
# ModelSim .do file for HW1
# -----------------------------------------------------------

# 1. Clean up and create the 'work' library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# 2. Compile the SystemVerilog files
# (Make sure these names match your actual file names)
vlog fibonacci.sv
vlog fibonacci_tb.sv

# 3. Load the simulation with FULL VISIBILITY
# -voptargs=+acc prevents ModelSim from optimizing away your signals
vsim -voptargs=+acc work.fibonacci_tb

# 4. Add signals to the Waveform window
# The '*' adds all signals in the testbench
add wave -position insertpoint sim:/fibonacci_tb/*

# Add the internal state of the instance 'fib' for debugging
add wave -group "Internal Signals" sim:/fibonacci_tb/fib/*

# 5. Format the Waveform window 
# This makes the signal names shorter (e.g., "clk" instead of "fibonacci_tb/clk")
config wave -signalnamewidth 1

# 6. Run the simulation
run -all

# 7. Zoom to fit the entire simulation in the view
wave zoom full