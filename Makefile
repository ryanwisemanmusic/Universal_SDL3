.PHONY: all update-libraries build run run-headless clean xhost-allow check-xquartz

# Default target
all: check-xquartz xhost-allow build run

# Verify XQuartz is running and DISPLAY is set
check-xquartz:
	@if [ "$$(uname)" = "Darwin" ]; then \
		if ! ps aux | grep -q '[X]quartz'; then \
			echo "ERROR: XQuartz not running. Run 'open -a XQuartz'"; \
			exit 1; \
		fi; \
		if [ -z "$$DISPLAY" ]; then \
			export DISPLAY=:0; \
			echo "NOTE: Setting DISPLAY=:0"; \
		fi; \
	fi

# Safe xhost-allow with DISPLAY verification
xhost-allow: check-xquartz
	@if [ "$$(uname)" = "Darwin" ]; then \
		DISPLAY=:0 /opt/X11/bin/xhost + 127.0.0.1; \
		DISPLAY=:0 /opt/X11/bin/xhost + local:docker; \
	else \
		xhost +; \
	fi

update-libraries:
	@mkdir -p build
	@cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=1 .. 
	@cp build/compile_commands.json .vscode/

build:
	@docker build . -t mostsignificant/simplehttpserver

run: xhost-allow
	@if [ "$$(uname)" = "Darwin" ]; then \
		DISPLAY_HOST=host.docker.internal; \
	else \
		DISPLAY_HOST=$$(hostname -I | awk '{print $$1}'); \
	fi; \
	docker run --rm \
		-e DISPLAY=$$DISPLAY_HOST:0 \
		-e SDL_VIDEODRIVER=x11 \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		mostsignificant/simplehttpserver

run-headless:
	@docker run --rm \
		-e SDL_VIDEODRIVER=dummy \
		mostsignificant/simplehttpserver

clean:
	@rm -rf build
	@docker rmi mostsignificant/simplehttpserver 2>/dev/null || true
