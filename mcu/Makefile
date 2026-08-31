-include .env

PORT     ?= COM14
VENV     ?= .venv
PYTHON   ?= python
PIO      ?= $(VENV)/Scripts/pio
MSYS2_UCRT_GCC := /c/msys64/ucrt64/bin/gcc.exe
HOST_GCC ?= $(if $(wildcard $(MSYS2_UCRT_GCC)),$(MSYS2_UCRT_GCC),gcc)
HOST_PATH := PATH=/c/msys64/ucrt64/bin:$$PATH
.PHONY: all init build flash clean monitor test

all: build

init:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/Scripts/python.exe -m pip install --upgrade pip platformio
	$(PIO) pkg install

build:
	$(PIO) run

flash:
	$(PIO) run --target upload --upload-port $(PORT)

clean:
	$(PIO) run --target clean
	rm -rf .pio

monitor:
	$(PIO) device monitor --port $(PORT) --baud 115200

test:
	$(HOST_PATH) $(HOST_GCC) -pipe -std=c11 -Wall -Wextra -I. -Isrc test_miner_core.c src/miner_core.c -o test_miner_core.exe
	./test_miner_core.exe
