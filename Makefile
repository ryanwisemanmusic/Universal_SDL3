.PHONY: all clean build run purge shell intellisense test-stage run-log

PROJECT_ROOT := $(shell pwd)
IMAGE_NAME := lilyspark-alpha
CONTAINER_NAME := sdl3-app

# Only mount main.cpp for local development - this is what users will replace
CXX_FILES := main.cpp

# These are handled in the Docker image, no need to mount them
SOURCE_FILES := $(CXX_FILES)
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
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		sh -c "mkdir -p build && cd build && \
		cmake .. && make -j\$$(nproc) && cd .. && \
		lilyspark-alpha-filtered"

run-log: intellisense
	@mkdir -p log
	@docker run --rm --name $(CONTAINER_NAME) \
		$(VOLUME_MOUNTS) \
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		sh -c "mkdir -p build && cd build && \
		cmake .. && make -j\$$(nproc) && cd .. && \
		lilyspark-alpha-filtered"

shell:
	@docker run -it --rm \
		$(VOLUME_MOUNTS) \
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME) \
		/bin/bash