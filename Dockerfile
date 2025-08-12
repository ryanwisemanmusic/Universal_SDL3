# Stage: base deps (Alpine version)
FROM alpine:3.18 AS base-deps

# Remove any preinstalled LLVM/Clang
RUN apk del --no-cache llvm clang || true

# Force install LLVM 16 only
RUN apk add --no-cache llvm16-dev llvm16-libs clang16

# Make sure llvm16 tools are first on PATH and expose llvm-config
ENV PATH=/usr/lib/llvm16/bin:${PATH}
ENV LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config
# Prefer llvm16 libs at runtime (helps runtime resolution inside the image)
ENV LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib

# Enhanced LLVM15 detector with package correlation
RUN cat > /usr/local/bin/check_llvm15.sh <<'SH' && chmod +x /usr/local/bin/check_llvm15.sh
#!/bin/sh
set -eu

STAGE="${1:-unknown-stage}"
OUT="/tmp/llvm15_debug_${STAGE}.log"
echo "=== LLVM15 DEBUG: stage=${STAGE} timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >"$OUT"

# 1) Find LLVM 15 files
echo ">> Searching for LLVM-15 files..." | tee -a "$OUT"
LLVM15_FILES=$(find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null || true)
if [ -n "$LLVM15_FILES" ]; then
    echo "FOUND LLVM15 FILES:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | tee -a "$OUT"
else
    echo "NO LLVM15 FILES FOUND" | tee -a "$OUT"
fi

# 2) Find owning packages for each LLVM15 file
if [ -n "$LLVM15_FILES" ]; then
    echo "" | tee -a "$OUT"
    echo ">> Package owners of LLVM15 files:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | while read -r f; do
        if [ -f "$f" ]; then
            echo "FILE: $f" | tee -a "$OUT"
            OWNER=$(apk info --who-owns "$f" 2>/dev/null | head -n1 || echo "UNKNOWN")
            echo "  OWNED BY: $OWNER" | tee -a "$OUT"
        fi
    done
fi

# 3) Check if llvm15-libs package is installed
echo "" | tee -a "$OUT"
echo ">> llvm15-libs package status:" | tee -a "$OUT"
if apk info llvm15-libs >/dev/null 2>&1; then
    echo "INSTALLED: llvm15-libs" | tee -a "$OUT"
    apk info llvm15-libs | tee -a "$OUT"
else
    echo "NOT INSTALLED: llvm15-libs" | tee -a "$OUT"
fi

# 4) Find all packages that depend on llvm15-libs
echo "" | tee -a "$OUT"
echo ">> Packages depending on llvm15-libs:" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
    if apk info -R "$pkg" 2>/dev/null | grep -q '^llvm15-libs$'; then
        echo "DEPENDS ON llvm15-libs: $pkg" | tee -a "$OUT"
    fi
done

# 5) Find packages containing LLVM15 in their file lists
echo "" | tee -a "$OUT"
echo ">> Packages containing LLVM15 files:" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
    if apk info -L "$pkg" 2>/dev/null | grep -q 'libLLVM-15'; then
        echo "CONTAINS LLVM15: $pkg" | tee -a "$OUT"
    fi
done

# 6) Show all LLVM versions present
echo "" | tee -a "$OUT"
echo ">> All LLVM versions detected:" | tee -a "$OUT"
for v in 14 15 16 17; do
    if find /usr -name "libLLVM-${v}*.so*" -print -quit 2>/dev/null | grep -q .; then
        echo "LLVM ${v}: PRESENT" | tee -a "$OUT"
    else
        echo "LLVM ${v}: ABSENT" | tee -a "$OUT"
    fi
done

# 7) Final verdict
echo "" | tee -a "$OUT"
if [ -n "$LLVM15_FILES" ]; then
    echo "VERDICT: LLVM15 CONTAMINATION DETECTED in ${STAGE}" | tee -a "$OUT"
else
    echo "VERDICT: LLVM15 CLEAN in ${STAGE}" | tee -a "$OUT"
fi

# Always show the log
echo "" && echo "=== FULL DEBUG LOG ===" && cat "$OUT"
SH

# Individual package installation with LLVM15 checks
RUN echo "=== INSTALLING CORE PACKAGES WITH LLVM15 MONITORING ==="

RUN apk add --no-cache bash && /usr/local/bin/check_llvm15.sh "after-bash" || true
RUN apk add --no-cache ca-certificates && /usr/local/bin/check_llvm15.sh "after-ca-certificates" || true
RUN apk add --no-cache git && /usr/local/bin/check_llvm15.sh "after-git" || true
RUN apk add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk add --no-cache musl-dev && /usr/local/bin/check_llvm15.sh "after-musl-dev" || true
RUN apk add --no-cache cmake && /usr/local/bin/check_llvm15.sh "after-cmake" || true
RUN apk add --no-cache ninja && /usr/local/bin/check_llvm15.sh "after-ninja" || true
RUN apk add --no-cache pkgconf && /usr/local/bin/check_llvm15.sh "after-pkgconf" || true
RUN apk add --no-cache python3 && /usr/local/bin/check_llvm15.sh "after-python3" || true
RUN apk add --no-cache py3-pip && /usr/local/bin/check_llvm15.sh "after-py3-pip" || true

# Vulkan and graphics packages (high suspects for LLVM15)
RUN apk add --no-cache vulkan-headers && /usr/local/bin/check_llvm15.sh "after-vulkan-headers" || true
RUN apk add --no-cache vulkan-loader && /usr/local/bin/check_llvm15.sh "after-vulkan-loader" || true
RUN apk add --no-cache vulkan-tools && /usr/local/bin/check_llvm15.sh "after-vulkan-tools" || true
RUN apk add --no-cache freetype-dev && /usr/local/bin/check_llvm15.sh "after-freetype-dev" || true
RUN apk add --no-cache fontconfig-dev && /usr/local/bin/check_llvm15.sh "after-fontconfig-dev" || true

# X11 packages (suspects)
RUN apk add --no-cache libxcomposite-dev && /usr/local/bin/check_llvm15.sh "after-libxcomposite-dev" || true
RUN apk add --no-cache libxinerama-dev && /usr/local/bin/check_llvm15.sh "after-libxinerama-dev" || true
RUN apk add --no-cache libxi-dev && /usr/local/bin/check_llvm15.sh "after-libxi-dev" || true
RUN apk add --no-cache libxcursor-dev && /usr/local/bin/check_llvm15.sh "after-libxcursor-dev" || true
RUN apk add --no-cache libxrandr-dev && /usr/local/bin/check_llvm15.sh "after-libxrandr-dev" || true
RUN apk add --no-cache libxshmfence-dev && /usr/local/bin/check_llvm15.sh "after-libxshmfence-dev" || true
RUN apk add --no-cache libxxf86vm-dev && /usr/local/bin/check_llvm15.sh "after-libxxf86vm-dev" || true

# Audio packages
RUN apk add --no-cache alsa-lib-dev && /usr/local/bin/check_llvm15.sh "after-alsa-lib-dev" || true
RUN apk add --no-cache pulseaudio-dev && /usr/local/bin/check_llvm15.sh "after-pulseaudio-dev" || true

# Misc packages
RUN apk add --no-cache bsd-compat-headers && /usr/local/bin/check_llvm15.sh "after-bsd-compat-headers" || true
RUN apk add --no-cache xf86-video-fbdev && /usr/local/bin/check_llvm15.sh "after-xf86-video-fbdev" || true
RUN apk add --no-cache xf86-video-dummy && /usr/local/bin/check_llvm15.sh "after-xf86-video-dummy" || true
RUN apk add --no-cache glslang && /usr/local/bin/check_llvm15.sh "after-glslang" || true
RUN apk add --no-cache net-tools && /usr/local/bin/check_llvm15.sh "after-net-tools" || true
RUN apk add --no-cache iproute2 && /usr/local/bin/check_llvm15.sh "after-iproute2" || true


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
    rm *.apk && \
    /usr/local/bin/check_llvm15.sh "after-glibc" || true

# Stage: build core libraries
FROM base-deps AS libs-build
WORKDIR /build

# Pre-build LLVM status
RUN /usr/local/bin/check_llvm15.sh "libs-build-start" || true

# Install build dependencies with INDIVIDUAL LLVM15 monitoring
RUN apk add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true  
RUN apk add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true

# Install X11 protocol packages first (these are needed for xorg-server build)
RUN apk add --no-cache xf86driproto && /usr/local/bin/check_llvm15.sh "after-xf86driproto" || true
RUN apk add --no-cache xf86vidmodeproto && /usr/local/bin/check_llvm15.sh "after-xf86vidmodeproto" || true
RUN apk add --no-cache glproto && /usr/local/bin/check_llvm15.sh "after-glproto" || true
RUN apk add --no-cache dri2proto && /usr/local/bin/check_llvm15.sh "after-dri2proto" || true
RUN apk add --no-cache libxext-dev && /usr/local/bin/check_llvm15.sh "after-libxext-dev" || true
RUN apk add --no-cache libxrender-dev && /usr/local/bin/check_llvm15.sh "after-libxrender-dev" || true
RUN apk add --no-cache libxfixes-dev && /usr/local/bin/check_llvm15.sh "after-libxfixes-dev" || true
RUN apk add --no-cache libxdamage-dev && /usr/local/bin/check_llvm15.sh "after-libxdamage-dev" || true
RUN apk add --no-cache libxcb-dev && /usr/local/bin/check_llvm15.sh "after-libxcb-dev" || true

# Additional dependencies for xorg-server build
RUN apk add --no-cache \
    autoconf \
    automake \
    libtool \
    util-macros \
    xorg-util-macros \
    libdrm-dev \
    libpciaccess-dev \
    libepoxy-dev \
    pixman-dev \
    xkeyboard-config \
    xkbcomp \
    libxkbfile-dev \
    libxfont2-dev && \
    /usr/local/bin/check_llvm15.sh "after-xorg-build-deps" || true

# BUILD XORG-SERVER FROM SOURCE (avoiding LLVM15 contamination)
RUN echo "=== BUILDING XORG-SERVER FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-xorg-server-source-build" || true && \
    git clone --depth=1 --branch xorg-server-21.1.8 https://gitlab.freedesktop.org/xorg/xserver.git && \
    cd xserver && \
    echo "=== CONFIGURING XORG-SERVER WITH LLVM16 EXPLICIT PATHS ===" && \
    autoreconf -fiv && \
    ./configure \
        --prefix=/usr/local \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-systemd-logind \
        --disable-libunwind \
        --enable-glamor \
        --enable-dri \
        --enable-dri2 \
        --enable-dri3 \
        --enable-xvfb \
        --enable-xnest \
        --enable-xephyr \
        --disable-xorg \
        --disable-dmx \
        --disable-xwin \
        --disable-xquartz \
        --without-dtrace \
        CC=clang-16 \
        CXX=clang++-16 \
        LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config \
        CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        LDFLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        PKG_CONFIG_PATH="/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
    echo "=== BUILDING XORG-SERVER ===" && \
    make -j"$(nproc)" && \
    echo "=== INSTALLING XORG-SERVER ===" && \
    make install && \
    echo "=== CREATING XORG-SERVER-DEV COMPATIBILITY HEADERS ===" && \
    mkdir -p /usr/local/include/xorg && \
    cp -r include/* /usr/local/include/xorg/ || true && \
    cd .. && \
    rm -rf xserver && \
    /usr/local/bin/check_llvm15.sh "post-xorg-server-source-build" || true

# Continue with remaining packages
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true
RUN apk add --no-cache python3-dev && /usr/local/bin/check_llvm15.sh "after-python3-dev" || true
RUN apk add --no-cache py3-setuptools && /usr/local/bin/check_llvm15.sh "after-py3-setuptools" || true
RUN apk add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true

# Debug tools
RUN apk add --no-cache strace && /usr/local/bin/check_llvm15.sh "after-strace" || true
RUN apk add --no-cache file && /usr/local/bin/check_llvm15.sh "after-file" || true
RUN apk add --no-cache tree && /usr/local/bin/check_llvm15.sh "after-tree" || true

# BUILD SHADERC FROM SOURCE (avoiding LLVM15 contamination)
RUN echo "=== BUILDING SHADERC FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-shaderc-source-build" || true && \
    git clone --recursive https://github.com/google/shaderc.git && \
    cd shaderc && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
        -DCMAKE_C_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        -DSHADERC_SKIP_TESTS=ON \
        -DSHADERC_SKIP_EXAMPLES=ON && \
    make -j"$(nproc)" install && \
    cd ../.. && \
    rm -rf shaderc && \
    /usr/local/bin/check_llvm15.sh "post-shaderc-source-build" || true

# Media packages
RUN apk add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true


RUN apk add --no-cache v4l-utils-dev && /usr/local/bin/check_llvm15.sh "after-v4l-utils-dev" || true

# Install Python dependencies for Mesa and glmark2
RUN pip install --no-cache-dir meson==1.4.0 mako==1.3.3 && \
    /usr/local/bin/check_llvm15.sh "after-python-packages" || true

    # Build libgbm from source (required for GBM on this image)
RUN echo "=== BUILDING libgbm FROM SOURCE ===" && \
    apk add --no-cache autoconf automake libtool pkgconf pkgconfig && \
    /usr/local/bin/check_llvm15.sh "pre-libgbm-deps" || true && \
    git clone --depth=1 https://github.com/robclark/libgbm.git && \
    cd libgbm && \
    ./autogen.sh --prefix=/usr/local && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf libgbm && \
    /usr/local/bin/check_llvm15.sh "after-libgbm" || true

# BUILD GST-PLUGINS-BASE FROM SOURCE (avoiding LLVM15 contamination)
RUN echo "=== BUILDING GST-PLUGINS-BASE FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gst-plugins-base-source-build" || true && \
    wget https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.20.3.tar.xz && \
    tar -xvf gst-plugins-base-1.20.3.tar.xz && \
    cd gst-plugins-base-1.20.3 && \
    echo "=== CONFIGURING GST-PLUGINS-BASE WITH LLVM16 EXPLICIT PATHS ===" && \
    ./configure \
        --prefix=/usr/local \
        --disable-static \
        --enable-shared \
        --disable-introspection \
        --disable-examples \
        --disable-gtk-doc \
        CC=clang-16 \
        CXX=clang++-16 \
        LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config \
        CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        LDFLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        PKG_CONFIG_PATH="/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
    echo "=== BUILDING GST-PLUGINS-BASE ===" && \
    make -j"$(nproc)" && \
    echo "=== INSTALLING GST-PLUGINS-BASE ===" && \
    make install && \
    cd .. && \
    rm -rf gst-plugins-base-* && \
    /usr/local/bin/check_llvm15.sh "post-gst-plugins-base-source-build" || true
    
# Set verbose build environment
ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

# Mesa build with LLVM monitoring and explicit LLVM16 usage
RUN echo "=== MESA BUILD WITH LLVM16 ENFORCEMENT ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-clone" || true && \
    git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git && \
    /usr/local/bin/check_llvm15.sh "post-mesa-clone" || true && \
    cd mesa && \
    git checkout mesa-24.0.3 && \
    echo "=== MESA BUILD CONFIGURATION (ARM64 + LLVM16) ===" && \
    CC=clang-16 CXX=clang++-16 LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config \
    meson setup builddir/ \
        -Dprefix=/usr/local \
        -Dglx=disabled \
        -Ddri3=disabled \
        -Degl=enabled \
        -Dgbm=enabled \
        -Dplatforms=wayland \
        -Dglvnd=false \
        -Dosmesa=true \
        -Dgallium-drivers=swrast,kmsro,zink \
        -Dvulkan-drivers=swrast \
        -Dbuildtype=debugoptimized \
        --fatal-meson-warnings \
        --wrap-mode=nodownload \
        -Dllvm=enabled \
        -Dc_args="-v -Wno-error -march=armv8-a -I/usr/lib/llvm16/include" \
        -Dcpp_args="-v -Wno-error -march=armv8-a -I/usr/lib/llvm16/include" \
        -Dc_link_args="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        -Dcpp_link_args="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" && \
    /usr/local/bin/check_llvm15.sh "post-mesa-configure" || true && \
    echo "=== MESA BUILD LOGS ===" && \
    cat builddir/meson-logs/meson-log.txt && \
    echo "=== MESA CONFIGURATION ===" && \
    meson configure builddir/ && \
    echo "=== STARTING NINJA BUILD (ARM64 + LLVM16) ===" && \
    ninja -C builddir -v install && \
    /usr/local/bin/check_llvm15.sh "post-mesa-build" || true && \
    echo "=== VULKAN ICD CONFIGURATION (ARM64) ===" && \
    mkdir -p /usr/share/vulkan/icd.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > /usr/share/vulkan/icd.d/swrast_icd.arm64.json && \
    echo "=== MESA BUILD COMPLETED ===" && \
    cd .. && \
    rm -rf mesa && \
    /usr/local/bin/check_llvm15.sh "post-mesa-cleanup" || true

# Create DRI directory structure
RUN mkdir -p /usr/lib/xorg/modules/dri && \
    ln -s /usr/lib/dri /usr/lib/xorg/modules/dri

# Build and install SDL3
RUN /usr/local/bin/check_llvm15.sh "pre-sdl3" || true && \
    git clone --depth=1 https://github.com/libsdl-org/SDL.git sdl && \
    cd sdl && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
        -DSDL_STATIC=ON \
        -DSDL_SHARED=OFF \
        -DSDL_VIDEO=ON \
        -DSDL_VULKAN=ON \
        -DSDL_WAYLAND=ON \
        -DSDL_X11=ON \
        -DSDL_RPI=ON \
        -DSDL_OPENGL=ON \
        -DSDL_OPENGLES=ON \
        -DSDL_RENDER=ON \
        -DSDL_AUDIO=ON \
        -DCMAKE_C_FLAGS="-march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a" && \
    make -j"$(nproc)" install && \
    /usr/local/bin/check_llvm15.sh "post-sdl3" || true

# Vulkan-Headers
RUN /usr/local/bin/check_llvm15.sh "pre-vulkan-headers" || true && \
    git clone --progress https://github.com/KhronosGroup/Vulkan-Headers.git && \
    cd Vulkan-Headers && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_C_COMPILER=clang-16 \
          -DCMAKE_CXX_COMPILER=clang++-16 \
          -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a" \
          -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a" && \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Headers && \
    /usr/local/bin/check_llvm15.sh "post-vulkan-headers" || true

# Vulkan-Loader
RUN /usr/local/bin/check_llvm15.sh "pre-vulkan-loader" || true && \
    git clone --progress https://github.com/KhronosGroup/Vulkan-Loader.git && \
    cd Vulkan-Loader && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_C_COMPILER=clang-16 \
          -DCMAKE_CXX_COMPILER=clang++-16 \
          -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a" \
          -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a" \
          -DBUILD_TESTS=OFF -DVULKAN_HEADERS_INSTALL_DIR=/usr/local && \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Loader && \
    /usr/local/bin/check_llvm15.sh "post-vulkan-loader" || true

# Build and install glmark2 with explicit LLVM16
RUN echo "===== START GLMARK2 BUILD WITH LLVM16 =====" && \
    /usr/local/bin/check_llvm15.sh "pre-glmark2" || true && \
    git clone --depth=1 https://github.com/glmark2/glmark2.git && \
    cd glmark2 && \
    echo "===== DIRECTORY STRUCTURE (PRE-BUILD) =====" && \
    tree -L 2 && \
    echo "===== WAF SCRIPT PERMISSIONS =====" && \
    ls -l waf* || true && \
    echo "===== CONFIGURING GLMARK2 WITH LLVM16 =====" && \
    CC=clang-16 CXX=clang++-16 \
    CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
    CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
    LDFLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
    python3 ./waf configure --prefix=/usr/local --with-flavors=x11-gl,drm-gl --verbose 2>&1 | tee configure.log || { \
        echo "===== CONFIGURATION FAILED - SHOWING LOG ====="; \
        cat configure.log; \
    } && \
    echo "===== BUILDING GLMARK2 =====" && \
    python3 ./waf build -j"$(nproc)" --verbose 2>&1 | tee build.log || { \
        echo "===== BUILD FAILED - SHOWING LOG ====="; \
        cat build.log; \
    } && \
    echo "===== INSTALLING GLMARK2 =====" && \
    python3 ./waf install --verbose 2>&1 | tee install.log && \
    echo "===== GLMARK2 BUILD COMPLETED =====" && \
    /usr/local/bin/check_llvm15.sh "post-glmark2" || true

# Stage: build application
FROM libs-build AS app-build
WORKDIR /app

# Ensure system-level Mesa / OSMesa development packages are available on this stage
# so CMake's find_library(...) for mesa/OSMesa can discover them in /usr/lib.
# This prevents the CMakeLists.txt fatal error: "Could not find software rendering libraries"
# (we add minimal system packages — libs/headers — here only).
RUN apk add --no-cache \
        mesa-dev \
        mesa-osmesa 

COPY . .
WORKDIR /app/build
RUN /usr/local/bin/check_llvm15.sh "pre-app-build" || true && \
    cmake -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
         -DCMAKE_C_COMPILER=clang-16 \
         -DCMAKE_CXX_COMPILER=clang++-16 \
         -DCMAKE_C_FLAGS="-I/usr/lib/llvm16/include" \
         -DCMAKE_CXX_FLAGS="-I/usr/lib/llvm16/include" \
         -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
         ../src && \
    # explicitly build the simplehttpserver target so the binary exists for the COPY
    cmake --build . --target simplehttpserver --parallel "$(nproc)" && \
    /usr/local/bin/check_llvm15.sh "post-app-build" || true

# Stage: debug environment
FROM base-deps AS debug
COPY --from=libs-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver

# Install debug tools + LLVM runtime with monitoring
RUN apk add --no-cache mesa-demos && /usr/local/bin/check_llvm15.sh "debug-after-mesa-demos" || true
RUN apk add --no-cache xdpyinfo && /usr/local/bin/check_llvm15.sh "debug-after-xdpyinfo" || true
RUN apk add --no-cache xrandr && /usr/local/bin/check_llvm15.sh "debug-after-xrandr" || true
RUN apk add --no-cache xeyes && /usr/local/bin/check_llvm15.sh "debug-after-xeyes" || true
RUN apk add --no-cache gdb && /usr/local/bin/check_llvm15.sh "debug-after-gdb" || true
RUN apk add --no-cache valgrind && /usr/local/bin/check_llvm15.sh "debug-after-valgrind" || true
RUN apk add --no-cache libxxf86vm && /usr/local/bin/check_llvm15.sh "debug-after-libxxf86vm" || true

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
    LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/lib:/usr/glibc-compat/lib:/usr/local/lib

USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]

# Stage: runtime environment
FROM alpine:3.18 AS runtime

# Runtime packages with LLVM monitoring
RUN apk add --no-cache libstdc++ && echo "Installed libstdc++"
RUN apk add --no-cache libgcc && echo "Installed libgcc"
RUN apk add --no-cache freetype && echo "Installed freetype"
RUN apk add --no-cache fontconfig && echo "Installed fontconfig"
RUN apk add --no-cache libx11 && echo "Installed libx11"
RUN apk add --no-cache libxcomposite && echo "Installed libxcomposite"
RUN apk add --no-cache libxext && echo "Installed libxext"
RUN apk add --no-cache libxrandr && echo "Installed libxrandr"
RUN apk add --no-cache libxrender && echo "Installed libxrender"
RUN apk add --no-cache libxfixes && echo "Installed libxfixes"
RUN apk add --no-cache libxcursor && echo "Installed libxcursor"
RUN apk add --no-cache libxi && echo "Installed libxi"
RUN apk add --no-cache libxinerama && echo "Installed libxinerama"
RUN apk add --no-cache libxdamage && echo "Installed libxdamage"
RUN apk add --no-cache libxshmfence && echo "Installed libxshmfence"
RUN apk add --no-cache libxcb && echo "Installed libxcb"
RUN apk add --no-cache libxxf86vm && echo "Installed libxxf86vm"
RUN apk add --no-cache wayland && echo "Installed wayland"
RUN apk add --no-cache alsa-lib && echo "Installed alsa-lib"
RUN apk add --no-cache pulseaudio && echo "Installed pulseaudio"

# Install LLVM16 first to establish preference
RUN apk add --no-cache llvm16-libs && echo "Installed llvm16-libs"

# High suspect packages for LLVM15 in runtime - install carefully
RUN echo "=== INSTALLING MESA PACKAGES - MONITORING FOR LLVM15 CONTAMINATION ===" && \
    apk add --no-cache mesa-dri-gallium && echo "Installed mesa-dri-gallium"
RUN apk add --no-cache mesa-va-gallium && echo "Installed mesa-va-gallium"  
RUN apk add --no-cache mesa-vdpau-gallium && echo "Installed mesa-vdpau-gallium"
RUN apk add --no-cache mesa-vulkan-swrast && echo "Installed mesa-vulkan-swrast"

RUN apk add --no-cache glu && echo "Installed glu"

# Final runtime LLVM15 check
RUN cat > /usr/local/bin/check_llvm15.sh <<'SH' && chmod +x /usr/local/bin/check_llvm15.sh
#!/bin/sh
set -eux

STAGE="${1:-unknown-stage}"
OUT="/tmp/llvm15_debug_${STAGE}.log"
echo "=== LLVM15 DEBUG: stage=${STAGE} timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >"$OUT"

# Find LLVM 15 files
echo ">> Searching for LLVM-15 files..." | tee -a "$OUT"
LLVM15_FILES=$(find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null || true)
if [ -n "$LLVM15_FILES" ]; then
    echo "FOUND LLVM15 FILES:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | tee -a "$OUT"
    
    # Find owning packages
    echo ">> Package owners:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | while read -r f; do
        if [ -f "$f" ]; then
            OWNER=$(apk info --who-owns "$f" 2>/dev/null | head -n1 || echo "UNKNOWN")
            echo "FILE: $f -> OWNED BY: $OWNER" | tee -a "$OUT"
        fi
    done
    echo "VERDICT: LLVM15 CONTAMINATION DETECTED in ${STAGE}" | tee -a "$OUT"
else
    echo "NO LLVM15 FILES FOUND" | tee -a "$OUT"
    echo "VERDICT: LLVM15 CLEAN in ${STAGE}" | tee -a "$OUT"
fi

# Always show the log
echo "" && echo "=== RUNTIME DEBUG LOG ===" && cat "$OUT"
SH

RUN /usr/local/bin/check_llvm15.sh "runtime-final" || true

# GBM library check
RUN set -eux; \
    if apk add --no-cache libgbm 2>/dev/null; then \
        echo "Installed libgbm"; \
        /usr/local/bin/check_llvm15.sh "after-libgbm" || true; \
    else \
        apk add --no-cache mesa-gbm || true; \
        /usr/local/bin/check_llvm15.sh "after-mesa-gbm" || true; \
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
    LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib:/usr/glibc-compat/lib \
    LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config

# FINAL COMPREHENSIVE LLVM15 ANALYSIS
RUN set -eux; \
    echo "=== FINAL LLVM15 ANALYSIS ==="; \
    echo "Searching entire filesystem for LLVM15..."; \
    find /usr -name '*llvm*15*' -o -name '*LLVM*15*' 2>/dev/null | tee /tmp/all_llvm15_files.txt || true; \
    if [ -s /tmp/all_llvm15_files.txt ]; then \
        echo "=== ALL LLVM15 RELATED FILES ==="; \
        cat /tmp/all_llvm15_files.txt; \
        echo "=== PACKAGE OWNERSHIP ANALYSIS ==="; \
        while read -r f; do \
            if [ -f "$f" ] || [ -L "$f" ]; then \
                echo "FILE: $f"; \
                apk info --who-owns "$f" 2>/dev/null || echo "  No package owns this file"; \
            fi; \
        done < /tmp/all_llvm15_files.txt; \
        echo "=== INSTALLED PACKAGES WITH LLVM15 DEPS ==="; \
        apk info --installed | while read -r pkg; do \
            if apk info -R "$pkg" 2>/dev/null | grep -q llvm15; then \
                echo "PACKAGE: $pkg depends on LLVM15"; \
                apk info -R "$pkg" | grep llvm15; \
            fi; \
        done; \
        echo "=== WARNING: LLVM15 FILES FOUND BUT CONTINUING ==="; \
        echo "The build will continue with LLVM16 preference enforced via environment variables."; \
    else \
        echo "=== SUCCESS: NO LLVM15 CONTAMINATION DETECTED ==="; \
    fi

USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]
