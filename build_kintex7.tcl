# ============================================================================
# Vivado Non-Project Mode Build Script with Dynamic Generics
# ============================================================================
set_param general.maxThreads 16

set part_device "xc7k325tffg676-2"
set cores       "80"
set clk_freq    "650000000"
set output_dir  "./build_vivado"

file mkdir $output_dir

puts "Starting compilation for device: $part_device"
puts "Generics -> CLK_FREQ: $clk_freq CORES: $cores"

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
             -generic [list CLK_FREQ=$clk_freq CORES=$cores] 
            #  -flatten_hierarchy none

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
