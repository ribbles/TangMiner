SHELL := /bin/bash

ENV_FILE ?= .env
ifneq ($(wildcard $(ENV_FILE)),)
include $(ENV_FILE)
export
endif

TARGET ?= xc7k325tffg676

ifeq ($(TARGET),tangnano9k)
BOARD := tangnano9k
FAMILY := GW1N-9C
DEVICE := GW1NR-LV9QN88PC6/I5
CST := constr/tangnano9k.cst
OPENFPGA_ARGS := -b $(BOARD)
else ifeq ($(TARGET),tangnano20k)
BOARD := tangnano20k
FAMILY := GW2A-18C
DEVICE := GW2AR-LV18QN88C8/I7
CST := constr/tangnano20k.cst
OPENFPGA_ARGS := -b $(BOARD)
else ifeq ($(TARGET),xc7k325tffg676)
BOARD := xc7k325tffg676
FAMILY := GW2A-18C
DEVICE := xc7k325tffg676
OPENFPGA_ARGS := --cable dirtyJtag --fpga-part $(DEVICE) 
else
$(error Unsupported TARGET '$(TARGET)'. Use tangnano20k or tangnano9k)
endif

TOP := top
BUILD := build
SRC := src/top.v src/uart_rx.v src/uart_tx.v src/bitcoin_hash_core.v src/sha256_compress.v src/lt256.v
SPINAL_SRC := $(BUILD)/spinal/top.v
SPINAL_PREFIX := $(BUILD)/tangminer_spinal_$(TARGET)
VERILOG_PREFIX := $(BUILD)/tangminer_verilog_$(TARGET)
OSS_CAD_SUITE ?= /c/fpga/oss-cad-suite
TOOLBIN := $(OSS_CAD_SUITE)/bin
TOOLLIB := $(OSS_CAD_SUITE)/lib
export PATH := $(TOOLBIN):$(TOOLLIB):$(PATH)
YOSYS := $(TOOLBIN)/yosys
NEXTPNR := $(TOOLBIN)/nextpnr-himbaechel
GOWIN_PACK := $(TOOLBIN)/gowin_pack
OPENFPGALOADER := OPENFPGALOADER_SOJ_DIR=/c/fpga/oss-cad-suite/share/openFPGALoader $(TOOLBIN)/openFPGALoader3
IVERILOG := $(TOOLBIN)/iverilog
VVP := $(TOOLBIN)/vvp
VIVADO := /c/AMDDesignTools/2026.1/Vivado/bin/vivado.bat
SBT ?= sbt
NEXTPNR_OPTS := --tmg-ripup
USERPROFILE_UNIX := $(subst \,/,$(USERPROFILE))
PIO_HOME := $(if $(HOME),$(HOME),$(USERPROFILE_UNIX))
PIO ?= $(if $(wildcard $(PIO_HOME)/.platformio/penv/Scripts/platformio.exe),$(PIO_HOME)/.platformio/penv/Scripts/platformio.exe,platformio)
MCU_DIR := mcu
MCU_ENV := esp32c3_oled
MCU_CONFIG := $(MCU_DIR)/mine_config.h
MCU_PORT ?= COM6
PING_PORT ?= $(MCU_PORT)
WIFI_SSID ?=
WIFI_PASS ?=
POOL_HOST ?= public-pool.io
POOL_PORT ?= 13333
MINER_USER ?= bc1qjwgtd0sa3znxftx5s7mzwaz8ct34yvesr2nqa6.tangnano9k
MINER_PASS ?=
MCU_UPLOAD_PORT := $(if $(MCU_PORT),--upload-port $(MCU_PORT),)
MCU_MONITOR_PORT := $(if $(MCU_PORT),--port $(MCU_PORT),)

.PHONY: build load flash clean sim sim-lt256 sim-sha sim-bitcoin sim-dual sim-uart gowin flash-gowin temp ping mcu-build mcu-flash mcu-monitor mcu-clean mcu-test FORCE


build: vivado

$(BUILD)/.dir:
	mkdir -p $(BUILD)
	touch $@


load: 
	$(OPENFPGALOADER) $(OPENFPGA_ARGS) build_vivado/pack.bit

flash:
	$(OPENFPGALOADER) $(OPENFPGA_ARGS) -r -f build_vivado/pack.bit

flash-gowin:
	$(OPENFPGALOADER)  $(OPENFPGA_ARGS) -f impl/pnr/top.fs

temp:
	OPENFPGALOADER='$(OPENFPGALOADER)' scripts/xadc_temperature.sh $(OPENFPGA_ARGS)

sim: sim-lt256 sim-sha sim-bitcoin sim-dual sim-uart

sim-lt256: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_lt256 sim/tb_lt256.v src/lt256.v
	$(VVP) $(BUILD)/tb_lt256

sim-sha: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_sha256_compress sim/tb_sha256_compress.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_sha256_compress

sim-bitcoin: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_bitcoin_hash_core sim/tb_bitcoin_hash_core.v src/bitcoin_hash_core.v src/sha256_compress.v src/lt256.v
	$(VVP) $(BUILD)/tb_bitcoin_hash_core

sim-dual: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_dual_bitcoin_hash_core sim/tb_dual_bitcoin_hash_core.v src/bitcoin_hash_core.v src/sha256_compress.v src/lt256.v
	$(VVP) $(BUILD)/tb_dual_bitcoin_hash_core

sim-uart: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_uart_top sim/tb_uart_top.v src/top.v src/uart_rx.v src/uart_tx.v src/bitcoin_hash_core.v src/sha256_compress.v src/lt256.v
	$(VVP) $(BUILD)/tb_uart_top

gowin:
	/c/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe build_gowin.tcl

vivado:
	rm -rf build_vivado/*
	$(VIVADO) -mode batch -source build_kintex7.tcl -log ./build_vivado/vivado_build.log -journal ./build_vivado/vivado.jou
	python3.14.exe scripts/render_floorplan.py

mine:
	python3.14 scripts/mine.py

ping:
	python3.14 scripts/ping.py $(PING_PORT)

mcu-init:
	make -C mcu init

mcu-build:
	make -C mcu build

mcu-flash:
	make -C mcu flash

mcu-clean:
	make -C mcu clean

mcu-test:
	make -C mcu test

profile:
	yosys -s profile.ys
	echo "Generating profile_report.txt from profile data..."
	python scripts/parse_profile.py > profile_report.txt

clean:
	rm -rf $(BUILD)
	rm -rf impl
	rm -rf .Xil
