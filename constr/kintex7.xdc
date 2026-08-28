# ============================================================================
# Core Clock and System Interfaces
# ============================================================================
# Ensure you adjust the specific letter/number of these two pins to match your
# specific development board's fixed oscillator input and UART bridge lines.

create_clock -name clk -period $CLK_PERIOD_NS [get_ports clk]
set_property PACKAGE_PIN F22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]


set_property PACKAGE_PIN Y20 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

set_property PACKAGE_PIN Y21 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]


set_property PACKAGE_PIN B20 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN B21 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN B22 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN B24 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN B25 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN B26 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]


##############################################
#
#  WARNING WARNING WARNING 
#
#TODO: multimeter the jtag vref and unset one of these:
# set_property CFGBVS VCCO [current_design]
# set_property CONFIG_VOLTAGE 3.3 [current_design]
# set_property CFGBVS GND [current_design]
# set_property CONFIG_VOLTAGE 1.8 [current_design]

