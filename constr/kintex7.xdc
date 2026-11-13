# https://github.com/ribbles/QD_GY_V1.2


# ============================================================================
# Core Clock and System Interfaces
# ============================================================================
set_property PACKAGE_PIN AC23 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin [get_ports clk]

# JTAG / BANK 0
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# LEDS: output low lights up
set_property PACKAGE_PIN U26 [get_ports {led[0]}]
set_property PACKAGE_PIN V26 [get_ports {led[1]}]
set_property PACKAGE_PIN W26 [get_ports {led[2]}]
set_property PACKAGE_PIN Y26 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_property SLEW SLOW [get_ports {led[*]}]


# GPIO
# set_property PACKAGE_PIN  B9 	[get_ports {gpio_pins[0]}]
# set_property PACKAGE_PIN  B10	[get_ports {gpio_pins[1]}]
# set_property PACKAGE_PIN  A12	[get_ports {gpio_pins[2]}]
# set_property PACKAGE_PIN  A14	[get_ports {gpio_pins[3]}]
# set_property PACKAGE_PIN  A8 	[get_ports {gpio_pins[4]}]
# set_property PACKAGE_PIN  A9	[get_ports {gpio_pins[5]}]
# set_property PACKAGE_PIN  A10	[get_ports {gpio_pins[6]}]
# set_property PACKAGE_PIN  A13	[get_ports {gpio_pins[7]}]
# set_property PACKAGE_PIN AE21	[get_ports {gpio_pins[8]}]
# set_property PACKAGE_PIN AF23	[get_ports {gpio_pins[9]}]
# set_property PACKAGE_PIN AF24	[get_ports {gpio_pins[10]}]
# set_property PACKAGE_PIN AE25	[get_ports {gpio_pins[11]}]
# set_property PACKAGE_PIN AF22	[get_ports {gpio_pins[12]}]
# set_property PACKAGE_PIN AE22	[get_ports {gpio_pins[13]}]
# set_property PACKAGE_PIN AE23	[get_ports {gpio_pins[14]}]
# set_property PACKAGE_PIN AF25	[get_ports {gpio_pins[15]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[*]}]
# set_property PULLDOWN true [get_ports {gpio_pins[*]}]


# GPIO 7
set_property PACKAGE_PIN  AE21		[get_ports {uart_tx_pin}]
set_property IOSTANDARD LVCMOS33	[get_ports {uart_tx_pin}]
set_property PULLDOWN true			[get_ports {uart_tx_pin}]
# GPIO 6
set_property PACKAGE_PIN  AF23		[get_ports {uart_rx_pin}]
set_property IOSTANDARD LVCMOS33	[get_ports {uart_rx_pin}]
set_property PULLDOWN true			[get_ports {uart_rx_pin}]


# ============================================================================
# Complete user I/O Array (All 400 Functional Hardware Pins)
# ============================================================================
# HP: BANK 32-34 (1.8v)
# HR: BANK 12-16 (3.3v)
# IO_L6N_T0_VREF_12
# - IO: This is a standard user Input/Output pin.
# - L6N: It belongs to Line pair 6, and it is the Negative (complementary)(twin pit is IO_L6P)
# - T0: It belongs to Memory Byte Group 0 within that bank.
# - VREF: This is the dual-purpose function modifier.
# - 12: It is located physically inside Bank 12.
#
# awk '{printf "# %-5s %-8s BANK %s %s %s\nset_property PACKAGE_PIN %s\t[get_ports {gpio_pins[%d]}]\nset_property PULLUP TRUE\t[get_ports {gpio_pins[%d]}]\nset_property IOSTANDARD LVCMOS%s [get_ports {gpio_pins[%d]}]\n\n", $1, $2, $4, $7, $8, $1, NR-1, NR-1, $7, NR-1}' pins.tsv | sed s/LVCMOSHP/LVCMOS18/g | sed s/LVCMOSHR/LVCMOS33/g > kintex7.sdc.new 
