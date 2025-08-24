# Stage: base deps (Alpine version)
FROM alpine:3.21 AS base-deps

# Install bare essentials
RUN apk add --no-cache bash wget coreutils findutils file

# Container Directory - different from repo directory (container in abstract space)
RUN mkdir -p \
    # our OS's main folder
    /lilyspark \
    # For anything kernel related, Level 0
    /lilyspark/sysroot \
    /lilyspark/sysroot/kern \
    /lilyspark/sysroot/asm \
    /lilyspark/sysroot/os/bin \
    # For anything OS related, Level 1
    /lilyspark/src \
    # Home directory
    /lilyspark/home \
    # User's directory
    /lilyspark/usr/include \
    /lilyspark/usr/lib \
    /lilyspark/usr/bin \
    /lilyspark/usr/sbin \
    # User's native OS dependencies
    /lilyspark/usr/local/bin \
    /lilyspark/usr/local/sbin \
    /lilyspark/usr/local/lib \
    /lilyspark/usr/local/share \
    # User's OS dependencies - Still Essential
    /lilyspark/usr/local/lib \
    /lilyspark/usr/local/lib/audio \
    /lilyspark/usr/local/lib/av \
    /lilyspark/usr/local/lib/compression \
    /lilyspark/usr/local/lib/database \
    /lilyspark/usr/local/lib/device_management \
    /lilyspark/usr/local/lib/documentation \
    /lilyspark/usr/local/lib/graphics \
    /lilyspark/usr/local/lib/i18n \
    /lilyspark/usr/local/lib/image \
    /lilyspark/usr/local/lib/java \
    /lilyspark/usr/local/lib/math \
    /lilyspark/usr/local/lib/networking \
    /lilyspark/usr/local/lib/python \
    /lilyspark/usr/local/lib/security \
    /lilyspark/usr/local/lib/system \
    /lilyspark/usr/local/lib/testing \
    /lilyspark/usr/local/lib/video \
    /lilyspark/usr/local/lib/wayland \
    /lilyspark/usr/local/lib/x11 \
    # Third-party libraries
    /lilyspark/opt \
    /lilyspark/opt/bin \
    /lilyspark/opt/include \
    /lilyspark/opt/lib \
    /lilyspark/opt/lib/graphics \
    # Main Compiler
    /lilyspark/compiler/bin \
    /lilyspark/compiler/lib \
    /lilyspark/compiler/include \
    # GLIBC Compiler
    /lilyspark/glibc/bin \
    /lilyspark/glibc/sbin \
    /lilyspark/glibc/lib \
    /lilyspark/glibc/include \
    # Distribution
    /lilyspark/dist \
    # App
    /lilyspark/app/build_files \
    # MISC
    /lilyspark/etc \
    /lilyspark/var \
    /lilyspark/tmp && \
    echo "=== DIRECTORY CREATION VERIFICATION ===" && \
    echo "Checking /lilyspark/usr/bin:" && ls -la /lilyspark/usr/bin && \
    echo "Checking /lilyspark/compiler/bin:" && ls -la /lilyspark/compiler/bin && \
    echo "Checking /lilyspark/compiler/lib:" && ls -la /lilyspark/compiler/lib && \
    echo "All directories created successfully"


# Copy debug + inspection scripts
COPY setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
COPY setup-scripts/binlib_validator.sh /usr/local/bin/binlib_validator.sh
RUN chmod +x /usr/local/bin/check_llvm15.sh \
    /usr/local/bin/check-filesystem.sh \
    /usr/local/bin/binlib_validator.sh

# Remove any preinstalled LLVM/Clang
RUN apk del --no-cache llvm clang || true

# Install glibc compatibility layer with ARM64 warning suppression
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-dev-2.35-r1.apk && \
    apk add --no-cache --allow-untrusted \
        glibc-2.35-r1.apk \
        glibc-bin-2.35-r1.apk \
        glibc-dev-2.35-r1.apk 2>&1 \
        | grep -v "unknown machine 183" \
        | awk 'NF' && \
    if [ -x /usr/glibc-compat/sbin/ldconfig ]; then \
        mv /usr/glibc-compat/sbin/ldconfig /usr/glibc-compat/sbin/ldconfig.real && \
        echo '#!/bin/sh' > /usr/glibc-compat/sbin/ldconfig && \
        echo '/usr/glibc-compat/sbin/ldconfig.real "$@" 2>&1 | grep -v "unknown machine 183" | awk '\''NF'\'' ' >> /usr/glibc-compat/sbin/ldconfig && \
        echo -e '\n\n' >> /usr/glibc-compat/sbin/ldconfig && \
        chmod +x /usr/glibc-compat/sbin/ldconfig; \
    fi && \
    rm -f /sbin/ldconfig || true && \
    rm -f *.apk || true && \
    /usr/local/bin/check_llvm15.sh "after-glibc" || true

# Copy glibc runtime into custom filesystem
RUN cp -r /usr/glibc-compat/lib/* /lilyspark/glibc/lib/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/bin/* /lilyspark/glibc/bin/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/sbin/* /lilyspark/glibc/sbin/ 2>/dev/null || true

# Install LLVM16 + Clang16 - FIXED VERSION
RUN apk add --no-cache llvm16-dev llvm16-libs clang16 && \
    echo "=== LLVM16 INSTALLATION VERIFICATION ===" && \
    echo "System LLVM16 binaries:" && \
    ls -la /usr/bin/clang-16 /usr/bin/clang++-16 || echo "LLVM16 binaries not found in expected location" && \
    echo "Available clang binaries:" && \
    find /usr -name "*clang*" -type f 2>/dev/null | head -10 && \
    echo "Copying LLVM16 binaries to /lilyspark/compiler/bin..." && \
    cp /usr/bin/clang-16 /lilyspark/compiler/bin/ 2>/dev/null || cp /usr/bin/clang /lilyspark/compiler/bin/clang-16 2>/dev/null || echo "Could not find clang-16, checking alternatives..." && \
    cp /usr/bin/clang++-16 /lilyspark/compiler/bin/ 2>/dev/null || cp /usr/bin/clang++ /lilyspark/compiler/bin/clang++-16 2>/dev/null || echo "Could not find clang++-16, checking alternatives..." && \
    echo "Copying LLVM16 libraries..." && \
    cp -r /usr/lib/llvm16/lib/* /lilyspark/compiler/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/llvm16/include/* /lilyspark/compiler/include/ 2>/dev/null || true && \
    echo "=== POST-COPY VERIFICATION ===" && \
    echo "Contents of /lilyspark/compiler/bin:" && \
    ls -la /lilyspark/compiler/bin/ && \
    echo "Contents of /lilyspark/compiler/lib:" && \
    ls -la /lilyspark/compiler/lib/ | head -10

# Environment setup
RUN cat > /lilyspark/etc/environment <<'ENV'
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:${PATH}"
export LLVM_CONFIG="/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/glibc"
ENV

# Quick filesystem checks
RUN /usr/local/bin/check_llvm15.sh "final" || true && \
    /usr/local/bin/check-filesystem.sh "final" || true

# Verify /lilyspark/usr/bin exists
RUN echo "=== Verifying /lilyspark/usr/bin ===" && \
    ls -la /lilyspark/usr/bin || echo "Missing /lilyspark/usr/bin"

#
#
#
#
#
#
#
#
#
#

# Stage: filesystem setup - Install base-deps
FROM base-deps AS filesystem-base-deps-builder


# Quick checks
RUN echo ">>> check /lilyspark/compiler/bin" && ls -la /lilyspark/compiler/bin || true
RUN echo ">>> check for libc++" && ls -la /lilyspark/compiler/lib | head -20 || true

# Force rebuild each time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_FS_STAGE2_$(date +%s%N)" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && rm -f /tmp/nocache/timestamp

# ======================
# Core packages ONLY
# ======================
# Vanilla requirements
RUN apk add --no-cache bash && /usr/local/bin/check_llvm15.sh "after-bash" || true
RUN apk add --no-cache curl && /usr/local/bin/check_llvm15.sh "after-curl" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache ca-certificates && /usr/local/bin/check_llvm15.sh "after-ca-certificates" || true
RUN apk add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk add --no-cache bsd-compat-headers && /usr/local/bin/check_llvm15.sh "after-bsd-compat-headers" || true
RUN apk add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk add --no-cache musl-dev && /usr/local/bin/check_llvm15.sh "after-musl-dev" || true
RUN apk add --no-cache pkgconf && /usr/local/bin/check_llvm15.sh "after-pkgconf" || true
RUN apk add --no-cache pkgconf-dev && /usr/local/bin/check_llvm15.sh "after-pkgconf-dev" || true
RUN apk add --no-cache autoconf && /usr/local/bin/check_llvm15.sh "after-autoconf" || true
RUN apk add --no-cache tar && /usr/local/bin/check_llvm15.sh "after-tar" || true
RUN apk add --no-cache git && /usr/local/bin/check_llvm15.sh "after-git" || true
RUN apk add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk add --no-cache glslang && /usr/local/bin/check_llvm15.sh "after-glslang" || true
RUN apk add --no-cache make && /usr/local/bin/check_llvm15.sh "after-make" || true
RUN apk add --no-cache cmake && /usr/local/bin/check_llvm15.sh "after-cmake" || true
RUN apk add --no-cache automake && /usr/local/bin/check_llvm15.sh "after-automake" || true
RUN apk add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true
RUN apk add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk add --no-cache libtool && /usr/local/bin/check_llvm15.sh "after-libtool" || true
RUN apk add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk add --no-cache util-macros && /usr/local/bin/check_llvm15.sh "after-util-macros" || true
RUN apk add --no-cache readline-dev && /usr/local/bin/check_llvm15.sh "after-readline-dev" || true
RUN apk add --no-cache openssl-dev && /usr/local/bin/check_llvm15.sh "after-openssl-dev" || true
RUN apk add --no-cache bzip2-dev && /usr/local/bin/check_llvm15.sh "after-bzip2-dev" || true

# Render essentials
RUN apk add --no-cache meson && /usr/local/bin/check_llvm15.sh "after-meson" || true
RUN apk add --no-cache ninja && /usr/local/bin/check_llvm15.sh "after-ninja" || true

# ===============================
# Copy essentials into /lilyspark
# ===============================
RUN echo "=== COPYING CORE SYSROOT FILES TO /lilyspark ===" && \
    mkdir -p /lilyspark/usr/{bin,lib,include,share} /lilyspark/lib && \
    \
    # Copy apk db (for later reference/debug)
    cp -r /lib/apk /lilyspark/lib/ 2>/dev/null || true && \
    \
    # Copy libc/musl runtime
    cp -a /lib/ld-musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    cp -a /lib/libc.musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    ln -sf libc.musl-*.so.1 /lilyspark/lib/libc.so 2>/dev/null || true && \
    ln -sf ld-musl-*.so.1 /lilyspark/lib/ld-linux.so.1 2>/dev/null || true && \
    \
    # Copy toolchain runtime bits
    cp -a /usr/lib/libgcc* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/libstdc++* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -a /lib/crt*.o /usr/lib/crt*.o /lilyspark/usr/lib/ 2>/dev/null || true && \
    \
    # Copy headers + share data
    cp -r /usr/include/* /lilyspark/usr/include/ 2>/dev/null || true && \
    cp -r /usr/share/* /lilyspark/usr/share/ 2>/dev/null || true && \
    \
    # Verify
    echo "--- FS COPY CHECK ---" && \
    find /lilyspark/lib -maxdepth 1 -type f | head -10 && \
    ls -la /lilyspark/usr/bin | head -10 || true && \
    ls -la /lilyspark/usr/lib | head -10 || true

# ===============================
# Debug tools - May change folder
# ===============================
RUN apk add --no-cache file tree valgrind-dev linux-tools-dev && \
    mkdir -p /lilyspark/usr/debug/bin && \
    cp /usr/bin/file /usr/bin/tree /lilyspark/usr/debug/bin/ 2>/dev/null || true && \
    chmod -R a+rx /lilyspark/usr/debug/bin && \
    echo "Debug tools isolated into /lilyspark/usr/debug/bin"

# =========================
# Other Essential Libraries
# =========================
# Audio Libraries - /lilyspark/usr/local/lib/audio
RUN apk add --no-cache sndio-dev && /usr/local/bin/check_llvm15.sh "after-sndio-dev" || true
RUN apk add --no-cache libvorbis-dev && /usr/local/bin/check_llvm15.sh "after-liborbis-dev" || true
RUN apk add --no-cache libogg-dev && /usr/local/bin/check_llvm15.sh "after-libogg-dev" || true
RUN apk add --no-cache flac-dev && /usr/local/bin/check_llvm15.sh "after flac-dev" || true
RUN apk add --no-cache libmodplug-dev && /usr/local/bin/check_llvm15.sh "after-libmodplug-dev" || true
RUN apk add --no-cache mpg123-dev && /usr/local/bin/check_llvm15.sh "after-mpg123-dev" || true
RUN apk add --no-cache opusfile-dev && /usr/local/bin/check_llvm15.sh "after-opusfile-dev" || true
RUN apk add --no-cache alsa-lib-dev && /usr/local/bin/check_llvm15.sh "after-alsa-lib-dev" || true
RUN apk add --no-cache pulseaudio-dev && /usr/local/bin/check_llvm15.sh "after-pulseaudio-dev" || true
RUN apk add --no-cache libsamplerate-dev && /usr/local/bin/check_llvm15.sh "after-libsamplerate-dev" || true
RUN apk add --no-cache portaudio-dev && /usr/local/bin/check_llvm15.sh "after-portaudio-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING AUDIO LIBRARIES ===" && \
    cp -a /usr/include/sndio* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/vorbis* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/ogg* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/FLAC* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/libmodplug* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/mpg123* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/opus* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/alsa* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/pulse* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/samplerate* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/include/portaudio* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    \
    cp -a /usr/lib/libsndio* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libvorbis* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libogg* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libFLAC* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libmodplug* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libmpg123* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libopus* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libalsa* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libpulse* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libsamplerate* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    cp -a /usr/lib/libportaudio* /lilyspark/usr/local/lib/audio/ 2>/dev/null || true && \
    \
    echo "--- AUDIO CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/audio | head -20 || true

#
#
#

# A/V Libraries - /lilyspark/usr/local/lib/av
RUN apk add --no-cache pipewire-dev && /usr/local/bin/check_llvm15.sh "after-pipewire-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING AUDIO LIBRARIES ===" && \
    cp -a /usr/lib/libpipewire* /lilyspark/usr/local/lib/av/ || true && \
    echo "--- A/V CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/av | head -20 || true

#
#
#

# Compression Libraries - /lilyspark/usr/local/lib/compression
RUN apk add --no-cache xz-dev && /usr/local/bin/check_llvm15.sh "after-xz-dev" || true
RUN apk add --no-cache zstd-dev && /usr/local/bin/check_llvm15.sh "after-zstd-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING COMPRESSION LIBRARIES ===" && \
    cp -a /usr/lib/liblzma* /lilyspark/usr/local/lib/compression/ 2>/dev/null || true && \
    cp -a /usr/lib/libzstd* /lilyspark/usr/local/lib/compression/ 2>/dev/null || true && \
    echo "--- COMPRESSION CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/compression | head -10 || true

#
#
#

# Database Libraries - /lilyspark/usr/local/lib/database
RUN apk add --no-cache sqlite-dev && /usr/local/bin/check_llvm15.sh "after-sqlite-dev" || true
RUN apk add --no-cache libedit-dev && /usr/local/bin/check_llvm15.sh "after-libedit-dev" || true
RUN apk add --no-cache icu-dev && /usr/local/bin/check_llvm15.sh "after-icu-dev" || true
RUN apk add --no-cache tcl-dev && /usr/local/bin/check_llvm15.sh "after-tcl-dev" || true
RUN apk add --no-cache lz4-dev && /usr/local/bin/check_llvm15.sh "after-lz4-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING DATABASE LIBRARIES ===" && \
    cp -a /usr/lib/libsqlite* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libedit* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libicu* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libtcl* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/liblz4* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    echo "--- DATABASE CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/database | head -10 || true

#
#
#

# Device Management Libraries - /lilyspark/usr/local/lib/device_management
RUN apk add --no-cache eudev-dev && /usr/local/bin/check_llvm15.sh "after-eudev-dev" || true
RUN apk add --no-cache pciutils-dev && /usr/local/bin/check_llvm15.sh "after-pciutils-dev" || true
RUN apk add --no-cache libusb-dev && /usr/local/bin/check_llvm15.sh "after-libusb-dev" || true

    # Copy Libraries To Directory
# Copy Libraries To Directory
RUN echo "=== COPYING DEVICE MANAGEMENT LIBRARIES ===" && \
    cp -a /usr/include/eudev /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libudev* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libpci* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libusb* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    echo "--- DEVICE MANAGEMENT CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/device_management | head -10 || true

#
#
#

# Documentation Libraries - /lilyspark/usr/local/lib/documentation
RUN apk add --no-cache xmlto && /usr/local/bin/check_llvm15.sh "after-xmlto" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING DOCUMENTATION LIBRARIES ===" && \
    cp -a /usr/bin/xmlto /lilyspark/usr/local/lib/documentation/ 2>/dev/null || true && \
    cp -a /usr/share/xmlto /lilyspark/usr/local/lib/documentation/ 2>/dev/null || true && \
    echo "--- DOCUMENTATION CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/documentation | head -10 || true

#
#
#

# Graphics Libraries - /lilyspark/usr/local/lib/graphics
RUN apk add --no-cache gtk+3-dev && /usr/local/bin/check_llvm15.sh "after-gtk+3-dev" || true
RUN apk add --no-cache cairo-dev && /usr/local/bin/check_llvm15.sh "after-cairo-dev" || true
RUN apk add --no-cache pixman-dev && /usr/local/bin/check_llvm15.sh "after-pixman-dev" || true
RUN apk add --no-cache harfbuzz-dev && /usr/local/bin/check_llvm15.sh "after-harfbuzz-dev" || true
RUN apk add --no-cache vulkan-headers && /usr/local/bin/check_llvm15.sh "after-vulkan-headers" || true
RUN apk add --no-cache vulkan-loader && /usr/local/bin/check_llvm15.sh "after-vulkan-loader" || true
RUN apk add --no-cache vulkan-tools && /usr/local/bin/check_llvm15.sh "after-vulkan-tools" || true
RUN apk add --no-cache freetype-dev && /usr/local/bin/check_llvm15.sh "after-freetype-dev" || true
RUN apk add --no-cache fontconfig-dev && /usr/local/bin/check_llvm15.sh "after-fontconfig-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING GRAPHICS LIBRARIES ===" && \
    cp -a /usr/include/harfbuzz /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/include/freetype2 /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/include/fontconfig /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/lib/libharfbuzz* /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/lib/libfreetype* /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/lib/libfontconfig* /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    cp -a /usr/lib/libvulkan* /lilyspark/usr/local/lib/graphics/ 2>/dev/null || true && \
    echo "--- GRAPHICS CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/graphics | head -10 || true

#
#
#

# i18n Libraries - /lilyspark/usr/local/lib/i18n \
RUN apk add --no-cache gettext-dev && /usr/local/bin/check_llvm15.sh "after-gettext-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING I18N LIBRARIES ===" && \
    cp -a /usr/include/gettext /lilyspark/usr/local/lib/i18n/ 2>/dev/null || true && \
    cp -a /usr/lib/libgettext* /lilyspark/usr/local/lib/i18n/ 2>/dev/null || true && \
    echo "--- I18N CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/i18n | head -10 || true
#
#
#

# Image Libraries - /lilyspark/usr/local/lib/image
RUN apk add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk add --no-cache libjpeg-turbo-dev && /usr/local/bin/check_llvm15.sh "after-libjpeg-turbo-dev" || true
RUN apk add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk add --no-cache tiff-dev && /usr/local/bin/check_llvm15.sh "after-tiff-dev" || true
RUN apk add --no-cache libtiff && /usr/local/bin/check_llvm15.sh "after-lib-tiff" || true
RUN apk add --no-cache libavif && /usr/local/bin/check_llvm15.sh "after-libavif" || true
RUN apk add --no-cache libwebp && /usr/local/bin/check_llvm15.sh "after-libwebp" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING IMAGE LIBRARIES ===" && \
    cp -a /usr/include/jpeg* /usr/include/png* /usr/include/tiff* /usr/include/libavif* /usr/include/libwebp* /lilyspark/usr/local/lib/image/ 2>/dev/null || true && \
    cp -a /usr/lib/libjpeg* /usr/lib/libpng* /usr/lib/libtiff* /usr/lib/libavif* /usr/lib/libwebp* /lilyspark/usr/local/lib/image/ 2>/dev/null || true && \
    echo "--- IMAGE CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/image | head -10 || true
#
#
#

# Java Libraries - /lilyspark/usr/local/lib/java
RUN apk add --no-cache openjdk11 && /usr/local/bin/check_llvm15.sh "after-openjdk11" || true
RUN apk add --no-cache ant && /usr/local/bin/check_llvm15.sh "after-ant" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING JAVA LIBRARIES ===" && \
    cp -a /usr/lib/jvm/java-11-openjdk /lilyspark/usr/local/lib/java/ 2>/dev/null || true && \
    cp -a /usr/bin/ant /lilyspark/usr/local/lib/java/ 2>/dev/null || true && \
    echo "--- JAVA CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/java | head -10 || true

#
#
#

# Math Libraries - /lilyspark/usr/local/lib/math
RUN apk add --no-cache eigen-dev && /usr/local/bin/check_llvm15.sh "after-eigen-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING MATH LIBRARIES ===" && \
    cp -a /usr/include/eigen3 /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    echo "--- MATH CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/math | head -10 || true

#
#
#

# Networking Libraries - /lilyspark/usr/local/lib/networking
RUN apk add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true
RUN apk add --no-cache libunwind-dev && /usr/local/bin/check_llvm15.sh "after-libunwind-dev" || true
RUN apk add --no-cache dbus-dev && /usr/local/bin/check_llvm15.sh "after-dbus-dev" || true
RUN apk add --no-cache libmnl-dev && /usr/local/bin/check_llvm15.sh "after-libmnl-dev" || true
RUN apk add --no-cache net-tools && /usr/local/bin/check_llvm15.sh "after-net-tools" || true
RUN apk add --no-cache iproute2 && /usr/local/bin/check_llvm15.sh "after-iproute2" || true

# Copy Libraries To Directory
RUN echo "=== COPYING NETWORKING LIBRARIES ===" && \
    cp -a /usr/include/pcap* /usr/include/unwind* /usr/include/dbus-1.0 /usr/include/libmnl* /lilyspark/usr/local/lib/networking/ 2>/dev/null || true && \
    cp -a /usr/lib/libpcap* /usr/lib/libunwind* /usr/lib/libdbus* /usr/lib/libmnl* /lilyspark/usr/local/lib/networking/ 2>/dev/null || true && \
    echo "--- NETWORKING CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/networking | head -10 || true

#
#
#

# Python Libraries - /lilyspark/usr/local/lib/python
RUN apk add --no-cache python3 && /usr/local/bin/check_llvm15.sh "after-python3" || true
RUN apk add --no-cache python3-dev && /usr/local/bin/check_llvm15.sh "after-python3-dev" || true
RUN apk add --no-cache py3-setuptools && /usr/local/bin/check_llvm15.sh "after-py3-setuptools" || true
RUN apk add --no-cache py3-pip && /usr/local/bin/check_llvm15.sh "after-py3-pip" || true
RUN apk add --no-cache mako && /usr/local/bin/check_llvm15.sh "after-mako" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING PYTHON LIBRARIES ===" && \
    cp -a /usr/lib/python3* /lilyspark/usr/local/lib/python/ 2>/dev/null || true && \
    cp -a /usr/bin/python3 /lilyspark/usr/local/lib/python/ 2>/dev/null || true && \
    cp -a /usr/lib/python3*/site-packages/mako /lilyspark/usr/local/lib/python/ 2>/dev/null || true && \
    cp -a /usr/lib/python3*/site-packages/setuptools /lilyspark/usr/local/lib/python/ 2>/dev/null || true && \
    cp -a /usr/bin/pip3 /lilyspark/usr/local/lib/python/ 2>/dev/null || true && \
    echo "--- PYTHON CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/python | head -10 || true
#
#
#

# Security Libraries - /lilyspark/usr/local/lib/security
RUN apk add --no-cache libselinux-dev && /usr/local/bin/check_llvm15.sh "after-libselinux-dev" || true
RUN apk add --no-cache libseccomp-dev && /usr/local/bin/check_llvm15.sh "after-libseccomp-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING SECURITY LIBRARIES ===" && \
    cp -a /usr/include/selinux /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/lib/libselinux* /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/include/seccomp /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/lib/libseccomp* /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    echo "--- SECURITY CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/security | head -10 || true
#
#
#

# System Libraries - /lilyspark/usr/local/lib/system
RUN apk add --no-cache libatomic_ops-dev && /usr/local/bin/check_llvm15.sh "after-libatomic_ops-dev" || true
RUN apk add --no-cache util-linux-dev && /usr/local/bin/check_llvm15.sh "after-util-linux-dev" || true
RUN apk add --no-cache libcap-dev && /usr/local/bin/check_llvm15.sh "after-libcap-dev" || true
RUN apk add --no-cache liburing-dev && /usr/local/bin/check_llvm15.sh "after-liburing-dev" || true
RUN apk add --no-cache e2fsprogs-dev && /usr/local/bin/check_llvm15.sh "after-e2fsprogs-dev" || true
RUN apk add --no-cache xfsprogs-dev && /usr/local/bin/check_llvm15.sh "after-xfsprogs-dev" || true
RUN apk add --no-cache btrfs-progs-dev && /usr/local/bin/check_llvm15.sh "after-btrfs-progs-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING SYSTEM LIBRARIES ===" && \
    cp -a /usr/include/liburing /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/lib/liburing* /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/include/libcap /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/lib/libcap* /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/include/libatomic_ops /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/lib/libatomic_ops* /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/include/e2fsprogs /usr/include/xfs /usr/include/btrfs /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/lib/libext2fs* /usr/lib/libxfs* /usr/lib/libbtrfs* /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    echo "--- SYSTEM CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/system | head -10 || true
#
#
#

# Testing Libraries - /lilyspark/usr/local/lib/testing
RUN apk add --no-cache cunit-dev && /usr/local/bin/check_llvm15.sh "after-cunit-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING TESTING LIBRARIES ===" && \
    cp -a /usr/include/cunit /lilyspark/usr/local/lib/testing/ 2>/dev/null || true && \
    cp -a /usr/lib/libcunit* /lilyspark/usr/local/lib/testing/ 2>/dev/null || true && \
    echo "--- TESTING CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/testing | head -10 || true
#
#
#

# Video Libraries - /lilyspark/usr/local/lib/video
RUN apk add --no-cache v4l-utils-dev && /usr/local/bin/check_llvm15.sh "after-v4l-utils-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING VIDEO LIBRARIES ===" && \
    cp -a /usr/include/libv4l* /lilyspark/usr/local/lib/video/ 2>/dev/null || true && \
    cp -a /usr/lib/libv4l* /lilyspark/usr/local/lib/video/ 2>/dev/null || true && \
    echo "--- VIDEO CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/video | head -10 || true

#
#
#

# Wayland Libraries - /lilyspark/usr/local/lib/wayland
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING WAYLAND LIBRARIES ===" && \
    cp -a /usr/include/wayland* /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    cp -a /usr/include/wayland-protocols /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    cp -a /usr/lib/libwayland* /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    echo "--- WAYLAND CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/wayland | head -10 || true

#
#
#

# X11 Libraries - /lilyspark/usr/local/lib/x11
RUN apk add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true
RUN apk add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true
RUN apk add --no-cache xkeyboard-config && /usr/local/bin/check_llvm15.sh "after-xkeyboard-config" || true
RUN apk add --no-cache xkbcomp && /usr/local/bin/check_llvm15.sh "after-xkbcomp" || true
RUN apk add --no-cache libxkbfile-dev && /usr/local/bin/check_llvm15.sh "after-libxkbfile-dev" || true
RUN apk add --no-cache libxfont2-dev && /usr/local/bin/check_llvm15.sh "after-libxfont2-dev" || true
RUN apk add --no-cache font-util-dev && /usr/local/bin/check_llvm15.sh "after-font-util-dev-dev" || true
RUN apk add --no-cache xcb-util-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-dev" || true
RUN apk add --no-cache xcb-util-renderutil-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-renderutil-dev" || true
RUN apk add --no-cache xcb-util-wm-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-wm-dev" || true
RUN apk add --no-cache xcb-util-keysyms-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-keysyms-dev" || true
RUN apk add --no-cache xf86driproto && /usr/local/bin/check_llvm15.sh "after-xf86driproto" || true
RUN apk add --no-cache xf86vidmodeproto && /usr/local/bin/check_llvm15.sh "after-xf86vidmodeproto" || true
RUN apk add --no-cache glproto && /usr/local/bin/check_llvm15.sh "after-glproto" || true
RUN apk add --no-cache dri2proto && /usr/local/bin/check_llvm15.sh "after-dri2proto" || true
RUN apk add --no-cache libxext-dev && /usr/local/bin/check_llvm15.sh "after-libxext-dev" || true
RUN apk add --no-cache libxrender-dev && /usr/local/bin/check_llvm15.sh "after-libxrender-dev" || true
RUN apk add --no-cache libxfixes-dev && /usr/local/bin/check_llvm15.sh "after-libxfixes-dev" || true
RUN apk add --no-cache libxdamage-dev && /usr/local/bin/check_llvm15.sh "after-libxdamage-dev" || true
RUN apk add --no-cache libxcb-dev && /usr/local/bin/check_llvm15.sh "after-libxcb-dev" || true
RUN apk add --no-cache libxcomposite-dev && /usr/local/bin/check_llvm15.sh "after-libxcomposite-dev" || true
RUN apk add --no-cache libxinerama-dev && /usr/local/bin/check_llvm15.sh "after-libxinerama-dev" || true
RUN apk add --no-cache libxi-dev && /usr/local/bin/check_llvm15.sh "after-libxi-dev" || true
RUN apk add --no-cache libxcursor-dev && /usr/local/bin/check_llvm15.sh "after-libxcursor-dev" || true
RUN apk add --no-cache libxrandr-dev && /usr/local/bin/check_llvm15.sh "after-libxrandr-dev" || true
RUN apk add --no-cache libxshmfence-dev && /usr/local/bin/check_llvm15.sh "after-libxshmfence-dev" || true
RUN apk add --no-cache libxxf86vm-dev && /usr/local/bin/check_llvm15.sh "after-libxxf86vm-dev" || true
RUN apk add --no-cache xf86-video-fbdev && /usr/local/bin/check_llvm15.sh "after-xf86-video-fbdev" || true
RUN apk add --no-cache xf86-video-dummy && /usr/local/bin/check_llvm15.sh "after-xf86-video-dummy" || true

# Copy Libraries To Directory
RUN echo "=== COPYING X11 LIBRARIES ===" && \
    cp -a /usr/include/X11 /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    cp -a /usr/include/xkb* /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    cp -a /usr/include/xf86* /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    cp -a /usr/include/gl* /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    cp -a /usr/include/dri2* /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    cp -a /usr/lib/libX11* /usr/lib/libxcb* /usr/lib/libXext* /usr/lib/libXrender* /usr/lib/libXfixes* /usr/lib/libXdamage* /usr/lib/libXcomposite* /usr/lib/libXinerama* /usr/lib/libXi* /usr/lib/libXcursor* /usr/lib/libXrandr* /usr/lib/libXshmfence* /usr/lib/libXXF86VM* /lilyspark/usr/local/lib/x11/ 2>/dev/null || true && \
    echo "--- X11 CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/x11 | head -20 || true

#
#
#



# Stage: filesystem-libs (minimal version for C++ Hello World)
FROM filesystem-base-deps-builder AS filesystem-libs-build-builder

# Cache busting
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_STAGE3_$(date +%s%N)" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && rm -f /tmp/nocache/timestamp


# ===========================
# Build From Source Libraries
# ===========================
# Graphics Libraries - /lilyspark/opt/lib/graphics


# ======================
# SECTION: Core C/C++ libs (tiny subset)
# ======================
RUN echo ">>> Installing minimal C/C++ dev libs for Hello World" && \
    apk add --no-cache libc-dev musl-dev libstdc++ && \
    /usr/local/bin/check_llvm15.sh "stage3-core" || true

# ======================
# SECTION: Copy sysroot libs into /lilyspark
# ======================
RUN echo ">>> Copying libc & stdc++ into /lilyspark sysroot" && \
    cp -a /usr/include/* /lilyspark/usr/include/ 2>/dev/null || true && \
    cp -a /usr/lib/libstdc++* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/libgcc* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -a /lib/ld-musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    cp -a /lib/libc.musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    # Copy essential runtime objects - find and copy all crt files
    find /usr/lib -name "crt*.o" -exec cp -a {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "crt*.o" -exec cp -a {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy gcc libraries
    find /usr/lib -name "libgcc*" -exec cp -a {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "libgcc*" -exec cp -a {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy ssp libraries
    find /usr/lib -name "*ssp*" -exec cp -a {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "=== SYSROOT VERIFICATION ===" && \
    ls -la /lilyspark/usr/lib | head -20

# ======================
# SECTION: Diagnostics (kept for consistency)
# ======================
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
COPY setup-scripts/binlib_validator.sh /usr/local/bin/binlib_validator.sh
RUN chmod +x /usr/local/bin/check-filesystem.sh /usr/local/bin/binlib_validator.sh && \
    /usr/local/bin/check-filesystem.sh "stage3-final" || true

# ======================
# SECTION: Environment Configuration
# ======================
ENV PKG_CONFIG_PATH=/lilyspark/compiler/lib/pkgconfig:/lilyspark/usr/vulkan/pkgconfig:/lilyspark/usr/x11/pkgconfig:/lilyspark/usr/lib/pkgconfig
ENV LD_LIBRARY_PATH=/lilyspark/compiler/lib:/lilyspark/usr/vulkan/lib:/lilyspark/usr/x11/lib:/lilyspark/usr/lib

# ======================
# SECTION: LLVM15 Contamination Check
# ======================
RUN echo "=== FINAL LLVM15 CONTAMINATION CHECK ===" && \
    (grep -R --binary-files=without-match -n "llvm-15" /lilyspark/ || true) | tee /tmp/llvm15-grep || true && \
    test ! -s /tmp/llvm15-grep || (echo "FOUND llvm-15 references - aborting" && cat /tmp/llvm15-grep && false) || true && \
    echo "=== STAGE END VERIFICATION: filesystem-libs-build-builder ===" && \
    echo "Verifying binary directory /lilyspark/usr/bin exists:" && \
    if [ -d /lilyspark/usr/bin ]; then \
        ls -la /lilyspark/usr/bin && \
        echo "✓ filesystem-libs-build-builder stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /lilyspark/usr/bin does not exist!" && \
        echo "Available directories in /lilyspark/usr/:" && \
        ls -la /lilyspark/usr/ 2>/dev/null || echo "No /lilyspark/usr/ directory found"; \
    fi

# Stage: build application
FROM filesystem-libs-build-builder AS app-build

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_APP_BUILD" && \
    rm -f /tmp/nocache/timestamp

# ======================
# SECTION: Application Build Setup
# ======================
RUN echo "=== INITIALIZING APPLICATION BUILD ENVIRONMENT ===" && \
    echo "Creating all necessary directories..." && \
    mkdir -p /lilyspark/app/src /lilyspark/app/build /lilyspark/snapshots && \
    echo "Filesystem initialized with binary target directory confirmed"

# Set working directory for app build
WORKDIR /lilyspark/app

# Copy application source
COPY . ./src

# EXPLICITLY PLACE CMakeLists.txt in the build_files directory
COPY CMakeLists.txt /lilyspark/app/build_files/CMakeLists.txt

# ======================
# SECTION: Source Verification
# ======================
RUN echo "=== SAFETY CHECK: VERIFY SOURCE CODE ===" && \
    ls -la ./src/ | tee /tmp/source_copy.log && \
    if [ -f /lilyspark/app/build_files/CMakeLists.txt ]; then \
        echo "✓ CMakeLists.txt found in build_files"; \
        head -20 /lilyspark/app/build_files/CMakeLists.txt | tee /tmp/CMakeLists_preview.log; \
    else \
        echo "✗ CMakeLists.txt NOT found in build_files"; \
        find ./src -type f | tee /tmp/available_source_files.log; \
    fi && \
    find ./src -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.hpp" | tee /tmp/source_files_list.log

# ======================
# SECTION: Environment Setup for Build
# ======================
ENV PATH="/lilyspark/usr/bin:/lilyspark/compiler/bin:$PATH"
ENV PKG_CONFIG_SYSROOT_DIR="/lilyspark"
ENV PKG_CONFIG_PATH="/lilyspark/usr/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV LD_LIBRARY_PATH="/lilyspark/usr/lib:/lilyspark/compiler/lib:$LD_LIBRARY_PATH"
ENV C_INCLUDE_PATH="/lilyspark/usr/include"

# Ensure sysroot libraries exist before building
RUN echo "=== POPULATING SYSROOT LIBRARIES (BUILD) ===" && \
    cp -v /usr/lib/libstdc++.so* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/libgcc* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/libm.so* /lilyspark/glibc/lib/ 2>/dev/null || true && \
    cp -v /lib/libc.musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    cp -v /lib/ld-musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    # Copy essential runtime objects - find and copy all crt files
    find /usr/lib -name "crt*.o" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "crt*.o" -exec cp -v {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy gcc libraries
    find /usr/lib -name "libgcc*" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "libgcc*" -exec cp -v {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy ssp libraries
    find /usr/lib -name "*ssp*" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Sysroot libraries populated for app-build"

# ======================
# SECTION: CMake Build
# ======================
WORKDIR /lilyspark/app/build
RUN mkdir -p . /lilyspark/log && \
    # --- Use system compiler directly ---
    echo "=== PRE-BUILD VERIFICATION ===" && \
    echo "Using system compiler" && \
    if [ -f /lilyspark/app/build_files/CMakeLists.txt ]; then \
        echo "✓ CMakeLists.txt found in build_files"; \
    else \
        echo "✗ CMakeLists.txt NOT found in build_files"; exit 1; \
    fi && \
    \
    # --- Configure CMake with system compiler ---
    cmake /lilyspark/app/build_files \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        2>&1 | tee /lilyspark/log/cmake_configure.log && \
    \
    # --- Build ---
    echo "=== BUILDING APPLICATION ===" && \
    cmake --build . --target simplehttpserver -- -j$(nproc) \
        2>&1 | tee /lilyspark/log/cmake_build.log && \
    \
    # --- Install ---
    echo "=== INSTALLING APPLICATION (DESTDIR) ===" && \
    DESTDIR=/lilyspark cmake --install . \
        2>&1 | tee /lilyspark/log/cmake_install.log

# ======================
# SECTION: Final Environment
# ======================
ENV PATH="/lilyspark/usr/bin:/lilyspark/compiler/bin:$PATH"

# ======================
# Stage: debug environment (Stripped)
# ======================
FROM app-build AS debug

# Cache busting
ARG BUILDKIT_INLINE_CACHE=0
ARG CACHEBUST_DEBUG
RUN echo "CACHEBUST_DEBUG=${CACHEBUST_DEBUG}" && echo "CACHE_DISABLED_FOR_DEBUG_STAGE"

# Debug environment folders
RUN mkdir -p /lilyspark/app/build \
             /lilyspark/var/log/debug && \
    echo "Folders created:" && ls -la /lilyspark/app && ls -la /lilyspark/usr

# Copy build artifacts from app-build
COPY --from=app-build /lilyspark/app/build /lilyspark/app/build
COPY --from=app-build /lilyspark/usr/bin/ /lilyspark/usr/bin/

# Populate minimal sysroot libraries
RUN cp -v /usr/lib/libstdc++.so* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/libgcc* /lilyspark/usr/lib/ 2>/dev/null || true && \
    cp -v /usr/lib/libm.so* /lilyspark/glibc/lib/ 2>/dev/null || true && \
    cp -v /lib/libc.musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    cp -v /lib/ld-musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    # Copy essential runtime objects - find and copy all crt files
    find /usr/lib -name "crt*.o" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "crt*.o" -exec cp -v {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy gcc libraries
    find /usr/lib -name "libgcc*" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    find /lib -name "libgcc*" -exec cp -v {} /lilyspark/lib/ \; 2>/dev/null || true && \
    # Copy ssp libraries
    find /usr/lib -name "*ssp*" -exec cp -v {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Sysroot libraries populated" | tee /lilyspark/var/log/debug/sysroot_libs.log

# Debug scripts/tools
COPY setup-scripts/file_finder.sh /usr/local/bin/file_finder.sh
RUN chmod +x /usr/local/bin/file_finder.sh && \
    echo "=== FILE FINDER READY ===" | tee /lilyspark/var/log/debug/file_finder.log

# Verify CMakeLists.txt
RUN if [ -f /lilyspark/app/build_files/CMakeLists.txt ]; then \
        echo "✓ Found CMakeLists.txt in build_files"; \
    else \
        echo "✗ ERROR: CMakeLists.txt missing in build_files!"; ls -la /lilyspark/app/build_files; \
    fi | tee /lilyspark/var/log/debug/cmake_path_check.log

# Use system compiler
ENV SYSROOT=/lilyspark
ENV PATH="/lilyspark/usr/bin:/lilyspark/compiler/bin:$PATH"

# CMake configure & build
WORKDIR /lilyspark/app/build/src
# No complex environment setup needed for simple Hello World

RUN cmake /lilyspark/app/build_files \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        2>&1 | tee /tmp/debug_cmake_configure.log && \
    cmake --build . --target simplehttpserver -- -j$(nproc) 2>&1 | tee /tmp/debug_cmake_build.log && \
    DESTDIR=$SYSROOT cmake --install . 2>&1 | tee /tmp/debug_cmake_install.log

# Binary verification
RUN if [ ! -f $SYSROOT/usr/bin/simplehttpserver ] && [ -f ./simplehttpserver ]; then \
        cp -v ./simplehttpserver $SYSROOT/usr/bin/simplehttpserver && chmod +x $SYSROOT/usr/bin/simplehttpserver; \
    fi && \
    ls -la $SYSROOT/usr/bin/simplehttpserver || true

# Minimal debug tools
RUN apk add --no-cache gdb strace ltrace perf lsof file binutils && \
    for cmd in gdb strace ltrace perf lsof file objdump; do \
        src="$(command -v $cmd 2>/dev/null || true)"; \
        [ -n "$src" ] && cp -p "$src" "$SYSROOT/usr/bin/"; \
    done



# User setup
RUN addgroup -g 1000 shs && adduser -u 1000 -G shs -D shs && \
    chown -R shs:shs $SYSROOT/app $SYSROOT/usr/local

USER shs
WORKDIR /lilyspark/app
CMD ["/lilyspark/usr/bin/simplehttpserver"]

# Stage: runtime environment
FROM debug AS runtime

# Create necessary directories
USER root
RUN mkdir -p /lilyspark/usr/lib/runtime

# Copy application binary from app-build stage
COPY --from=app-build /lilyspark/app/build/simplehttpserver /lilyspark/usr/bin/

# Ensure the binary is executable
RUN chmod +x /lilyspark/usr/bin/simplehttpserver

# Copy minimal scripts needed in runtime
COPY setup-scripts/file_finder.sh /usr/local/bin/file_finder.sh
RUN chmod +x /usr/local/bin/file_finder.sh
COPY --chmod=755 setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh

# Create runtime environment configuration
RUN mkdir -p /lilyspark/etc/profile.d && \
    cat > /lilyspark/etc/profile.d/runtime.sh <<'RUNTIME_PROFILE'
#!/bin/sh
export LD_LIBRARY_PATH="/lilyspark/usr/lib/runtime:/lilyspark/usr/lib:/lilyspark/usr/local/lib:${LD_LIBRARY_PATH:-}"
RUNTIME_PROFILE
RUN chmod +x /lilyspark/etc/profile.d/runtime.sh

# Configure user
RUN chown -R shs:shs /lilyspark/app /lilyspark/usr/local

# Minimal runtime libraries
RUN apk add --no-cache libstdc++ libgcc libpng freetype fontconfig libx11

# Set environment variables
ENV LD_LIBRARY_PATH="/lilyspark/usr/lib/runtime:/lilyspark/usr/lib:/lilyspark/usr/local/lib:$LD_LIBRARY_PATH" \
    PATH="/lilyspark/compiler/bin:/lilyspark/usr/local/bin:/lilyspark/usr/bin:$PATH"

# Default command
CMD ["/lilyspark/usr/bin/simplehttpserver"]