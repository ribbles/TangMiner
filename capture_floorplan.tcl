# dump_all.tcl
set report_file [open "./${output_dir}/placement_dump.txt" "w"]

# 1. Dump ALL Pblocks in the entire design (no filters)
foreach pb [get_pblocks] {
    set grid [get_property GRID_RANGES $pb]
    puts $report_file "PBLOCK|$pb|$grid"
}

# 2. Dump ALL placed primitives (every single component on the silicon)
foreach cell [get_cells -hierarchical -filter {IS_PRIMITIVE && LOC != ""}] {
    set loc [get_property LOC $cell]
    set type [get_property PRIME_TYPE $cell]
    set pblock [get_property PBLOCK $cell]
    puts $report_file "CELL|$cell|$type|$loc|$pblock"
}

close $report_file
