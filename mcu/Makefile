-include .env

PORT     ?= COM14
VENV     ?= .venv
PYTHON   ?= python
PIO      ?= $(VENV)/Scripts/pio
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
	cc -pipe -std=c11 -Wall -Wextra -I. -Isrc test_miner_core.c src/miner_core.c -o test_miner_core.exe
	./test_miner_core.exe
