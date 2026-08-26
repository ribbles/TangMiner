set_device GW1NR-LV9QN88PC6/I5 -device_version C

add_file src/bitcoin_hash_core.v
add_file src/sha256_compress.v
add_file src/uart_rx.v
add_file src/uart_tx.v
add_file src/top.v
add_file constr/tangnano9k.cst
add_file constr/tangnano9k.sdc


set_option -top_module top
set_option -verilog_std v2001
set_option -output_base_name top

run all
