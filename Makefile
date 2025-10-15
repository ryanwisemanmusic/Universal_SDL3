.PHONY: all clean build run purge shell intellisense test-stage run-log setup-venv activate-venv quit-venv python-deps

PROJECT_ROOT := $(shell pwd)
IMAGE_NAME := lilyspark-alpha
CONTAINER_NAME := sdl3-app
VENV_DIR := venv
PYTHON := $(VENV_DIR)/bin/python3
PIP := $(VENV_DIR)/bin/pip

CXX_FILES := main.cpp
PYTHON_FILES := wifidetect.py

SOURCE_FILES := $(CXX_FILES) $(PYTHON_FILES)
VOLUME_MOUNTS := $(foreach file,$(SOURCE_FILES),-v "$(PROJECT_ROOT)/$(file):/app/$(file)")

all: clean build run

clean:
	@-docker container rm -f $(CONTAINER_NAME) 2>/dev/null || true
	@-docker image rm -f $(IMAGE_NAME) 2>/dev/null || true
	@-rm -rf log 2>/dev/null || true

purge: clean
	@-docker system prune -f --filter="label=$(IMAGE_NAME)" 2>/dev/null || true
	@-docker container prune -f 2>/dev/null || true
	@-docker image prune -f 2>/dev/null || true
	@-docker builder prune -f 2>/dev/null || true

build:
	@docker build --platform=linux/arm64 -t $(IMAGE_NAME) .

test-stage: purge
	@mkdir -p log
	@docker build --platform=linux/arm64 --target test -t $(IMAGE_NAME)-test . > log/test.log 2>&1

intellisense:
	@chmod +x .vscode/generate_cpp_config.sh
	@.vscode/generate_cpp_config.sh

run: intellisense
	@docker run --rm --name $(CONTAINER_NAME) \
		$(VOLUME_MOUNTS) \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		sh -c "mkdir -p build && cd build && \
		cmake .. && make -j\$$(nproc) && cd .. && \
		lilyspark-alpha-filtered"

run-log: intellisense
	@mkdir -p log
	@docker run --rm --name $(CONTAINER_NAME) \
		$(VOLUME_MOUNTS) \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		sh -c "mkdir -p build && cd build && \
		cmake .. && make -j\$$(nproc) && cd .. && \
		lilyspark-alpha-filtered"

shell:
	@docker run -it --rm \
		$(VOLUME_MOUNTS) \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		/bin/bash

# Python Virtual Environment Management
setup-venv:
	@python3 -m venv $(VENV_DIR)

python-deps: setup-venv
	@$(PIP) install --upgrade pip
	@$(PIP) install pandas numpy

activate-venv:
	@echo "To activate the virtual environment, run:"
	@echo "source $(VENV_DIR)/bin/activate"

quit-venv:
	@echo "To deactivate the virtual environment, run:"
	@echo "deactivate"

# Test Python setup
test-python: python-deps
	@$(PYTHON) -c "import pandas as pd; import numpy as np; print('✓ All Python imports successful!')"
	@$(PYTHON) -c "import pandas as pd; print('✓ Pandas version:', pd.__version__)"

# Run Python code
run-python: python-deps activate-venv quit-venv
	@echo "Running Python code"
	@$(PYTHON) $(PYTHON_FILES)
	
	
