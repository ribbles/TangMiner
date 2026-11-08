
# ============================================================================
# Clocks
# ============================================================================
# sys_clk_p: schematic SYS_CLK_P | package T25 | bank 65 | VCCO 1.2 V | LVDS
set_property -dict {PACKAGE_PIN T25 IOSTANDARD LVDS} [get_ports sys_clk_p]
# sys_clk_n: schematic SYS_CLK_N | package U25 | bank 65 | VCCO 1.2 V | LVDS
set_property -dict {PACKAGE_PIN U25 IOSTANDARD LVDS} [get_ports sys_clk_n]
# Y1 is the 100 MHz differential system oscillator (10.000 ns period).
create_clock -name sys_clk -period 10.000 [get_ports sys_clk_p]

# 100MHz oscillator
# create_generated_clock -name sys_clk -source [get_ports sys_clk_p] -multiply_by 1 [get_pins my_pll/CLKOUT0]


# gclk1: schematic GCLK1 | package AB15 | bank 84 | VCCO 3.3 V | LVCMOS33
# set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS33} [get_ports gclk1]
# gclk2: schematic GCLK2 | package E18 | bank 67 | VCCO 1.8 V | LVCMOS18
# set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS18} [get_ports gclk2]


# uart_tx: J2 pin 23 | schematic AE13 | package AE13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS33} [get_ports {uart_tx}]



# ============================================================================
# LEDs
# ============================================================================
# led[0]: LED V1, active low | package A9 | bank 86 | VCCO 3.3 V | J2 pin 86
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
# led[1]: LED V2, active low | package B10 | bank 86 | VCCO 3.3 V | J2 pin 82
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# led[2]: LED V3, active low | package A10 | bank 86 | VCCO 3.3 V | J2 pin 84
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports {led[2]}]

# GPIO vector ordering is physical, not by FPGA bank:
#   gpio[0:53]    = J1 pins 25 through 78
#   gpio[54:117]  = J2 pins 19 through 81, then pin 83
#   gpio[118:175] = J3 pins 21 through 62, then 65 through 80
# Power, ground, unlabelled/NC positions, J3 ADC_VN/ADC_VP, and LEDs are not GPIO.
# Each P/N-capable jumper signal is intentionally constrained as independent
# single-ended GPIO; replace both members' IOSTANDARD when using LVDS.
#
# Supply rails from voltages.png:
#   VCCINT/VCCINT_IO/VCCBRAM = 0.85 V
#   VBATT/VCCAUX/VCCAUX_IO   = 1.8 V
#   VCCO bank 0              = 1.8 V (configuration bank)
#   VCCO banks 64/67         = 1.8 V
#   VCCO banks 65/66         = 1.2 V
#   VCCO banks 84/86/87      = 3.3 V
set_property CONFIG_VOLTAGE 1.8 [current_design]
# set_property CONFIG_MODE SPIx4 [current_design]
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# ============================================================================
# Jumper GPIO
# ============================================================================
# Complete connector-position notes (positions not listed as GPIO below):
#   J1 1-6 GND; 7-10 VDD12; 11-14 GND; 15-16 VDD3.3;
#      17-24 and 79-100 unlabelled.
#   J2 1-18, 85, and 87-100 unlabelled.
#   J3 1-4 GND; 5-20 unlabelled; 63 ADC_VN; 64 ADC_VP; 81-82 GND;
#      83-100 unlabelled.
# "Unlabelled" means only that no net name is present in the supplied image;
# it is not an electrical assertion that the connector position is NC.

# J1: jumper-order GPIO
# gpio[0]: J1 pin 25 | schematic 66_L8_P | package M25 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN M25 IOSTANDARD LVCMOS12} [get_ports {gpio[0]}]
# gpio[1]: J1 pin 26 | schematic 66_L8_N | package M26 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN M26 IOSTANDARD LVCMOS12} [get_ports {gpio[1]}]
# gpio[2]: J1 pin 27 | schematic 66_L10_P | package L24 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN L24 IOSTANDARD LVCMOS12} [get_ports {gpio[2]}]
# gpio[3]: J1 pin 28 | schematic 66_L10_N | package L25 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN L25 IOSTANDARD LVCMOS12} [get_ports {gpio[3]}]
# gpio[4]: J1 pin 29 | schematic 65_L22_P | package N23 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN N23 IOSTANDARD LVCMOS12} [get_ports {gpio[4]}]
# gpio[5]: J1 pin 30 | schematic 65_L22_N | package P23 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P23 IOSTANDARD LVCMOS12} [get_ports {gpio[5]}]
# gpio[6]: J1 pin 31 | schematic 65_L21_P | package R20 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVCMOS12} [get_ports {gpio[6]}]
# gpio[7]: J1 pin 32 | schematic 65_L21_N | package R21 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVCMOS12} [get_ports {gpio[7]}]
# gpio[8]: J1 pin 33 | schematic 64_L19_N | package Y21 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN Y21 IOSTANDARD LVCMOS18} [get_ports {gpio[8]}]
# gpio[9]: J1 pin 34 | schematic 64_L19_P | package Y20 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN Y20 IOSTANDARD LVCMOS18} [get_ports {gpio[9]}]
# gpio[10]: J1 pin 35 | schematic 64_L6_N | package AC24 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC24 IOSTANDARD LVCMOS18} [get_ports {gpio[10]}]
# gpio[11]: J1 pin 36 | schematic 64_L6_P | package AB24 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB24 IOSTANDARD LVCMOS18} [get_ports {gpio[11]}]
# gpio[12]: J1 pin 37 | schematic 64_L4_P | package AC26 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS18} [get_ports {gpio[12]}]
# gpio[13]: J1 pin 38 | schematic 64_L4_N | package AD26 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVCMOS18} [get_ports {gpio[13]}]
# gpio[14]: J1 pin 39 | schematic 64_L1_P | package AE25 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE25 IOSTANDARD LVCMOS18} [get_ports {gpio[14]}]
# gpio[15]: J1 pin 40 | schematic 64_L1_N | package AE26 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVCMOS18} [get_ports {gpio[15]}]
# gpio[16]: J1 pin 41 | schematic 65_L18_P | package R25 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN R25 IOSTANDARD LVCMOS12} [get_ports {gpio[16]}]
# gpio[17]: J1 pin 42 | schematic 65_L18_N | package R26 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN R26 IOSTANDARD LVCMOS12} [get_ports {gpio[17]}]
# gpio[18]: J1 pin 43 | schematic 65_L16_N | package V26 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVCMOS12} [get_ports {gpio[18]}]
# gpio[19]: J1 pin 44 | schematic 65_L16_P | package U26 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN U26 IOSTANDARD LVCMOS12} [get_ports {gpio[19]}]
# gpio[20]: J1 pin 45 | schematic 64_L3_P | package AF24 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF24 IOSTANDARD LVCMOS18} [get_ports {gpio[20]}]
# gpio[21]: J1 pin 46 | schematic 64_L3_N | package AF25 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF25 IOSTANDARD LVCMOS18} [get_ports {gpio[21]}]
# gpio[22]: J1 pin 47 | schematic 64_L2_N | package AB26 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB26 IOSTANDARD LVCMOS18} [get_ports {gpio[22]}]
# gpio[23]: J1 pin 48 | schematic 64_L2_P | package AB25 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB25 IOSTANDARD LVCMOS18} [get_ports {gpio[23]}]
# gpio[24]: J1 pin 49 | schematic 64_L5_N | package AD25 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD25 IOSTANDARD LVCMOS18} [get_ports {gpio[24]}]
# gpio[25]: J1 pin 50 | schematic 64_L5_P | package AD24 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD24 IOSTANDARD LVCMOS18} [get_ports {gpio[25]}]
# gpio[26]: J1 pin 51 | schematic 64_L12_P | package AB21 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS18} [get_ports {gpio[26]}]
# gpio[27]: J1 pin 52 | schematic 64_L12_N | package AC21 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC21 IOSTANDARD LVCMOS18} [get_ports {gpio[27]}]
# gpio[28]: J1 pin 53 | schematic 64_L9_N | package AC23 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC23 IOSTANDARD LVCMOS18} [get_ports {gpio[28]}]
# gpio[29]: J1 pin 54 | schematic 64_L9_P | package AC22 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC22 IOSTANDARD LVCMOS18} [get_ports {gpio[29]}]
# gpio[30]: J1 pin 55 | schematic 64_L7_P | package AE22 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE22 IOSTANDARD LVCMOS18} [get_ports {gpio[30]}]
# gpio[31]: J1 pin 56 | schematic 64_L7_N | package AF22 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF22 IOSTANDARD LVCMOS18} [get_ports {gpio[31]}]
# gpio[32]: J1 pin 57 | schematic 64_L11_P | package AD21 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD21 IOSTANDARD LVCMOS18} [get_ports {gpio[32]}]
# gpio[33]: J1 pin 58 | schematic 64_L11_N | package AE21 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE21 IOSTANDARD LVCMOS18} [get_ports {gpio[33]}]
# gpio[34]: J1 pin 59 | schematic 64_L24_P | package Y18 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS18} [get_ports {gpio[34]}]
# gpio[35]: J1 pin 60 | schematic 64_L24_N | package AA18 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS18} [get_ports {gpio[35]}]
# gpio[36]: J1 pin 61 | schematic 64_L15_N | package AF19 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF19 IOSTANDARD LVCMOS18} [get_ports {gpio[36]}]
# gpio[37]: J1 pin 62 | schematic 64_L15_P | package AF18 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF18 IOSTANDARD LVCMOS18} [get_ports {gpio[37]}]
# gpio[38]: J1 pin 63 | schematic 64_L21_N | package AB20 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS18} [get_ports {gpio[38]}]
# gpio[39]: J1 pin 64 | schematic 64_L21_P | package AA20 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS18} [get_ports {gpio[39]}]
# gpio[40]: J1 pin 65 | schematic 64_L17_P | package AE17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE17 IOSTANDARD LVCMOS18} [get_ports {gpio[40]}]
# gpio[41]: J1 pin 66 | schematic 64_L17_N | package AF17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF17 IOSTANDARD LVCMOS18} [get_ports {gpio[41]}]
# gpio[42]: J1 pin 67 | schematic 64_L16_N | package AD18 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD18 IOSTANDARD LVCMOS18} [get_ports {gpio[42]}]
# gpio[43]: J1 pin 68 | schematic 64_L16_P | package AC18 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC18 IOSTANDARD LVCMOS18} [get_ports {gpio[43]}]
# gpio[44]: J1 pin 69 | schematic 64_L22_N | package AC17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC17 IOSTANDARD LVCMOS18} [get_ports {gpio[44]}]
# gpio[45]: J1 pin 70 | schematic 64_L22_P | package AB17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS18} [get_ports {gpio[45]}]
# gpio[46]: J1 pin 71 | schematic 64_L13_N | package AF20 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AF20 IOSTANDARD LVCMOS18} [get_ports {gpio[46]}]
# gpio[47]: J1 pin 72 | schematic 64_L13_P | package AD20 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD20 IOSTANDARD LVCMOS18} [get_ports {gpio[47]}]
# gpio[48]: J1 pin 73 | schematic 64_L14_N | package AD19 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD19 IOSTANDARD LVCMOS18} [get_ports {gpio[48]}]
# gpio[49]: J1 pin 74 | schematic 64_L14_P | package AC19 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AC19 IOSTANDARD LVCMOS18} [get_ports {gpio[49]}]
# gpio[50]: J1 pin 75 | schematic 64_L18_N | package AE16 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AE16 IOSTANDARD LVCMOS18} [get_ports {gpio[50]}]
# gpio[51]: J1 pin 76 | schematic 64_L18_P | package AD16 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AD16 IOSTANDARD LVCMOS18} [get_ports {gpio[51]}]
# gpio[52]: J1 pin 77 | schematic 64_L23_N | package AA17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN AA17 IOSTANDARD LVCMOS18} [get_ports {gpio[52]}]
# gpio[53]: J1 pin 78 | schematic 64_L23_P | package Y17 | bank 64 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS18} [get_ports {gpio[53]}]

# J2: jumper-order GPIO
# gpio[54]: J2 pin 19 | schematic AF15 | package AF15 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AF15 IOSTANDARD LVCMOS33} [get_ports {gpio[54]}]
# gpio[55]: J2 pin 20 | schematic AD15 | package AD15 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AD15 IOSTANDARD LVCMOS33} [get_ports {gpio[55]}]
# gpio[56]: J2 pin 21 | schematic AF13 | package AF13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS33} [get_ports {gpio[56]}]
# gpio[57]: J2 pin 22 | schematic AF14 | package AF14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AF14 IOSTANDARD LVCMOS33} [get_ports {gpio[57]}]
# gpio[58]: J2 pin 23 | schematic AE13 | package AE13 | bank 84 | VCCO 3.3 V | LVCMOS33
# Reserved for uart_tx above; do not also assign gpio[58] to AE13.
# gpio[59]: J2 pin 24 | schematic AE15 | package AE15 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AE15 IOSTANDARD LVCMOS33} [get_ports {gpio[59]}]
# gpio[60]: J2 pin 25 | schematic AD13 | package AD13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AD13 IOSTANDARD LVCMOS33} [get_ports {gpio[60]}]
# gpio[61]: J2 pin 26 | schematic AD14 | package AD14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AD14 IOSTANDARD LVCMOS33} [get_ports {gpio[61]}]
# gpio[62]: J2 pin 27 | schematic AC13 | package AC13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AC13 IOSTANDARD LVCMOS33} [get_ports {gpio[62]}]
# gpio[63]: J2 pin 28 | schematic AC14 | package AC14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AC14 IOSTANDARD LVCMOS33} [get_ports {gpio[63]}]
# gpio[64]: J2 pin 29 | schematic AB14 | package AB14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AB14 IOSTANDARD LVCMOS33} [get_ports {gpio[64]}]
# gpio[65]: J2 pin 30 | schematic AB16 | package AB16 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33} [get_ports {gpio[65]}]
# gpio[66]: J2 pin 31 | schematic AA13 | package AA13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AA13 IOSTANDARD LVCMOS33} [get_ports {gpio[66]}]
# gpio[67]: J2 pin 32 | schematic AA14 | package AA14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33} [get_ports {gpio[67]}]
# gpio[68]: J2 pin 33 | schematic Y16 | package Y16 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {gpio[68]}]
# gpio[69]: J2 pin 34 | schematic Y15 | package Y15 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN Y15 IOSTANDARD LVCMOS33} [get_ports {gpio[69]}]
# gpio[70]: J2 pin 35 | schematic W15 | package W15 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports {gpio[70]}]
# gpio[71]: J2 pin 36 | schematic W14 | package W14 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {gpio[71]}]
# gpio[72]: J2 pin 37 | schematic W13 | package W13 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {gpio[72]}]
# gpio[73]: J2 pin 38 | schematic W12 | package W12 | bank 84 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN W12 IOSTANDARD LVCMOS33} [get_ports {gpio[73]}]
# gpio[74]: J2 pin 39 | schematic K9 | package K9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN K9 IOSTANDARD LVCMOS33} [get_ports {gpio[74]}]
# gpio[75]: J2 pin 40 | schematic K10 | package K10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN K10 IOSTANDARD LVCMOS33} [get_ports {gpio[75]}]
# gpio[76]: J2 pin 41 | schematic J9 | package J9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J9 IOSTANDARD LVCMOS33} [get_ports {gpio[76]}]
# gpio[77]: J2 pin 42 | schematic J10 | package J10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J10 IOSTANDARD LVCMOS33} [get_ports {gpio[77]}]
# gpio[78]: J2 pin 43 | schematic H9 | package H9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN H9 IOSTANDARD LVCMOS33} [get_ports {gpio[78]}]
# gpio[79]: J2 pin 44 | schematic H12 | package H12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN H12 IOSTANDARD LVCMOS33} [get_ports {gpio[79]}]
# gpio[80]: J2 pin 45 | schematic G9 | package G9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN G9 IOSTANDARD LVCMOS33} [get_ports {gpio[80]}]
# gpio[81]: J2 pin 46 | schematic G10 | package G10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVCMOS33} [get_ports {gpio[81]}]
# gpio[82]: J2 pin 47 | schematic J12 | package J12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J12 IOSTANDARD LVCMOS33} [get_ports {gpio[82]}]
# gpio[83]: J2 pin 48 | schematic J13 | package J13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {gpio[83]}]
# gpio[84]: J2 pin 49 | schematic J11 | package J11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J11 IOSTANDARD LVCMOS33} [get_ports {gpio[84]}]
# gpio[85]: J2 pin 50 | schematic H11 | package H11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN H11 IOSTANDARD LVCMOS33} [get_ports {gpio[85]}]
# gpio[86]: J2 pin 51 | schematic H13 | package H13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS33} [get_ports {gpio[86]}]
# gpio[87]: J2 pin 52 | schematic H14 | package H14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {gpio[87]}]
# gpio[88]: J2 pin 53 | schematic J14 | package J14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {gpio[88]}]
# gpio[89]: J2 pin 54 | schematic J15 | package J15 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {gpio[89]}]
# gpio[90]: J2 pin 55 | schematic G11 | package G11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN G11 IOSTANDARD LVCMOS33} [get_ports {gpio[90]}]
# gpio[91]: J2 pin 56 | schematic G12 | package G12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN G12 IOSTANDARD LVCMOS33} [get_ports {gpio[91]}]
# gpio[92]: J2 pin 57 | schematic F12 | package F12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS33} [get_ports {gpio[92]}]
# gpio[93]: J2 pin 58 | schematic F13 | package F13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {gpio[93]}]
# gpio[94]: J2 pin 59 | schematic G14 | package G14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {gpio[94]}]
# gpio[95]: J2 pin 60 | schematic F14 | package F14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports {gpio[95]}]
# gpio[96]: J2 pin 61 | schematic D11 | package D11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN D11 IOSTANDARD LVCMOS33} [get_ports {gpio[96]}]
# gpio[97]: J2 pin 62 | schematic E12 | package E12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS33} [get_ports {gpio[97]}]
# gpio[98]: J2 pin 63 | schematic F10 | package F10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN F10 IOSTANDARD LVCMOS33} [get_ports {gpio[98]}]
# gpio[99]: J2 pin 64 | schematic F9 | package F9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN F9 IOSTANDARD LVCMOS33} [get_ports {gpio[99]}]
# gpio[100]: J2 pin 65 | schematic E11 | package E11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN E11 IOSTANDARD LVCMOS33} [get_ports {gpio[100]}]
# gpio[101]: J2 pin 66 | schematic E10 | package E10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVCMOS33} [get_ports {gpio[101]}]
# gpio[102]: J2 pin 67 | schematic D10 | package D10 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports {gpio[102]}]
# gpio[103]: J2 pin 68 | schematic D9 | package D9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {gpio[103]}]
# gpio[104]: J2 pin 69 | schematic C11 | package C11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {gpio[104]}]
# gpio[105]: J2 pin 70 | schematic C9 | package C9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {gpio[105]}]
# gpio[106]: J2 pin 71 | schematic D14 | package D14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {gpio[106]}]
# gpio[107]: J2 pin 72 | schematic D13 | package D13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports {gpio[107]}]
# gpio[108]: J2 pin 73 | schematic C14 | package C14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports {gpio[108]}]
# gpio[109]: J2 pin 74 | schematic B14 | package B14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports {gpio[109]}]
# gpio[110]: J2 pin 75 | schematic A14 | package A14 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports {gpio[110]}]
# gpio[111]: J2 pin 76 | schematic C13 | package C13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports {gpio[111]}]
# gpio[112]: J2 pin 77 | schematic C12 | package C12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {gpio[112]}]
# gpio[113]: J2 pin 78 | schematic B12 | package B12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN B12 IOSTANDARD LVCMOS33} [get_ports {gpio[113]}]
# gpio[114]: J2 pin 79 | schematic B11 | package B11 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports {gpio[114]}]
# gpio[115]: J2 pin 80 | schematic A13 | package A13 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports {gpio[115]}]
# gpio[116]: J2 pin 81 | schematic A12 | package A12 | bank 87 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN A12 IOSTANDARD LVCMOS33} [get_ports {gpio[116]}]
# gpio[117]: J2 pin 83 | schematic B9 | package B9 | bank 86 | VCCO 3.3 V | LVCMOS33
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {gpio[117]}]

# J2 pins 82, 84, and 86 are reserved for the three active-low LEDs and are
# intentionally omitted from gpio.

# J3: jumper-order GPIO
# gpio[118]: J3 pin 21 | schematic 65_L17_N | package P26 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P26 IOSTANDARD LVCMOS12} [get_ports {gpio[118]}]
# gpio[119]: J3 pin 22 | schematic 65_L17_P | package P25 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P25 IOSTANDARD LVCMOS12} [get_ports {gpio[119]}]
# gpio[120]: J3 pin 23 | schematic 66_L9_N | package K26 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN K26 IOSTANDARD LVCMOS12} [get_ports {gpio[120]}]
# gpio[121]: J3 pin 24 | schematic 66_L9_P | package K25 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN K25 IOSTANDARD LVCMOS12} [get_ports {gpio[121]}]
# gpio[122]: J3 pin 25 | schematic 66_L15_N | package J26 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVCMOS12} [get_ports {gpio[122]}]
# gpio[123]: J3 pin 26 | schematic 66_L15_P | package J25 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN J25 IOSTANDARD LVCMOS12} [get_ports {gpio[123]}]
# gpio[124]: J3 pin 27 | schematic 66_L17_P | package H26 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS12} [get_ports {gpio[124]}]
# gpio[125]: J3 pin 28 | schematic 66_L17_N | package G26 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVCMOS12} [get_ports {gpio[125]}]
# gpio[126]: J3 pin 29 | schematic 67_L23_N | package A25 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A25 IOSTANDARD LVCMOS18} [get_ports {gpio[126]}]
# gpio[127]: J3 pin 30 | schematic 67_L23_P | package A24 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A24 IOSTANDARD LVCMOS18} [get_ports {gpio[127]}]
# gpio[128]: J3 pin 31 | schematic 67_L19_N | package A23 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A23 IOSTANDARD LVCMOS18} [get_ports {gpio[128]}]
# gpio[129]: J3 pin 32 | schematic 67_L19_P | package A22 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A22 IOSTANDARD LVCMOS18} [get_ports {gpio[129]}]
# gpio[130]: J3 pin 33 | schematic 65_L24_N | package N22 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS12} [get_ports {gpio[130]}]
# gpio[131]: J3 pin 34 | schematic 65_L24_P | package N21 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN N21 IOSTANDARD LVCMOS12} [get_ports {gpio[131]}]
# gpio[132]: J3 pin 35 | schematic 67_L24_N | package B22 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS18} [get_ports {gpio[132]}]
# gpio[133]: J3 pin 36 | schematic 67_L24_P | package C22 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS18} [get_ports {gpio[133]}]
# gpio[134]: J3 pin 37 | schematic 67_L22_N | package B21 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS18} [get_ports {gpio[134]}]
# gpio[135]: J3 pin 38 | schematic 67_L22_P | package C21 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C21 IOSTANDARD LVCMOS18} [get_ports {gpio[135]}]
# gpio[136]: J3 pin 39 | schematic 67_L20_N | package D21 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS18} [get_ports {gpio[136]}]
# gpio[137]: J3 pin 40 | schematic 67_L20_P | package E21 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS18} [get_ports {gpio[137]}]
# gpio[138]: J3 pin 41 | schematic 67_L9_N | package G21 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS18} [get_ports {gpio[138]}]
# gpio[139]: J3 pin 42 | schematic 67_L9_P | package G20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS18} [get_ports {gpio[139]}]
# gpio[140]: J3 pin 43 | schematic 66_L5_N | package J21 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS12} [get_ports {gpio[140]}]
# gpio[141]: J3 pin 44 | schematic 66_L5_P | package K21 | bank 66 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS12} [get_ports {gpio[141]}]
# gpio[142]: J3 pin 45 | schematic 67_L10_N | package E20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS18} [get_ports {gpio[142]}]
# gpio[143]: J3 pin 46 | schematic 67_L10_P | package F20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS18} [get_ports {gpio[143]}]
# gpio[144]: J3 pin 47 | schematic 67_L18_N | package A20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS18} [get_ports {gpio[144]}]
# gpio[145]: J3 pin 48 | schematic 67_L18_P | package A19 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS18} [get_ports {gpio[145]}]
# gpio[146]: J3 pin 49 | schematic 67_L14_N | package B20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS18} [get_ports {gpio[146]}]
# gpio[147]: J3 pin 50 | schematic 67_L14_P | package B19 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B19 IOSTANDARD LVCMOS18} [get_ports {gpio[147]}]
# gpio[148]: J3 pin 51 | schematic 67_L13_N | package C19 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVCMOS18} [get_ports {gpio[148]}]
# gpio[149]: J3 pin 52 | schematic 67_L13_P | package C18 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS18} [get_ports {gpio[149]}]
# gpio[150]: J3 pin 53 | schematic 67_L12_N | package D20 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS18} [get_ports {gpio[150]}]
# gpio[151]: J3 pin 54 | schematic 67_L12_P | package D19 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS18} [get_ports {gpio[151]}]
# gpio[152]: J3 pin 55 | schematic 65_L20_N | package P21 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS12} [get_ports {gpio[152]}]
# gpio[153]: J3 pin 56 | schematic 65_L20_P | package P20 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS12} [get_ports {gpio[153]}]
# gpio[154]: J3 pin 57 | schematic 67_L4_N | package E17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS18} [get_ports {gpio[154]}]
# gpio[155]: J3 pin 58 | schematic 67_L4_P | package E16 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS18} [get_ports {gpio[155]}]
# gpio[156]: J3 pin 59 | schematic 67_L16_P | package A17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS18} [get_ports {gpio[156]}]
# gpio[157]: J3 pin 60 | schematic 67_L16_N | package A18 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS18} [get_ports {gpio[157]}]
# gpio[158]: J3 pin 61 | schematic 65_L23_P | package N19 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS12} [get_ports {gpio[158]}]
# gpio[159]: J3 pin 62 | schematic 65_L23_N | package P19 | bank 65 | VCCO 1.2 V | LVCMOS12
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS12} [get_ports {gpio[159]}]
# gpio[160]: J3 pin 65 | schematic 67_L15_P | package C17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS18} [get_ports {gpio[160]}]
# gpio[161]: J3 pin 66 | schematic 67_L15_N | package B17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS18} [get_ports {gpio[161]}]
# gpio[162]: J3 pin 67 | schematic 67_L6_P | package D16 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS18} [get_ports {gpio[162]}]
# gpio[163]: J3 pin 68 | schematic 67_L6_N | package C16 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS18} [get_ports {gpio[163]}]
# gpio[164]: J3 pin 69 | schematic 67_L2_P | package H17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS18} [get_ports {gpio[164]}]
# gpio[165]: J3 pin 70 | schematic 67_L2_N | package G17 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS18} [get_ports {gpio[165]}]
# gpio[166]: J3 pin 71 | schematic 67_L5_P | package H16 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS18} [get_ports {gpio[166]}]
# gpio[167]: J3 pin 72 | schematic 67_L5_N | package G16 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS18} [get_ports {gpio[167]}]
# gpio[168]: J3 pin 73 | schematic 67_L17_P | package B15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS18} [get_ports {gpio[168]}]
# gpio[169]: J3 pin 74 | schematic 67_L17_N | package A15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS18} [get_ports {gpio[169]}]
# gpio[170]: J3 pin 75 | schematic 67_L7_P | package H18 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS18} [get_ports {gpio[170]}]
# gpio[171]: J3 pin 76 | schematic 67_L7_N | package H19 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS18} [get_ports {gpio[171]}]
# gpio[172]: J3 pin 77 | schematic 67_L3_P | package E15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS18} [get_ports {gpio[172]}]
# gpio[173]: J3 pin 78 | schematic 67_L3_N | package D15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS18} [get_ports {gpio[173]}]
# gpio[174]: J3 pin 79 | schematic 67_L1_P | package G15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS18} [get_ports {gpio[174]}]
# gpio[175]: J3 pin 80 | schematic 67_L1_N | package F15 | bank 67 | VCCO 1.8 V | LVCMOS18
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS18} [get_ports {gpio[175]}]

# J3 pin 63 is ADC_VN and J3 pin 64 is ADC_VP. The supplied images do not
# show their FPGA package balls, so no PACKAGE_PIN values are invented here.


# ============================================================================
# DDR4 (banks 65 and 66, VCCO 1.2 V)
# ============================================================================
# ddr4_dq[0]: DDR4 data/mask | package U22 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN U22 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[0]}]
# ddr4_dq[1]: DDR4 data/mask | package W20 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN W20 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[1]}]
# ddr4_dq[2]: DDR4 data/mask | package U20 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN U20 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[2]}]
# ddr4_dq[3]: DDR4 data/mask | package W19 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN W19 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[3]}]
# ddr4_dq[4]: DDR4 data/mask | package U21 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN U21 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[4]}]
# ddr4_dq[5]: DDR4 data/mask | package T22 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN T22 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[5]}]
# ddr4_dq[6]: DDR4 data/mask | package T23 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN T23 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[6]}]
# ddr4_dq[7]: DDR4 data/mask | package T20 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN T20 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[7]}]
# ddr4_dq[8]: DDR4 data/mask | package AA24 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN AA24 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[8]}]
# ddr4_dq[9]: DDR4 data/mask | package Y25 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN Y25 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[9]}]
# ddr4_dq[10]: DDR4 data/mask | package V24 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN V24 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[10]}]
# ddr4_dq[11]: DDR4 data/mask | package Y26 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN Y26 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[11]}]
# ddr4_dq[12]: DDR4 data/mask | package AA25 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN AA25 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[12]}]
# ddr4_dq[13]: DDR4 data/mask | package W24 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN W24 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[13]}]
# ddr4_dq[14]: DDR4 data/mask | package W23 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN W23 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[14]}]
# ddr4_dq[15]: DDR4 data/mask | package V23 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN V23 IOSTANDARD POD12_DCI} [get_ports {ddr4_dq[15]}]
# ddr4_dm[0]: DDR4 data/mask | package U19 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN U19 IOSTANDARD POD12_DCI} [get_ports {ddr4_dm[0]}]
# ddr4_dm[1]: DDR4 data/mask | package Y22 | bank 65 | VCCO 1.2 V | POD12_DCI
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD POD12_DCI} [get_ports {ddr4_dm[1]}]
# ddr4_dqs_p[0]: DDR4 data strobe | package V21 | bank 65 | VCCO 1.2 V | DIFF_POD12_DCI
set_property -dict {PACKAGE_PIN V21 IOSTANDARD DIFF_POD12_DCI} [get_ports {ddr4_dqs_p[0]}]
# ddr4_dqs_n[0]: DDR4 data strobe | package V22 | bank 65 | VCCO 1.2 V | DIFF_POD12_DCI
set_property -dict {PACKAGE_PIN V22 IOSTANDARD DIFF_POD12_DCI} [get_ports {ddr4_dqs_n[0]}]
# ddr4_dqs_p[1]: DDR4 data strobe | package W25 | bank 65 | VCCO 1.2 V | DIFF_POD12_DCI
set_property -dict {PACKAGE_PIN W25 IOSTANDARD DIFF_POD12_DCI} [get_ports {ddr4_dqs_p[1]}]
# ddr4_dqs_n[1]: DDR4 data strobe | package W26 | bank 65 | VCCO 1.2 V | DIFF_POD12_DCI
set_property -dict {PACKAGE_PIN W26 IOSTANDARD DIFF_POD12_DCI} [get_ports {ddr4_dqs_n[1]}]
# ddr4_addr[0]: DDR4 address/control | package F22 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN F22 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[0]}]
# ddr4_addr[1]: DDR4 address/control | package K20 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN K20 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[1]}]
# ddr4_addr[2]: DDR4 address/control | package C26 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN C26 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[2]}]
# ddr4_addr[3]: DDR4 address/control | package K18 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN K18 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[3]}]
# ddr4_addr[4]: DDR4 address/control | package K22 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN K22 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[4]}]
# ddr4_addr[5]: DDR4 address/control | package L19 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN L19 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[5]}]
# ddr4_addr[6]: DDR4 address/control | package D23 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN D23 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[6]}]
# ddr4_addr[7]: DDR4 address/control | package J20 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN J20 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[7]}]
# ddr4_addr[8]: DDR4 address/control | package C24 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN C24 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[8]}]
# ddr4_addr[9]: DDR4 address/control | package J19 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN J19 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[9]}]
# ddr4_addr[10]: DDR4 address/control | package L22 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN L22 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[10]}]
# ddr4_addr[11]: DDR4 address/control | package B26 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN B26 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[11]}]
# ddr4_addr[12]: DDR4 address/control | package M20 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN M20 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[12]}]
# ddr4_addr[13]: DDR4 address/control | package D24 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN D24 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_addr[13]}]
# ddr4_ba[0]: DDR4 address/control | package E23 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN E23 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_ba[0]}]
# ddr4_ba[1]: DDR4 address/control | package H22 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN H22 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_ba[1]}]
# ddr4_bg[0]: DDR4 address/control | package E25 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN E25 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_bg[0]}]
# ddr4_act_n: DDR4 address/control | package M21 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN M21 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_act_n}]
# ddr4_ras_n: DDR4 address/control | package L20 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN L20 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_ras_n}]
# ddr4_cas_n: DDR4 address/control | package L18 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN L18 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_cas_n}]
# ddr4_we_n: DDR4 address/control | package F23 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN F23 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_we_n}]
# ddr4_cke[0]: DDR4 address/control | package K23 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN K23 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_cke[0]}]
# ddr4_cs_n[0]: DDR4 address/control | package G22 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN G22 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_cs_n[0]}]
# ddr4_odt[0]: DDR4 address/control | package M24 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN M24 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_odt[0]}]
# ddr4_reset_n: DDR4 address/control | package D26 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN D26 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_reset_n}]
# ddr4_alert_n: DDR4 address/control | package D25 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN D25 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_alert_n}]
# ddr4_parity: DDR4 address/control | package B25 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN B25 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_parity}]
# ddr4_ten: DDR4 address/control | package H21 | bank 66 | VCCO 1.2 V | SSTL12_DCI
set_property -dict {PACKAGE_PIN H21 IOSTANDARD SSTL12_DCI} [get_ports {ddr4_ten}]
# ddr4_ck_p[0]: DDR4 clock | package G24 | bank 66 | VCCO 1.2 V | DIFF_SSTL12_DCI
set_property -dict {PACKAGE_PIN G24 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_p[0]}]
# ddr4_ck_n[0]: DDR4 clock | package G25 | bank 66 | VCCO 1.2 V | DIFF_SSTL12_DCI
set_property -dict {PACKAGE_PIN G25 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_n[0]}]

# ============================================================================
# GTH transceivers (dedicated pins; no fabric IOSTANDARD)
# ============================================================================
# Bank 224; dedicated MGT supplies are named in the image but their voltages are not stated.
# mgt224_rx_p/n[0]: bank 224 channel 0 RX | package AF2/AF1 | dedicated GTH
set_property PACKAGE_PIN AF2 [get_ports {mgt224_rx_p[0]}]
set_property PACKAGE_PIN AF1 [get_ports {mgt224_rx_n[0]}]
# mgt224_tx_p/n[0]: bank 224 channel 0 TX | package AF7/AF6 | dedicated GTH
set_property PACKAGE_PIN AF7 [get_ports {mgt224_tx_p[0]}]
set_property PACKAGE_PIN AF6 [get_ports {mgt224_tx_n[0]}]
# mgt224_rx_p/n[1]: bank 224 channel 1 RX | package AE4/AE3 | dedicated GTH
set_property PACKAGE_PIN AE4 [get_ports {mgt224_rx_p[1]}]
set_property PACKAGE_PIN AE3 [get_ports {mgt224_rx_n[1]}]
# mgt224_tx_p/n[1]: bank 224 channel 1 TX | package AE9/AE8 | dedicated GTH
set_property PACKAGE_PIN AE9 [get_ports {mgt224_tx_p[1]}]
set_property PACKAGE_PIN AE8 [get_ports {mgt224_tx_n[1]}]
# mgt224_rx_p/n[2]: bank 224 channel 2 RX | package AD2/AD1 | dedicated GTH
set_property PACKAGE_PIN AD2 [get_ports {mgt224_rx_p[2]}]
set_property PACKAGE_PIN AD1 [get_ports {mgt224_rx_n[2]}]
# mgt224_tx_p/n[2]: bank 224 channel 2 TX | package AD7/AD6 | dedicated GTH
set_property PACKAGE_PIN AD7 [get_ports {mgt224_tx_p[2]}]
set_property PACKAGE_PIN AD6 [get_ports {mgt224_tx_n[2]}]
# mgt224_rx_p/n[3]: bank 224 channel 3 RX | package AB2/AB1 | dedicated GTH
set_property PACKAGE_PIN AB2 [get_ports {mgt224_rx_p[3]}]
set_property PACKAGE_PIN AB1 [get_ports {mgt224_rx_n[3]}]
# mgt224_tx_p/n[3]: bank 224 channel 3 TX | package AC5/AC4 | dedicated GTH
set_property PACKAGE_PIN AC5 [get_ports {mgt224_tx_p[3]}]
set_property PACKAGE_PIN AC4 [get_ports {mgt224_tx_n[3]}]
# mgt224_refclk_p/n[0]: bank 224 reference clock 0 | package AB7/AB6 | dedicated GTH
set_property PACKAGE_PIN AB7 [get_ports {mgt224_refclk_p[0]}]
set_property PACKAGE_PIN AB6 [get_ports {mgt224_refclk_n[0]}]
# mgt224_refclk_p/n[1]: bank 224 reference clock 1 | package Y7/Y6 | dedicated GTH
set_property PACKAGE_PIN Y7 [get_ports {mgt224_refclk_p[1]}]
set_property PACKAGE_PIN Y6 [get_ports {mgt224_refclk_n[1]}]

# Bank 225; dedicated MGT supplies are named in the image but their voltages are not stated.
# mgt225_rx_p/n[0]: bank 225 channel 0 RX | package Y2/Y1 | dedicated GTH
set_property PACKAGE_PIN Y2 [get_ports {mgt225_rx_p[0]}]
set_property PACKAGE_PIN Y1 [get_ports {mgt225_rx_n[0]}]
# mgt225_tx_p/n[0]: bank 225 channel 0 TX | package AA5/AA4 | dedicated GTH
set_property PACKAGE_PIN AA5 [get_ports {mgt225_tx_p[0]}]
set_property PACKAGE_PIN AA4 [get_ports {mgt225_tx_n[0]}]
# mgt225_rx_p/n[1]: bank 225 channel 1 RX | package V2/V1 | dedicated GTH
set_property PACKAGE_PIN V2 [get_ports {mgt225_rx_p[1]}]
set_property PACKAGE_PIN V1 [get_ports {mgt225_rx_n[1]}]
# mgt225_tx_p/n[1]: bank 225 channel 1 TX | package W5/W4 | dedicated GTH
set_property PACKAGE_PIN W5 [get_ports {mgt225_tx_p[1]}]
set_property PACKAGE_PIN W4 [get_ports {mgt225_tx_n[1]}]
# mgt225_rx_p/n[2]: bank 225 channel 2 RX | package T2/T1 | dedicated GTH
set_property PACKAGE_PIN T2 [get_ports {mgt225_rx_p[2]}]
set_property PACKAGE_PIN T1 [get_ports {mgt225_rx_n[2]}]
# mgt225_tx_p/n[2]: bank 225 channel 2 TX | package U5/U4 | dedicated GTH
set_property PACKAGE_PIN U5 [get_ports {mgt225_tx_p[2]}]
set_property PACKAGE_PIN U4 [get_ports {mgt225_tx_n[2]}]
# mgt225_rx_p/n[3]: bank 225 channel 3 RX | package P2/P1 | dedicated GTH
set_property PACKAGE_PIN P2 [get_ports {mgt225_rx_p[3]}]
set_property PACKAGE_PIN P1 [get_ports {mgt225_rx_n[3]}]
# mgt225_tx_p/n[3]: bank 225 channel 3 TX | package R5/R4 | dedicated GTH
set_property PACKAGE_PIN R5 [get_ports {mgt225_tx_p[3]}]
set_property PACKAGE_PIN R4 [get_ports {mgt225_tx_n[3]}]
# mgt225_refclk_p/n[0]: bank 225 reference clock 0 | package V7/V6 | dedicated GTH
set_property PACKAGE_PIN V7 [get_ports {mgt225_refclk_p[0]}]
set_property PACKAGE_PIN V6 [get_ports {mgt225_refclk_n[0]}]
# mgt225_refclk_p/n[1]: bank 225 reference clock 1 | package T7/T6 | dedicated GTH
set_property PACKAGE_PIN T7 [get_ports {mgt225_refclk_p[1]}]
set_property PACKAGE_PIN T6 [get_ports {mgt225_refclk_n[1]}]

# Bank 226; dedicated MGT supplies are named in the image but their voltages are not stated.
# mgt226_rx_p/n[0]: bank 226 channel 0 RX | package M2/M1 | dedicated GTH
set_property PACKAGE_PIN M2 [get_ports {mgt226_rx_p[0]}]
set_property PACKAGE_PIN M1 [get_ports {mgt226_rx_n[0]}]
# mgt226_tx_p/n[0]: bank 226 channel 0 TX | package N5/N4 | dedicated GTH
set_property PACKAGE_PIN N5 [get_ports {mgt226_tx_p[0]}]
set_property PACKAGE_PIN N4 [get_ports {mgt226_tx_n[0]}]
# mgt226_rx_p/n[1]: bank 226 channel 1 RX | package K2/K1 | dedicated GTH
set_property PACKAGE_PIN K2 [get_ports {mgt226_rx_p[1]}]
set_property PACKAGE_PIN K1 [get_ports {mgt226_rx_n[1]}]
# mgt226_tx_p/n[1]: bank 226 channel 1 TX | package L5/L4 | dedicated GTH
set_property PACKAGE_PIN L5 [get_ports {mgt226_tx_p[1]}]
set_property PACKAGE_PIN L4 [get_ports {mgt226_tx_n[1]}]
# mgt226_rx_p/n[2]: bank 226 channel 2 RX | package H2/H1 | dedicated GTH
set_property PACKAGE_PIN H2 [get_ports {mgt226_rx_p[2]}]
set_property PACKAGE_PIN H1 [get_ports {mgt226_rx_n[2]}]
# mgt226_tx_p/n[2]: bank 226 channel 2 TX | package J5/J4 | dedicated GTH
set_property PACKAGE_PIN J5 [get_ports {mgt226_tx_p[2]}]
set_property PACKAGE_PIN J4 [get_ports {mgt226_tx_n[2]}]
# mgt226_rx_p/n[3]: bank 226 channel 3 RX | package F2/F1 | dedicated GTH
set_property PACKAGE_PIN F2 [get_ports {mgt226_rx_p[3]}]
set_property PACKAGE_PIN F1 [get_ports {mgt226_rx_n[3]}]
# mgt226_tx_p/n[3]: bank 226 channel 3 TX | package G5/G4 | dedicated GTH
set_property PACKAGE_PIN G5 [get_ports {mgt226_tx_p[3]}]
set_property PACKAGE_PIN G4 [get_ports {mgt226_tx_n[3]}]
# mgt226_refclk_p/n[0]: bank 226 reference clock 0 | package P7/P6 | dedicated GTH
set_property PACKAGE_PIN P7 [get_ports {mgt226_refclk_p[0]}]
set_property PACKAGE_PIN P6 [get_ports {mgt226_refclk_n[0]}]
# mgt226_refclk_p/n[1]: bank 226 reference clock 1 | package M7/M6 | dedicated GTH
set_property PACKAGE_PIN M7 [get_ports {mgt226_refclk_p[1]}]
set_property PACKAGE_PIN M6 [get_ports {mgt226_refclk_n[1]}]

# Bank 227; dedicated MGT supplies are named in the image but their voltages are not stated.
# mgt227_rx_p/n[0]: bank 227 channel 0 RX | package D2/D1 | dedicated GTH
set_property PACKAGE_PIN D2 [get_ports {mgt227_rx_p[0]}]
set_property PACKAGE_PIN D1 [get_ports {mgt227_rx_n[0]}]
# mgt227_tx_p/n[0]: bank 227 channel 0 TX | package F7/F6 | dedicated GTH
set_property PACKAGE_PIN F7 [get_ports {mgt227_tx_p[0]}]
set_property PACKAGE_PIN F6 [get_ports {mgt227_tx_n[0]}]
# mgt227_rx_p/n[1]: bank 227 channel 1 RX | package C4/C3 | dedicated GTH
set_property PACKAGE_PIN C4 [get_ports {mgt227_rx_p[1]}]
set_property PACKAGE_PIN C3 [get_ports {mgt227_rx_n[1]}]
# mgt227_tx_p/n[1]: bank 227 channel 1 TX | package E5/E4 | dedicated GTH
set_property PACKAGE_PIN E5 [get_ports {mgt227_tx_p[1]}]
set_property PACKAGE_PIN E4 [get_ports {mgt227_tx_n[1]}]
# mgt227_rx_p/n[2]: bank 227 channel 2 RX | package B2/B1 | dedicated GTH
set_property PACKAGE_PIN B2 [get_ports {mgt227_rx_p[2]}]
set_property PACKAGE_PIN B1 [get_ports {mgt227_rx_n[2]}]
# mgt227_tx_p/n[2]: bank 227 channel 2 TX | package D7/D6 | dedicated GTH
set_property PACKAGE_PIN D7 [get_ports {mgt227_tx_p[2]}]
set_property PACKAGE_PIN D6 [get_ports {mgt227_tx_n[2]}]
# mgt227_rx_p/n[3]: bank 227 channel 3 RX | package A4/A3 | dedicated GTH
set_property PACKAGE_PIN A4 [get_ports {mgt227_rx_p[3]}]
set_property PACKAGE_PIN A3 [get_ports {mgt227_rx_n[3]}]
# mgt227_tx_p/n[3]: bank 227 channel 3 TX | package B7/B6 | dedicated GTH
set_property PACKAGE_PIN B7 [get_ports {mgt227_tx_p[3]}]
set_property PACKAGE_PIN B6 [get_ports {mgt227_tx_n[3]}]
# mgt227_refclk_p/n[0]: bank 227 reference clock 0 | package K7/K6 | dedicated GTH
set_property PACKAGE_PIN K7 [get_ports {mgt227_refclk_p[0]}]
set_property PACKAGE_PIN K6 [get_ports {mgt227_refclk_n[0]}]
# mgt227_refclk_p/n[1]: bank 227 reference clock 1 | package H7/H6 | dedicated GTH
set_property PACKAGE_PIN H7 [get_ports {mgt227_refclk_p[1]}]
set_property PACKAGE_PIN H6 [get_ports {mgt227_refclk_n[1]}]
