# ============================================================================
# Vivado Non-Project Mode Build Script with Dynamic Generics
# ============================================================================
source "./constr/build.tlc"

set part_device "xc7k325tffg676-2"
# set part_device "xcku5p-ffvb676-1-i"
set cores       48
set clk_freq    210000000

set output_dir  "./build_vivado"

file mkdir $output_dir

puts "Starting compilation for device: $part_device"
puts "Generics -> CLK_FREQ: $clk_freq CORES: $cores"

# 2. Read RTL and constraints.
read_verilog [glob ./src/*.v]
read_xdc "./constr/kintex7.xdc"

# 3. Synthesize the top-level with parameter overrides.
synth_design -top top_kintex \
             -part $part_device \
             -generic [list CLK_FREQ=$clk_freq INPUT_CLK_FREQ=50000000 CORES=$cores]
            #  -flatten_hierarchy none

# Remap nonce register enables into datapath logic. This avoids a long routed
# compare-to-CE network that was previously the top failing path at 210 MHz.
set_property CONTROL_SET_REMAP ENABLE \
    [get_cells -hierarchical -regexp {.*current_nonce_reg\[[0-9]+\]$}]

# Reporting registers only sample when software reads them, so their source-to-
# shadow transfer does not need single-cycle setup.
set_multicycle_path 2 -setup \
    -from [get_cells -hierarchical -filter {NAME =~ *active_midstate_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_midstate_reg*}]
set_multicycle_path 1 -hold \
    -from [get_cells -hierarchical -filter {NAME =~ *active_midstate_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_midstate_reg*}]

set_multicycle_path 2 -setup \
    -from [get_cells -hierarchical -filter {NAME =~ *active_tail_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_tail_reg*}]
set_multicycle_path 1 -hold \
    -from [get_cells -hierarchical -filter {NAME =~ *active_tail_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_tail_reg*}]

set_multicycle_path 2 -setup \
    -from [get_cells -hierarchical -filter {NAME =~ *active_target_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_target_reg*}]
set_multicycle_path 1 -hold \
    -from [get_cells -hierarchical -filter {NAME =~ *active_target_reg*}] \
    -to [get_cells -hierarchical -filter {NAME =~ *job_target_reg*}]

report_utilization -file "${output_dir}/utilization_synth.rpt"
report_utilization -hierarchical -file "${output_dir}/utilization_synth_hier.rpt"

# 4. Implementation Steps
opt_design
place_design -directive Explore
phys_opt_design -directive AggressiveExplore
route_design -directive Explore

source ./capture_floorplan.tcl

report_design_analysis -file "${output_dir}/design_analysis_report.rpt"

# 5. Create timing report
report_timing_summary -file "${output_dir}/post_route_timing_summary.txt"
report_timing -max_paths 20 -file "${output_dir}/post_route_timing_paths.txt"

# 6. Safety DRC Checks & Bitstream Compilation
report_drc -file "${output_dir}/post_route_drc.txt"
write_bitstream -force "${output_dir}/pack.bit"

puts "Build Complete!"
exit
