# ============================================================================
# Vivado Non-Project Mode Build Script with Dynamic Generics
# ============================================================================

# 1. Gather Configuration parameters from Makefile Environment
set part_device [expr {[info exists ::env(DEVICE)] ? $::env(DEVICE) : "xc7k325tffg676-2"}]
set clk_freq    [expr {[info exists ::env(CLK_FREQ)] ? $::env(CLK_FREQ) : "100000000"}]

set output_dir "./build_vivado"
file mkdir $output_dir

puts "Starting compilation for device: $part_device"
puts "Generics -> CLK_FREQ: $clk_freq"

# 2. Ingest Source Files
read_verilog "./src/bitcoin_hash_core.v"
read_verilog "./src/sha256_compress.v"
read_verilog "./src/top.v"
read_verilog "./src/uart_rx.v"
read_verilog "./src/uart_tx.v"

read_xdc "./constr/kintex7.xdc"

# 3. Run Synthesis with Parameter Overrides
# The -generic flag passes values directly to your Verilog module parameters
synth_design -top top \
             -part $part_device \
             -generic [list CLK_FREQ=$clk_freq] \
             -flatten_hierarchy none

# 4. Implementation Steps
opt_design
place_design
phys_opt_design
route_design

# 5. Safety DRC Checks & Bitstream Compilation
report_drc -file "${output_dir}/post_route_drc.txt"
write_bitstream -force "${output_dir}/pack.bit"

puts "Build Complete!"
exit
