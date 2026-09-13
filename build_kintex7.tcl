# ============================================================================
# Vivado Non-Project Mode Build Script with Dynamic Generics
# ============================================================================
set_param general.maxThreads 16

set part_device "xc7k325tffg676-2"
# set part_device "xcku5p-ffvb676-1-i"
set cores       64
set clk_freq    210000000
set output_dir  "./build_vivado"

# Keep implementation directives overridable so timing sweeps can reuse the
# same build script without hand-editing the checked-in flow.
set place_directive    "Explore"
set phys_opt_directive "AggressiveExplore"
set route_directive    "Explore"

if {[info exists ::env(CORES_OVERRIDE)]} {
    set cores $::env(CORES_OVERRIDE)
}

if {[info exists ::env(CLK_FREQ_OVERRIDE)]} {
    set clk_freq $::env(CLK_FREQ_OVERRIDE)
}

if {[info exists ::env(VIVADO_OUTPUT_DIR)]} {
    set output_dir $::env(VIVADO_OUTPUT_DIR)
}

if {[info exists ::env(VIVADO_PLACE_DIRECTIVE)]} {
    set place_directive $::env(VIVADO_PLACE_DIRECTIVE)
}

if {[info exists ::env(VIVADO_PHYS_OPT_DIRECTIVE)]} {
    set phys_opt_directive $::env(VIVADO_PHYS_OPT_DIRECTIVE)
}

if {[info exists ::env(VIVADO_ROUTE_DIRECTIVE)]} {
    set route_directive $::env(VIVADO_ROUTE_DIRECTIVE)
}

set CLK_PERIOD_NS [expr {1000000000.0 / $clk_freq}]

file mkdir $output_dir

puts "Starting compilation for device: $part_device"
puts "Generics -> CLK_FREQ: $clk_freq CORES: $cores"
puts "Implementation -> PLACE: $place_directive PHYS_OPT: $phys_opt_directive ROUTE: $route_directive"

# 2. Read RTL and constraints.
read_verilog "./src/bitcoin_hash_core.v"
read_verilog "./src/sha256_compress.v"
read_verilog "./src/lt256.v"
read_verilog "./src/top.v"
read_verilog "./src/uart_rx.v"
read_verilog "./src/uart_tx.v"

read_xdc "./constr/kintex7.xdc"

# Treat the usual synthesis and constraint footguns as hard failures.
set_msg_config -id {Synth 8-327} -new_severity {ERROR}
set_msg_config -id {Synth 8-3352} -new_severity {ERROR}
set_msg_config -id {Synth 8-685} -new_severity {ERROR}
set_msg_config -id {Synth 8-3936} -new_severity {ERROR}
set_msg_config -id {Vivado 12-4366} -new_severity {ERROR}
set_msg_config -id {Timing 38-313} -new_severity {ERROR}
set_msg_config -id {Place 30-640} -new_severity {ERROR}
set_msg_config -id {Designutils 20-1307} -new_severity {ERROR}
set_msg_config -id {Vivado 12-4739} -new_severity {ERROR}
set_msg_config -id {Constraints 18-521} -new_severity {ERROR}
set_msg_config -id {Timing 38-249} -new_severity {ERROR}
# set_msg_config -id {Timing 38-3} -new_severity {ERROR}
set_msg_config -id {Place 30-487} -new_severity {ERROR}
set_msg_config -id {Place 30-974} -new_severity {ERROR}


# 3. Synthesize the top-level with parameter overrides.
synth_design -top top \
             -part $part_device \
             -generic [list CLK_FREQ=$clk_freq CORES=$cores]
            #  -flatten_hierarchy none

# Keep each mining core clustered in its own soft pblock so the placer preserves
# the floorplan intent without completely freezing local optimization.
create_pblock "pb_core_0"
add_cells_to_pblock [get_pblocks "pb_core_0"] [get_cells "core0"]
# set_property IS_SOFT TRUE [get_pblocks "pb_core_0"]

for {set i 1} {$i < $cores} {incr i} {
    create_pblock "pb_core_$i"
    add_cells_to_pblock [get_pblocks "pb_core_$i"] [get_cells "gg\[$i\].coreX"]
    # set_property IS_SOFT TRUE [get_pblocks "pb_core_$i"]
}

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
place_design -directive $place_directive
phys_opt_design -directive $phys_opt_directive
route_design -directive $route_directive

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
