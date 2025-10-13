.PHONY: all clean build run purge shell intellisense test-stage

PROJECT_ROOT := $(shell pwd)
IMAGE_NAME := mostsignificant/simplehttpserver
CONTAINER_NAME := sdl3-app

CXX_FILES := main.cpp screenScenes.h
C_FILES := 
CMAKE_FILES := CMakeLists.txt
SHELL_FILES := fb-wrapper.sh

SOURCE_FILES := $(CXX_FILES) $(C_FILES) $(CMAKE_FILES) $(SHELL_FILES)
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
	@echo "=== UPDATING INTELLISENSE CONFIG ==="
	@chmod +x .vscode/generate_cpp_config.sh
	@.vscode/generate_cpp_config.sh

run: intellisense
	@docker run --rm --name $(CONTAINER_NAME) \
		$(VOLUME_MOUNTS) \
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		sh -c "chmod +x fb-wrapper.sh && mkdir -p build && cd build && cmake .. && make -j\$$(nproc) && cd .. && ./fb-wrapper.sh"

shell:
	@docker run -it --rm \
		$(VOLUME_MOUNTS) \
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		/bin/bash