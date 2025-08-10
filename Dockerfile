# Stage: base deps (Alpine version)
FROM alpine:3.18 AS base-deps

# Install essential build tools
RUN apk add --no-cache \
    bash \
    ca-certificates \
    git \
    build-base \
    cmake \
    ninja \
    pkgconf \
    python3 \
    py3-pip \
    linux-headers \
    musl-dev

# Install glibc compatibility layer (ARM64-safe versions to prevent ldconfig machine mismatch)
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-dev-2.35-r1.apk && \
    apk add --no-cache \
        glibc-2.35-r1.apk \
        glibc-bin-2.35-r1.apk \
        glibc-dev-2.35-r1.apk && \
    rm -f /sbin/ldconfig && \
    rm *.apk

# Stage: build core libraries
FROM base-deps AS libs-build
WORKDIR /build

# Install build dependencies with debugging tools
RUN apk add --no-cache \
    m4 \
    bison \
    flex \
    zlib-dev \
    expat-dev \
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxrender-dev \
    libxfixes-dev \
    libxcursor-dev \
    libxi-dev \
    libxinerama-dev \
    libxdamage-dev \
    libxshmfence-dev \
    libxcb-dev \
    libxxf86vm-dev \
    wayland-dev \
    wayland-protocols \
    libdrm-dev \
    llvm16-dev llvm16-libs \
    clang16 \
    python3-dev \
    py3-setuptools \
    jpeg-dev \
    libpng-dev \
    libxkbcommon-dev \
    strace \
    file \
    tree

# Install Python dependencies for Mesa and glmark2
RUN pip install --no-cache-dir meson==1.4.0 mako==1.3.3

# Set verbose build environment
ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

# Build and install Mesa with verbose debugging
RUN git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git && \
    cd mesa && \
    git checkout mesa-24.0.3 && \
    echo "=== MESA BUILD CONFIGURATION ===" && \
    meson setup builddir/ \
        -Dprefix=/usr/local \
        -Dglx=dri \
        -Ddri3=enabled \
        -Degl=enabled \
        -Dgbm=enabled \
        -Dplatforms=x11,wayland \
        -Dglvnd=false \
        -Dosmesa=true \
        -Dgallium-drivers=swrast \
        -Dvulkan-drivers= \
        -Dbuildtype=debugoptimized \
        --fatal-meson-warnings \
        --wrap-mode=nodownload \
        -Dc_args="-v -Wno-error" \
        -Dcpp_args="-v -Wno-error" && \
    echo "=== MESA BUILD LOGS ===" && \
    cat builddir/meson-logs/meson-log.txt && \
    echo "=== MESA CONFIGURATION ===" && \
    meson configure builddir/ && \
    echo "=== STARTING NINJA BUILD ===" && \
    ninja -C builddir -v install && \
    echo "=== BUILD COMPLETED ===" && \
    cd .. && \
    rm -rf mesa

# Create DRI directory structure
RUN mkdir -p /usr/lib/xorg/modules/dri && \
    ln -s /usr/lib/dri /usr/lib/xorg/modules/dri

# Build and install SDL3
RUN git clone --depth=1 https://github.com/libsdl-org/SDL.git sdl && \
    cd sdl && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DSDL_STATIC=ON \
        -DSDL_SHARED=OFF \
        -DSDL_VIDEO=ON \
        -DSDL_X11=ON \
        -DSDL_WAYLAND=ON \
        -DSDL_OPENGL=ON \
        -DSDL_OPENGLES=ON \
        -DSDL_RENDER=ON \
        -DSDL_AUDIO=ON \
        -DSDL_VIDEO_OPENGL=ON \
        -DSDL_VIDEO_OPENGL_ES2=ON \
        -DSDL_VIDEO_OPENGL_EGL=ON && \
    make -j"$(nproc)" install

# Build and install glmark2
RUN echo "===== START GLMARK2 BUILD =====" && \
    git clone --depth=1 https://github.com/glmark2/glmark2.git && \
    cd glmark2 && \
    echo "===== DIRECTORY STRUCTURE (PRE-BUILD) =====" && \
    tree -L 2 && \
    echo "===== WAF SCRIPT PERMISSIONS =====" && \
    ls -l waf* || true && \
    echo "===== CONFIGURING GLMARK2 =====" && \
    python3 ./waf configure --prefix=/usr/local --with-flavors=x11-gl,drm-gl --verbose 2>&1 | tee configure.log || { \
        echo "===== CONFIGURATION FAILED - SHOWING LOG ====="; \
        cat configure.log; \
        exit 1; \
    } && \
    echo "===== BUILDING GLMARK2 =====" && \
    python3 ./waf build -j"$(nproc)" --verbose 2>&1 | tee build.log || { \
        echo "===== BUILD FAILED - SHOWING LOG ====="; \
        cat build.log; \
        exit 1; \
    } && \
    echo "===== INSTALLING GLMARK2 =====" && \
    python3 ./waf install --verbose 2>&1 | tee install.log && \
    echo "===== GLMARK2 BUILD COMPLETED ====="

# Stage: build application
FROM libs-build AS app-build
WORKDIR /app
COPY . .
WORKDIR /app/build
RUN cmake -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
         ../src && \
    cmake --build . --parallel "$(nproc)"

# Stage: debug environment
FROM base-deps AS debug
COPY --from=libs-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver

# Install debug tools + LLVM runtime
RUN apk add --no-cache \
    mesa-demos \
    xdpyinfo \
    xrandr \
    xeyes \
    strace \
    gdb \
    valgrind \
    libxxf86vm \
    llvm16-libs

# Create DRI directory structure
RUN mkdir -p /usr/lib/xorg/modules/dri && \
    ln -s /usr/lib/dri /usr/lib/xorg/modules/dri

# Create non-root user
RUN addgroup -g 1000 shs && \
    adduser -u 1000 -G shs -D shs && \
    chown -R shs:shs /app /usr/local

# Environment setup
ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    LD_LIBRARY_PATH=/usr/lib:/usr/glibc-compat/lib:/usr/local/lib

USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]

# Stage: runtime environment
FROM alpine:3.18 AS runtime
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    libx11 \
    libxext \
    libxrandr \
    libxrender \
    libxfixes \
    libxcursor \
    libxi \
    libxinerama \
    libxdamage \
    libxshmfence \
    libxcb \
    libxxf86vm \
    wayland \
    alsa-lib \
    pulseaudio \
    mesa-dri-gallium \
    mesa-va-gallium \
    mesa-vdpau-gallium \
    glu \
    llvm16-libs  # <-- ensure LLVM16 present in runtime

RUN set -eux; \
    if apk add --no-cache libgbm 2>/dev/null; then \
        echo "Installed libgbm"; \
    else \
        apk add --no-cache mesa-gbm || true; \
    fi

RUN mkdir -p /usr/lib/xorg/modules/dri && \
    ln -s /usr/lib/dri /usr/lib/xorg/modules/dri

COPY --from=libs-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver

RUN addgroup -g 1000 shs && \
    adduser -u 1000 -G shs -D shs && \
    chown -R shs:shs /app /usr/local

ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    LD_LIBRARY_PATH=/usr/lib:/usr/glibc-compat/lib:/usr/local/lib

USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]
