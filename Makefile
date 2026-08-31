ENV_FILE ?= .env
ifneq ($(wildcard $(ENV_FILE)),)
include $(ENV_FILE)
export
endif

TARGET ?= tangnano9k

ifeq ($(TARGET),tangnano9k)
BOARD := tangnano9k
FAMILY := GW1N-9C
DEVICE := GW1NR-LV9QN88PC6/I5
CST := constr/tangnano9k.cst
else ifeq ($(TARGET),tangnano20k)
BOARD := tangnano20k
FAMILY := GW2A-18C
DEVICE := GW2AR-LV18QN88C8/I7
CST := constr/tangnano20k.cst
else
$(error Unsupported TARGET '$(TARGET)'. Use tangnano20k or tangnano9k)
endif

TOP := top
BUILD := build
SRC := src/top.v src/uart_rx.v src/uart_tx.v src/bitcoin_hash_core.v src/sha256_compress.v
SPINAL_SRC := $(BUILD)/spinal/top.v
SPINAL_PREFIX := $(BUILD)/tangminer_spinal_$(TARGET)
VERILOG_PREFIX := $(BUILD)/tangminer_verilog_$(TARGET)
OSS_CAD_SUITE ?= /d/git/FPGA/oss-cad-suite
TOOLBIN := $(OSS_CAD_SUITE)/bin
YOSYS := $(TOOLBIN)/yosys
NEXTPNR := $(TOOLBIN)/nextpnr-himbaechel
GOWIN_PACK := $(TOOLBIN)/gowin_pack
OPENFPGALOADER := $(TOOLBIN)/openFPGALoader
IVERILOG := $(TOOLBIN)/iverilog
VVP := $(TOOLBIN)/vvp
SBT ?= sbt
NEXTPNR_OPTS := --tmg-ripup
USERPROFILE_UNIX := $(subst \,/,$(USERPROFILE))
PIO_HOME := $(if $(HOME),$(HOME),$(USERPROFILE_UNIX))
PIO ?= $(if $(wildcard $(PIO_HOME)/.platformio/penv/Scripts/platformio.exe),$(PIO_HOME)/.platformio/penv/Scripts/platformio.exe,platformio)
MCU_DIR := mcu
MCU_ENV := esp32c3_oled
MCU_CONFIG := $(MCU_DIR)/mine_config.h
MCU_PORT ?= COM14
WIFI_SSID ?=
WIFI_PASS ?=
POOL_HOST ?= public-pool.io
POOL_PORT ?= 13333
MINER_USER ?= bc1qjwgtd0sa3znxftx5s7mzwaz8ct34yvesr2nqa6.tangnano9k
MINER_PASS ?=
MCU_UPLOAD_PORT := $(if $(MCU_PORT),--upload-port $(MCU_PORT),)
MCU_MONITOR_PORT := $(if $(MCU_PORT),--port $(MCU_PORT),)

.PHONY: all build build-verilog spinal-verilog build-spinal load load-verilog load-spinal flash flash-verilog flash-spinal clean sim sim-sha sim-bitcoin sim-dual gowin flash-gowin mcu-build mcu-flash mcu-monitor mcu-clean mcu-test FORCE

all: build

build: build-spinal

build-verilog: $(VERILOG_PREFIX).fs

build-spinal: $(SPINAL_PREFIX).fs

spinal-verilog: $(SPINAL_SRC)

$(BUILD)/.dir:
	mkdir -p $(BUILD)
	touch $@

$(SPINAL_SRC): src/main/scala/tangminer/TangMiner.scala build.sbt project/build.properties | $(BUILD)/.dir
	$(SBT) "runMain tangminer.GenerateVerilog"

$(VERILOG_PREFIX).json: $(SRC) | $(BUILD)/.dir
	$(YOSYS) -p "read_verilog $(SRC); synth_gowin -top $(TOP) -json $@"

$(VERILOG_PREFIX)_pnr.json: $(VERILOG_PREFIX).json $(CST)
	$(NEXTPNR) $(NEXTPNR_OPTS) --json $< --write $@ --freq 27 --device $(DEVICE) -o family=$(FAMILY) -o cst=$(CST)

$(VERILOG_PREFIX).fs: $(VERILOG_PREFIX)_pnr.json
	$(GOWIN_PACK) -d $(FAMILY) -o $@ $<

$(SPINAL_PREFIX).json: $(SPINAL_SRC) | $(BUILD)/.dir
	$(YOSYS) -p "read_verilog $(SPINAL_SRC); synth_gowin -top $(TOP) -json $@"

$(SPINAL_PREFIX)_pnr.json: $(SPINAL_PREFIX).json $(CST)
	$(NEXTPNR) $(NEXTPNR_OPTS) --json $< --write $@ --freq 27 --device $(DEVICE) -o family=$(FAMILY) -o cst=$(CST)

$(SPINAL_PREFIX).fs: $(SPINAL_PREFIX)_pnr.json
	$(GOWIN_PACK) -d $(FAMILY) -o $@ $<

load: load-spinal

load-verilog: $(VERILOG_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) $<

load-spinal: $(SPINAL_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) $<

flash: flash-gowin

flash-verilog: $(VERILOG_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) -f $<

flash-spinal: $(SPINAL_PREFIX).fs
	$(OPENFPGALOADER) -b $(BOARD) -f $<

flash-gowin:
	$(OPENFPGALOADER) -b $(BOARD) -f impl/pnr/top.fs

sim: sim-sha sim-bitcoin sim-dual

sim-sha: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_sha256_compress sim/tb_sha256_compress.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_sha256_compress

sim-bitcoin: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_bitcoin_hash_core sim/tb_bitcoin_hash_core.v src/bitcoin_hash_core.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_bitcoin_hash_core

sim-dual: | $(BUILD)/.dir
	$(IVERILOG) -g2012 -o $(BUILD)/tb_dual_bitcoin_hash_core sim/tb_dual_bitcoin_hash_core.v src/bitcoin_hash_core.v src/sha256_compress.v
	$(VVP) $(BUILD)/tb_dual_bitcoin_hash_core

gowin:
	/c/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe build_gowin.tcl

vivado:
	/c/AMDDesignTools/2026.1/Vivado/bin/vivado.bat -mode batch -source build_kintex7.tcl -log ./build_vivado/vivado_build.log -journal ./build_vivado/vivado.jou

mine:
	python scripts/mine.py

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
