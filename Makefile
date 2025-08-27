.PHONY: all update-libraries build run run-software run-headless clean check-native help

UNAME_S := $(shell uname -s)
HAS_BREW := $(shell command -v brew >/dev/null 2>&1 && echo yes || echo no)
HAS_CMAKE := $(shell command -v cmake >/dev/null 2>&1 && echo yes || echo no)

PROJECT_ROOT := $(shell pwd)
SDL3_INSTALL_DIR := $(PROJECT_ROOT)/build/deps/install

all: detect-build-method

detect-build-method:
	@echo "=== Build Method Detection ==="
	@echo "OS: $(UNAME_S)"
	@echo "Homebrew available: $(HAS_BREW)"
	@echo "CMake available: $(HAS_CMAKE)"
	@echo "Project root: $(PROJECT_ROOT)"
	@echo "SDL3 install dir: $(SDL3_INSTALL_DIR)"
	@if [ "$(UNAME_S)" = "Darwin" ] && [ "$(HAS_BREW)" = "yes" ] && [ "$(HAS_CMAKE)" = "yes" ]; then \
		echo "✓ Native macOS build available - using Cocoa!"; \
		$(MAKE) build-native && $(MAKE) run-native; \
	else \
		echo "→ Using Docker build method"; \
		$(MAKE) build-docker && $(MAKE) run-docker; \
	fi

install-deps-native:
	@echo "Installing native macOS dependencies..."
	@if [ "$(HAS_BREW)" = "no" ]; then \
		echo "Error: Homebrew not found. Install from https://brew.sh/"; \
		exit 1; \
	fi
	@brew install boost cmake pkg-config

build-sdl3-mac:
	@echo "Building SDL3 from source for macOS..."
	@echo "SDL3 will be installed to: $(SDL3_INSTALL_DIR)"
	@mkdir -p build/deps
	@if [ ! -d "build/deps/SDL3" ]; then \
		git clone --depth=1 https://github.com/libsdl-org/SDL.git build/deps/SDL3; \
	fi
	@rm -rf build/deps/SDL3/build
	@rm -rf "$(SDL3_INSTALL_DIR)"
	@mkdir -p build/deps/SDL3/build
	@mkdir -p "$(SDL3_INSTALL_DIR)"
	@cd build/deps/SDL3/build && \
		cmake .. \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_INSTALL_PREFIX="$(SDL3_INSTALL_DIR)" \
			-DCMAKE_INSTALL_NAME_DIR="$(SDL3_INSTALL_DIR)/lib" \
			-DPKG_CONFIG_LIBDIR="$(SDL3_INSTALL_DIR)/lib/pkgconfig" \
			-DSDL_SHARED=ON \
			-DSDL_STATIC=ON \
			-DSDL_VIDEO=ON \
			-DSDL_COCOA=ON \
			-DSDL_X11=OFF \
			-DSDL_WAYLAND=OFF \
			-DSDL_OPENGL=ON \
			-DSDL_OPENGLES=ON \
			-DSDL_RENDER=ON \
			-DSDL_AUDIO=ON \
			-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
	@cd build/deps/SDL3/build && make -j"$(shell sysctl -n hw.ncpu)"
	@cd build/deps/SDL3/build && make install
	@ls -la "$(SDL3_INSTALL_DIR)/lib/" 2>/dev/null || echo "Warning: No SDL3 libraries found after installation"
	@ls -la "$(SDL3_INSTALL_DIR)/include/" 2>/dev/null || echo "Warning: No SDL3 headers found after installation"

build-native: build-sdl3-mac
	@echo "Building application natively for macOS with Cocoa and local SDL3..."
	@echo "Using SDL3 from: $(SDL3_INSTALL_DIR)"
	@mkdir -p build/native
	@cd build/native && \
		cmake ../../src \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
			-DCMAKE_PREFIX_PATH="$(SDL3_INSTALL_DIR)" \
			-DSDL3_INSTALL_DIR="$(SDL3_INSTALL_DIR)" \
			-DCMAKE_OSX_ARCHITECTURES="$$(uname -m)" \
			-DSDL_COCOA=ON \
			-DSDL_X11=OFF \
			-DSDL_WAYLAND=OFF
	@cd build/native && cmake --build . --parallel "$$(sysctl -n hw.ncpu)"
	@mkdir -p .vscode
	@cp build/native/compile_commands.json .vscode/ 2>/dev/null || true

run-native:
	@echo "Running native macOS application with Cocoa backend..."
	@if [ ! -f "build/native/simplehttpserver" ]; then \
		echo "Native build not found. Run 'make build-native' first."; \
		exit 1; \
	fi
	@ls -la "$(SDL3_INSTALL_DIR)/lib/libSDL3"* 2>/dev/null || echo "Warning: SDL3 libraries not found"
	@cd build/native && \
		DYLD_LIBRARY_PATH="$(SDL3_INSTALL_DIR)/lib:$$DYLD_LIBRARY_PATH" \
		DYLD_FALLBACK_LIBRARY_PATH="$(SDL3_INSTALL_DIR)/lib:$$DYLD_FALLBACK_LIBRARY_PATH" \
		SDL_VIDEODRIVER=cocoa \
		./simplehttpserver

build-docker: build-base build-debug build-app

build-base:
	@echo "Building base Alpine image..."
	@docker build --platform=linux/arm64 --target base-deps -t sdl3-base:latest .

build-debug:
	@echo "Building debug image..."
	@docker build --platform=linux/arm64 --target debug -t sdl3-debug:latest .

build-app:
	@echo "Building main application image..."
	@docker build --platform=linux/arm64 --target runtime -t mostsignificant/simplehttpserver .

run-docker: check-xquartz-settings
	@echo "Running with Docker and X11 forwarding..."
	@docker run --rm --name sdl3-opengl-app \
		-e DISPLAY=host.docker.internal:0 \
		-e SDL_VIDEODRIVER=x11 \
		--platform=linux/arm64 \
		--shm-size=512m \
		mostsignificant/simplehttpserver

run-docker-log:
	@echo "Running with Docker and logging output to run_docker.txt"
	@$(MAKE) run-docker > run_docker.txt 2>&1

run:
	@if [ "$(UNAME_S)" = "Darwin" ] && [ "$(HAS_BREW)" = "yes" ] && [ "$(HAS_CMAKE)" = "yes" ] && [ -f "build/native/simplehttpserver" ]; then \
		echo "Using native macOS build..."; \
		$(MAKE) run-native; \
	else \
		echo "Using Docker build..."; \
		$(MAKE) run-docker; \
	fi

test-native:
	@echo "=== Testing Native Build Capabilities ==="
	@echo "Operating System: $(UNAME_S)"
	@echo "Architecture: $(shell uname -m)"
	@echo "Homebrew: $(HAS_BREW)"
	@echo "CMake: $(HAS_CMAKE)"
	@echo "Project Root: $(PROJECT_ROOT)"
	@echo "SDL3 Install Dir: $(SDL3_INSTALL_DIR)"
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "Xcode Command Line Tools: $$(xcode-select -p >/dev/null 2>&1 && echo 'Yes' || echo 'No')"; \
		echo "macOS Version: $$(sw_vers -productVersion)"; \
		if command -v brew >/dev/null 2>&1; then \
			echo "Boost available: $$(brew list | grep -q boost && echo 'Yes' || echo 'No')"; \
			echo "SDL3 available: $$( [ -f '$(SDL3_INSTALL_DIR)/lib/libSDL3.dylib' ] && echo 'Yes' || echo 'No')"; \
		fi; \
		echo "Testing pkg-config for SDL3:"; \
		PKG_CONFIG_PATH="$(SDL3_INSTALL_DIR)/lib/pkgconfig" pkg-config --exists sdl3 && echo "  pkg-config: SDL3 found" || echo "  pkg-config: SDL3 NOT found"; \
		PKG_CONFIG_PATH="$(SDL3_INSTALL_DIR)/lib/pkgconfig" pkg-config --libs sdl3 2>/dev/null || echo "  pkg-config: Could not get libs"; \
		PKG_CONFIG_PATH="$(SDL3_INSTALL_DIR)/lib/pkgconfig" pkg-config --cflags sdl3 2>/dev/null || echo "  pkg-config: Could not get cflags"; \
	else \
		echo "Not running on macOS - Docker build required"; \
	fi

clean-native:
	@echo "Cleaning native build artifacts..."
	@rm -rf build/native build/deps
	@echo "Native build cleaned."

clean-docker:
	@echo "Cleaning up Docker resources..."
	@docker container rm -f sdl3-opengl-app sdl3-opengl-app-headless 2>/dev/null || true
	@docker image rm -f mostsignificant/simplehttpserver sdl3-base:latest sdl3-debug:latest 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "Docker cleanup completed."

clean-docker-log:
	@echo "Cleaning with Docker and logging output to clean_docker.txt"
	@$(MAKE) clean-docker > clean_docker.txt 2>&1

clean: clean-native clean-docker

update-libraries:
	@echo "Updating CMake configuration..."
	@if [ -d "build/native" ]; then \
		echo "Updating native build with SDL3 paths..."; \
		cd build/native && cmake ../../src \
			-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
			-DSDL3_INSTALL_DIR="$(SDL3_INSTALL_DIR)" \
			-DCMAKE_PREFIX_PATH="$(SDL3_INSTALL_DIR)"; \
		mkdir -p ../../.vscode; \
		cp compile_commands.json ../../.vscode/ 2>/dev/null || true; \
	fi
	@if command -v docker >/dev/null 2>&1; then \
		echo "Updating Docker build..."; \
		mkdir -p build/docker; \
		cd build/docker && cmake ../../src -DCMAKE_EXPORT_COMPILE_COMMANDS=1; \
	fi

check-xquartz-settings:
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "Checking XQuartz configuration..."; \
		if ! pgrep -f "XQuartz" >/dev/null; then \
			echo "WARNING: XQuartz is not running (needed for Docker builds)"; \
		else \
			echo "XQuartz is running."; \
		fi; \
	fi

debug:
	@echo "=== Build Environment Debug ==="
	@echo "Operating System: $(UNAME_S)"
	@echo "Architecture: $$(uname -m)"
	@echo "Homebrew: $(HAS_BREW)"
	@echo "CMake: $(HAS_CMAKE)"
	@echo "Project Root: $(PROJECT_ROOT)"
	@echo "SDL3 Install Dir: $(SDL3_INSTALL_DIR)"
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "macOS Version: $$(sw_vers -productVersion)"; \
		echo "Xcode CLI Tools: $$(xcode-select -p >/dev/null 2>&1 && echo 'Yes' || echo 'No')"; \
		echo "Native build available: $$( [ -f 'build/native/simplehttpserver' ] && echo 'Yes' || echo 'No')"; \
		echo "XQuartz running: $$(pgrep -f XQuartz >/dev/null && echo 'Yes' || echo 'No')"; \
	fi
	@echo "Docker available: $$(command -v docker >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
	@echo "Docker images: $$(docker images | grep -E '(sdl3|simplehttpserver)' | wc -l) built"

run-headless:
	@if [ -f "build/native/simplehttpserver" ]; then \
		echo "Running native headless mode..."; \
		cd build/native && SDL_VIDEODRIVER=dummy ./simplehttpserver; \
	else \
		echo "Running Docker headless mode..."; \
		docker run --rm --name sdl3-opengl-app-headless \
			-e SDL_VIDEODRIVER=dummy \
			-e LIBGL_ALWAYS_SOFTWARE=1 \
			--platform=linux/arm64 \
			--shm-size=512m \
			mostsignificant/simplehttpserver; \
	fi

help:
	@echo "=== Hybrid Build System ==="
	@echo "Available targets: all, build-native, run-native, build-docker, run-docker, test-native, run-headless, clean, debug"

build-native-log:
	@echo "Building natively and logging output to build_native.txt..."
	@$(MAKE) build-native > build_native.txt 2>&1

build-docker-log:
	@echo "Building with Docker and logging output to build_docker.txt"
	@$(MAKE) build-docker > build_docker.txt 2>&1

# Stage-specific Docker builds
.PHONY: build-base-deps-docker build-filesystem-base-deps-builder-docker \
        build-filesystem-libs-build-builder-docker build-app-build-docker \
        build-debug-docker build-runtime-docker

build-base-deps-docker:
	@echo "Building Docker stage: base-deps..."
	@docker build --platform=linux/arm64 --target base-deps -t sdl3-base:latest .

build-filesystem-base-deps-builder-docker:
	@echo "Building Docker stage: filesystem-base-deps-builder..."
	@docker build --platform=linux/arm64 --target filesystem-base-deps-builder -t sdl3-filesystem-base:latest .

build-filesystem-libs-build-builder-docker:
	@echo "Building Docker stage: filesystem-libs-build-builder..."
	@docker build --platform=linux/arm64 --target filesystem-libs-build-builder -t sdl3-filesystem-libs:latest .

build-app-build-docker:
	@echo "Building Docker stage: app-build..."
	@docker build --platform=linux/arm64 --target app-build -t sdl3-app-build:latest .

build-debug-docker:
	@echo "Building Docker stage: debug..."
	@docker build --platform=linux/arm64 --target debug -t sdl3-debug:latest .

build-runtime-docker:
	@echo "Building Docker stage: runtime..."
	@docker build --platform=linux/arm64 --target runtime -t mostsignificant/simplehttpserver .

# Stage-specific Docker cleanup
.PHONY: clean-base-deps-docker clean-filesystem-base-deps-builder-docker \
        clean-filesystem-libs-build-builder-docker clean-app-build-docker \
        clean-debug-docker clean-runtime-docker

clean-base-deps-docker:
	@echo "Cleaning Docker image: base-deps..."
	@docker image rm -f sdl3-base:latest 2>/dev/null || true

clean-filesystem-base-deps-builder-docker:
	@echo "Cleaning Docker image: filesystem-base-deps-builder..."
	@docker image rm -f sdl3-filesystem-base:latest 2>/dev/null || true

clean-filesystem-libs-build-builder-docker:
	@echo "Cleaning Docker image: filesystem-libs-build:latest..."
	@docker image rm -f sdl3-filesystem-libs:latest 2>/dev/null || true

clean-app-build-docker:
	@echo "Cleaning Docker image: app-build..."
	@docker image rm -f sdl3-app-build:latest 2>/dev/null || true

clean-debug-docker:
	@echo "Cleaning Docker image: debug..."
	@docker image rm -f sdl3-debug:latest 2>/dev/null || true

clean-runtime-docker:
	@echo "Cleaning Docker image: runtime..."
	@docker image rm -f mostsignificant/simplehttpserver 2>/dev/null || true

# Stage-specific Docker build logs
.PHONY: build-base-deps-docker-log build-filesystem-base-deps-builder-docker-log \
        build-filesystem-libs-build-builder-docker-log build-app-build-docker-log \
        build-debug-docker-log build-runtime-docker-log

build-base-deps-docker-log:
	@echo "Building Docker stage: base-deps (log)..."
	@mkdir -p log
	@$(MAKE) build-base-deps-docker > logs/build/build_base_deps_docker.txt 2>&1

build-filesystem-base-deps-builder-docker-log:
	@echo "Building Docker stage: filesystem-base-deps-builder (log)..."
	@mkdir -p log
	@$(MAKE) build-filesystem-base-deps-builder-docker > logs/build/build_filesystem_base_deps_builder_docker.txt 2>&1

build-filesystem-libs-build-builder-docker-log:
	@echo "Building Docker stage: filesystem-libs-build-builder (log)..."
	@mkdir -p log
	@$(MAKE) build-filesystem-libs-build-builder-docker > logs/build/build_filesystem_libs_build_builder_docker.txt 2>&1

build-app-build-docker-log:
	@echo "Building Docker stage: app-build (log)..."
	@mkdir -p log
	@$(MAKE) build-app-build-docker > logs/build/build_app_build_docker.txt 2>&1

build-debug-docker-log:
	@echo "Building Docker stage: debug (log)..."
	@mkdir -p log
	@$(MAKE) build-debug-docker > logs/build/build_debug_docker.txt 2>&1

build-runtime-docker-log:
	@echo "Building Docker stage: runtime (log)..."
	@mkdir -p log
	@$(MAKE) build-runtime-docker > logs/build/build_runtime_docker.txt 2>&1

# Stage-specific Docker clean logs
.PHONY: clean-base-deps-docker-log clean-filesystem-base-deps-builder-docker-log \
        clean-filesystem-libs-build-builder-docker-log clean-app-build-docker-log \
        clean-debug-docker-log clean-runtime-docker-log

clean-base-deps-docker-log:
	@echo "Cleaning Docker stage: base-deps (log)..."
	@mkdir -p log
	@$(MAKE) clean-base-deps-docker > logs/clean/clean_base_deps_docker.txt 2>&1

clean-filesystem-base-deps-builder-docker-log:
	@echo "Cleaning Docker stage: filesystem-base-deps-builder (log)..."
	@mkdir -p log
	@$(MAKE) clean-filesystem-base-deps-builder-docker > logs/clean/clean_filesystem_base_deps_builder_docker.txt 2>&1

clean-filesystem-libs-build-builder-docker-log:
	@echo "Cleaning Docker stage: filesystem-libs-build-builder (log)..."
	@mkdir -p log
	@$(MAKE) clean-filesystem-libs-build-builder-docker > logs/clean/clean_filesystem_libs_build_builder_docker.txt 2>&1

clean-app-build-docker-log:
	@echo "Cleaning Docker stage: app-build (log)..."
	@mkdir -p log
	@$(MAKE) clean-app-build-docker > logs/clean/clean_app_build_docker.txt 2>&1

clean-debug-docker-log:
	@echo "Cleaning Docker stage: debug (log)..."
	@mkdir -p log
	@$(MAKE) clean-debug-docker > logs/clean/clean_debug_docker.txt 2>&1

clean-runtime-docker-log:
	@echo "Cleaning Docker stage: runtime (log)..."
	@mkdir -p log
	@$(MAKE) clean-runtime-docker > logs/clean/clean_runtime_docker.txt 2>&1

LOGFILE := logs/build/cmake_output.txt

dump-cmake-output:
	@mkdir -p build/cmake
	@echo "===== CMake Output Dump =====" >> $(LOGFILE)
	@cmake -S . -B build/cmake >> $(LOGFILE) 2>&1
	@echo "===== End CMake Output =====" >> $(LOGFILE)