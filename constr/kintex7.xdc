# https://github.com/ribbles/QD_GY_V1.2


# ============================================================================
# Core Clock and System Interfaces
# ============================================================================
set_property PACKAGE_PIN AC23 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
# 50MHz oscillator
create_clock -period 20.000 -name sys_clk_pin [get_ports sys_clk]

# JTAG / BANK 0
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# UART
# AF24  IO_L20P_T3_12 BANK 12 HR 7K70T >>>>> GPIO 14
set_property PACKAGE_PIN AF24	[get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]
# AE25  IO_L23N_T3_12 BANK 12 HR 7K70T >>>>> GPIO 15
set_property PACKAGE_PIN AE25 [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]



# LEDS: output low lights up
set_property PACKAGE_PIN U26 [get_ports {led[0]}]
set_property SLEW SLOW [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN V26 [get_ports {led[1]}]
set_property SLEW SLOW [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN W26 [get_ports {led[2]}]
set_property SLEW SLOW [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN Y26 [get_ports {led[3]}]
set_property SLEW SLOW [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# # GPIO
# # A12   IO_L24N_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN B9 	[get_ports {gpio_pins[0]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[0]}]

# # B10   IO_L22P_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN B10    [get_ports {gpio_pins[1]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[1]}]

# # A10   IO_L22N_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN A12	[get_ports {gpio_pins[2]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[2]}]

# # A12   IO_L24N_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN A14	[get_ports {gpio_pins[3]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[3]}]

# # A8    IO_L9N_T1_DQS_16 BANK 16 HR NA
# set_property PACKAGE_PIN A8 	[get_ports {gpio_pins[4]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[4]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[4]}]

# # A9    IO_L9P_T1_DQS_16 BANK 16 HR NA
# set_property PACKAGE_PIN A9	    [get_ports {gpio_pins[5]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[5]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[5]}]

# # A10   IO_L22N_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN A10	[get_ports {gpio_pins[6]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[6]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[6]}]

# # A13   IO_L24P_T3_16 BANK 16 HR NA
# set_property PACKAGE_PIN A13	[get_ports {gpio_pins[7]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[7]}]

# # AF22  IO_L24N_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AF22	[get_ports {gpio_pins[8]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[8]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[8]}]

# # AE22  IO_L24P_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AE22	[get_ports {gpio_pins[9]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[9]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[9]}]

# # AE23  IO_L22P_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AE23	[get_ports {gpio_pins[10]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[10]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[10]}]

# # AF25  IO_L20N_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AF25	[get_ports {gpio_pins[11]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[11]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[11]}]

# # AE21  IO_L19N_T3_VREF_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AE21	[get_ports {gpio_pins[12]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[12]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[12]}]

# # AF23  IO_L22N_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AF23	[get_ports {gpio_pins[13]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[13]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[13]}]

# # # AF24  IO_L20P_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AF24	[get_ports {gpio_pins[14]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[14]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[14]}]

# # AE25  IO_L23N_T3_12 BANK 12 HR 7K70T
# set_property PACKAGE_PIN AE25	[get_ports {gpio_pins[15]}]
# set_property PULLUP TRUE	    [get_ports {gpio_pins[15]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {gpio_pins[15]}]
