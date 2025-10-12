.PHONY: all clean build run purge

PROJECT_ROOT := $(shell pwd)
IMAGE_NAME := mostsignificant/simplehttpserver
CONTAINER_NAME := sdl3-app

all: build-docker run-docker

clean:
	@-docker container rm -f $(CONTAINER_NAME) 2>/dev/null || true
	@-docker image rm -f $(IMAGE_NAME) 2>/dev/null || true

# NEW: Complete system purge
purge: clean
	@-docker system prune -f --filter="label=$(IMAGE_NAME)" 2>/dev/null || true
	@-docker container prune -f 2>/dev/null || true
	@-docker image prune -f 2>/dev/null || true
	@-docker builder prune -f 2>/dev/null || true

build:
	@echo "=== BUILDING DOCKER IMAGE ==="
	@docker build --platform=linux/arm64 -t $(IMAGE_NAME) .

run:
	@echo "=== RUNNING DOCKER CONTAINER ==="
	@docker run --rm --name $(CONTAINER_NAME) \
		-e DISPLAY=host.docker.internal:0 \
		--platform=linux/arm64 \
		$(IMAGE_NAME)