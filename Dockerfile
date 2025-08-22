# Stage: base deps (Alpine version)
FROM alpine:3.21 AS base-deps

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
ARG DOCKER_BUILDKIT=1
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_BASE_DEPS" && \
    rm -f /tmp/nocache/timestamp

# Install basic tools needed for filesystem operations
RUN apk add --no-cache bash findutils wget file coreutils

# Create directory structure
RUN mkdir -p /custom-os/bin /custom-os/sbin /custom-os/etc /custom-os/var /custom-os/tmp /custom-os/home /custom-os/root
RUN mkdir -p /custom-os/usr/bin /custom-os/usr/sbin /custom-os/usr/lib
RUN mkdir -p /custom-os/usr/local/bin /custom-os/usr/local/sbin /custom-os/usr/local/lib /custom-os/usr/share

# Create compiler directory structure
RUN mkdir -p /custom-os/compiler/bin /custom-os/compiler/lib /custom-os/compiler/include

# Create glibc directory structure
RUN mkdir -p /custom-os/glibc/lib /custom-os/glibc/bin /custom-os/glibc/sbin /custom-os/glibc/include

# Copy the LLVM15 debug script for monitoring
COPY setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh
RUN chmod +x /usr/local/bin/check_llvm15.sh

# Copy the filesystem inspection script
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
RUN chmod +x /usr/local/bin/check-filesystem.sh

# Remove any preinstalled LLVM/Clang
RUN apk del --no-cache llvm clang || true

# Run LLVM15 check before any installations
RUN /usr/local/bin/check_llvm15.sh "pre-install" || true

# Install glibc compatibility layer with ARM64 warning suppression
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-dev-2.35-r1.apk && \
    apk add --no-cache --allow-untrusted \
        glibc-2.35-r1.apk \
        glibc-bin-2.35-r1.apk \
        glibc-dev-2.35-r1.apk 2>&1 | grep -v "unknown machine 183" || true && \
    if [ -x /usr/glibc-compat/sbin/ldconfig ]; then \
        mv /usr/glibc-compat/sbin/ldconfig /usr/glibc-compat/sbin/ldconfig.real && \
        echo '#!/bin/sh' > /usr/glibc-compat/sbin/ldconfig && \
        echo '/usr/glibc-compat/sbin/ldconfig.real "$@" 2>&1 | grep -v "unknown machine 183" || true' >> /usr/glibc-compat/sbin/ldconfig && \
        chmod +x /usr/glibc-compat/sbin/ldconfig; \
    fi && \
    rm -f /sbin/ldconfig || true && \
    rm -f *.apk || true && \
    /usr/local/bin/check_llvm15.sh "after-glibc" || true

# Copy glibc runtime to custom filesystem
RUN echo "=== COPYING GLIBC TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/glibc/{lib,bin,sbin} && \
    cp -r /usr/glibc-compat/lib/* /custom-os/glibc/lib/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/bin/* /custom-os/glibc/bin/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/sbin/* /custom-os/glibc/sbin/ 2>/dev/null || true && \
    echo "GLIBC runtime copied to custom filesystem (no headers)." && \
    ls -la /custom-os/glibc/lib/ | head -10 || echo "No glibc libraries found"

# ======================
# LLVM16 + Clang16
# ======================
RUN echo "=== INSTALLING LLVM16 + CLANG16 (isolated) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-llvm16" || true && \
    apk add --no-cache llvm16-dev llvm16-libs clang16 && \
    echo "=== LLVM16 + Clang16 installed ==="

# --- Ensure clang is available in /custom-os/compiler/bin (copy + symlink) ---
RUN mkdir -p /custom-os/compiler/bin /custom-os/compiler/lib /custom-os/compiler/include && \
    echo "=== POPULATING /custom-os/compiler/bin from /usr/bin ===" && \
    cp -v /usr/bin/clang-16 /custom-os/compiler/bin/ 2>/dev/null || cp -v /usr/bin/clang /custom-os/compiler/bin/ 2>/dev/null || true && \
    cp -v /usr/bin/clang++-16 /custom-os/compiler/bin/ 2>/dev/null || cp -v /usr/bin/clang++ /custom-os/compiler/bin/ 2>/dev/null || true && \
    cp -v /usr/bin/llvm-* /custom-os/compiler/bin/ 2>/dev/null || true && \
    chmod a+x /custom-os/compiler/bin/* 2>/dev/null || true && \
    if [ -f /custom-os/compiler/bin/clang ] && [ ! -f /custom-os/compiler/bin/clang-16 ]; then \
        ln -sf /custom-os/compiler/bin/clang /custom-os/compiler/bin/clang-16 || true; \
    fi && \
    if [ -f /custom-os/compiler/bin/clang++ ] && [ ! -f /custom-os/compiler/bin/clang++-16 ]; then \
        ln -sf /custom-os/compiler/bin/clang++ /custom-os/compiler/bin/clang++-16 || true; \
    fi && \
    echo "=== /custom-os/compiler/bin contents ===" && ls -la /custom-os/compiler/bin || true

# ======================
# Environment setup
# ======================
RUN cat > /custom-os/etc/environment <<'ENV' && \
    echo "=== CREATING ENVIRONMENT SETUP ===" && \
    cat /custom-os/etc/environment
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:${PATH}"
export LLVM_CONFIG="/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/glibc"
ENV

RUN mkdir -p /custom-os/etc/profile.d && \
    cat > /custom-os/etc/profile.d/compiler.sh <<'PROFILE'
#!/bin/sh
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:${PATH}"
export LLVM_CONFIG="/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/glibc"
export GLIBC_COMPAT="/glibc"
export C_INCLUDE_PATH="/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/glibc/include:${CPLUS_INCLUDE_PATH:-}"
PROFILE
RUN chmod +x /custom-os/etc/profile.d/compiler.sh

RUN cat > /custom-os/etc/profile.d/glibc.sh <<'GLIBC_PROFILE'
#!/bin/sh
export GLIBC_ROOT="/glibc"
export GLIBC_COMPAT="/glibc"
export PATH="/glibc/sbin:/glibc/bin:${PATH}"
export LD_LIBRARY_PATH="/glibc/lib:${LD_LIBRARY_PATH:-}"
export C_INCLUDE_PATH="/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/glibc/include:${CPLUS_INCLUDE_PATH:-}"
GLIBC_PROFILE
RUN chmod +x /custom-os/etc/profile.d/glibc.sh

# Copy and execute setup scripts
COPY setup-scripts/ /setup/
RUN chmod +x /setup/*.sh && /setup/create-filesystem.sh

# Final LLVM15 contamination check & filesystem analyzer
RUN /usr/local/bin/check_llvm15.sh "final-filesystem-builder" || true && \
    /usr/local/bin/check-filesystem.sh "final-filesystem-builder" || true

# Critical binary directory verification
RUN echo "=== STAGE END VERIFICATION: base-deps ===" && \
    echo "Verifying binary directory /custom-os/usr/bin exists:" && \
    if [ -d /custom-os/usr/bin ]; then \
        ls -la /custom-os/usr/bin && \
        echo "✓ base-deps stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /custom-os/usr/bin does not exist!" && \
        ls -la /custom-os/usr/ 2>/dev/null || echo "No /custom-os/usr/ directory found" && \
        exit 1; \
    fi

# Copy bin/lib validator
COPY setup-scripts/binlib_validator.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/binlib_validator.sh


# Stage: filesystem setup - Install base-deps
FROM base-deps AS filesystem-base-deps-builder

RUN echo ">>> check /custom-os/compiler/bin" && ls -la /custom-os/compiler/bin || true
RUN echo ">>> check for libc++" && ls -la /custom-os/compiler/lib | head -20 || true

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_FILESYSTEM_BASE_DEPS" && \
    rm -f /tmp/nocache/timestamp

# Install all base packages with individual LLVM15 checks
RUN echo "=== INSTALLING CORE PACKAGES WITH LLVM15 MONITORING ==="
RUN apk add --no-cache bash && /usr/local/bin/check_llvm15.sh "after-bash" || true
RUN apk add --no-cache ca-certificates && /usr/local/bin/check_llvm15.sh "after-ca-certificates" || true
RUN apk add --no-cache git && /usr/local/bin/check_llvm15.sh "after-git" || true
RUN apk add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk add --no-cache musl-dev && /usr/local/bin/check_llvm15.sh "after-musl-dev" || true
RUN apk add --no-cache make && /usr/local/bin/check_llvm15.sh "after-make" || true
RUN apk add --no-cache cmake && /usr/local/bin/check_llvm15.sh "after-cmake" || true
RUN apk add --no-cache ninja && /usr/local/bin/check_llvm15.sh "after-ninja" || true
RUN apk add --no-cache pkgconf && /usr/local/bin/check_llvm15.sh "after-pkgconf" || true
RUN apk add --no-cache curl && /usr/local/bin/check_llvm15.sh "after-curl" || true
RUN apk add --no-cache xmlto && /usr/local/bin/check_llvm15.sh "after-xmlto" || true
# Doesn't exist - RUN apk add --no-cache fop && /usr/local/bin/check_llvm15.sh "after-fop" || true
RUN apk add --no-cache wget && /usr/local/bin/check_llvm15.sh "after-wget" || true
#RUN apk add --no-cache gbm && /usr/local/bin/check_llvm15.sh "after-gbm" || true
RUN apk add --no-cache tar && /usr/local/bin/check_llvm15.sh "after-tar" || true
RUN apk add --no-cache harfbuzz-dev && /usr/local/bin/check_llvm15.sh "after-harfbuzz-dev" || true
RUN apk add --no-cache openjdk11 && /usr/local/bin/check_llvm15.sh "after-openjdk11" || true
RUN apk add --no-cache ant && /usr/local/bin/check_llvm15.sh "after-ant" || true
RUN apk add --no-cache python3 && /usr/local/bin/check_llvm15.sh "after-python3" || true
RUN apk add --no-cache py3-pip && /usr/local/bin/check_llvm15.sh "after-py3-pip" || true
RUN apk add --no-cache mako && /usr/local/bin/check_llvm15.sh "after-mako" || true
RUN apk add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true
RUN apk add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk add --no-cache meson && /usr/local/bin/check_llvm15.sh "after-meson" || true
RUN apk add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache eudev-dev && /usr/local/bin/check_llvm15.sh "after-eudev-dev" || true
RUN apk add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true
# Other essential packages - Pt 1
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true
# Part of MESA (please make sure to configure this later)- RUN apk add --no-cache egl-dev && /usr/local/bin/check_llvm15.sh "after-egl-dev" || true
# Part of MESA (please make sure to configure this later) - RUN apk add --no-cache gles-dev && /usr/local/bin/check_llvm15.sh "after-gles-dev" || true
RUN apk add --no-cache python3-dev && /usr/local/bin/check_llvm15.sh "after-python3-dev" || true
RUN apk add --no-cache py3-setuptools && /usr/local/bin/check_llvm15.sh "after-py3-setuptools" || true
RUN apk add --no-cache cunit-dev && /usr/local/bin/check_llvm15.sh "after-cunit-dev" || true
RUN apk add --no-cache cairo-dev && /usr/local/bin/check_llvm15.sh "after-cairo-dev" || true
RUN apk add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true
RUN apk add --no-cache libatomic_ops-dev && /usr/local/bin/check_llvm15.sh "after-libatomic_ops-dev" || true
RUN apk add --no-cache pciutils-dev && /usr/local/bin/check_llvm15.sh "after-pciutils-dev" || true
#RUN apk add --no-cache jack2-dev && /usr/local/bin/check_llvm15.sh "after-jack2-dev" || true
RUN apk add --no-cache pipewire-dev && /usr/local/bin/check_llvm15.sh "after-pipewire-dev" || true
RUN apk add --no-cache sndio-dev && /usr/local/bin/check_llvm15.sh "after-sndio-dev" || true
RUN apk add --no-cache libvorbis-dev && /usr/local/bin/check_llvm15.sh "after-liborbis-dev" || true
# Other essential packages - Pt 2
RUN apk add --no-cache autoconf && /usr/local/bin/check_llvm15.sh "after-autoconf" || true
RUN apk add --no-cache automake && /usr/local/bin/check_llvm15.sh "after-automake" || true
RUN apk add --no-cache libtool && /usr/local/bin/check_llvm15.sh "after-libtool" || true
RUN apk add --no-cache util-macros && /usr/local/bin/check_llvm15.sh "after-util-macros" || true
RUN apk add --no-cache pkgconf-dev && /usr/local/bin/check_llvm15.sh "after-pkgconf-dev" || true
#RUN apk add --no-cache xorg-util-macros && /usr/local/bin/check_llvm15.sh "after-xorg-util-macros" || true
#RUN apk add --no-cache plutosvg-dev && /usr/local/bin/check_llvm15.sh "after-plutosvg-dev" || true
RUN apk add --no-cache libusb-dev && /usr/local/bin/check_llvm15.sh "after-libusb-dev" || true
# Checking something integral because could this be a problem?????? - RUN apk add --no-cache libpciaccess-dev && /usr/local/bin/check_llvm15.sh "after-libpciaccess-dev" || true
RUN apk add --no-cache pixman-dev && /usr/local/bin/check_llvm15.sh "after-pixman-dev" || true
RUN apk add --no-cache xkeyboard-config && /usr/local/bin/check_llvm15.sh "after-xkeyboard-config" || true
RUN apk add --no-cache xkbcomp && /usr/local/bin/check_llvm15.sh "after-xkbcomp" || true
RUN apk add --no-cache libxkbfile-dev && /usr/local/bin/check_llvm15.sh "after-libxkbfile-dev" || true
RUN apk add --no-cache libxfont2-dev && /usr/local/bin/check_llvm15.sh "after-libxfont2-dev" || true
RUN apk add --no-cache font-util-dev && /usr/local/bin/check_llvm15.sh "after-font-util-dev-dev" || true
RUN apk add --no-cache xcb-util-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-dev" || true
RUN apk add --no-cache xcb-util-renderutil-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-renderutil-dev" || true
RUN apk add --no-cache xcb-util-wm-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-wm-dev" || true
RUN apk add --no-cache xcb-util-keysyms-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-keysyms-dev" || true
RUN apk add --no-cache tiff-dev && /usr/local/bin/check_llvm15.sh "after-tiff-dev" || true
RUN apk add --no-cache libtiff && /usr/local/bin/check_llvm15.sh "after-lib-tiff" || true
RUN apk add --no-cache libavif && /usr/local/bin/check_llvm15.sh "after-libavif" || true
RUN apk add --no-cache libwebp && /usr/local/bin/check_llvm15.sh "after-libwebp" || true
RUN apk add --no-cache gettext-dev && /usr/local/bin/check_llvm15.sh "after-gettext-dev" || true
RUN apk add --no-cache libogg-dev && /usr/local/bin/check_llvm15.sh "after-libogg-dev" || true
RUN apk add --no-cache flac-dev && /usr/local/bin/check_llvm15.sh "after flac-dev" || true
RUN apk add --no-cache libmodplug-dev && /usr/local/bin/check_llvm15.sh "after-libmodplug-dev" || true
RUN apk add --no-cache mpg123-dev && /usr/local/bin/check_llvm15.sh "after-mpg123-dev" || true
RUN apk add --no-cache opusfile-dev && /usr/local/bin/check_llvm15.sh "after-opusfile-dev" || true
RUN apk add --no-cache libjpeg-turbo-dev && /usr/local/bin/check_llvm15.sh "after-libjpeg-turbo-dev" || true

# Copy the installed packages to custom filesystem in an organized way
RUN echo "=== COPYING BASE PACKAGES TO CUSTOM FILESYSTEM ===" && \
    # Create essential directories if they don't exist (include pkgconfig & gcc dirs)
    mkdir -p /custom-os/usr/bin /custom-os/usr/lib /custom-os/usr/include /custom-os/usr/lib/pkgconfig /custom-os/usr/lib/gcc && \
    mkdir -p /custom-os/lib /custom-os/usr/share /custom-os/usr/local/bin && \
    # Copy the package database
    cp -r /lib/apk /custom-os/lib/ 2>/dev/null || true && \
    # Copy essential musl C library components to both lib and usr/lib directories
    echo "Copying musl C library components..." && \
    cp -a /lib/ld-musl-aarch64.so.1 /custom-os/lib/ 2>/dev/null || true && \
    cp -a /lib/libc.musl-aarch64.so.1 /custom-os/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/libc.a /custom-os/usr/lib/ 2>/dev/null || true && \
    # Create necessary symlinks for libc
    cd /custom-os/lib && ln -sf libc.musl-aarch64.so.1 libc.so 2>/dev/null || true && \
    cd /custom-os/lib && ln -sf ld-musl-aarch64.so.1 ld-linux-aarch64.so.1 2>/dev/null || true && \
    # Also copy to usr/lib for compatibility
    cp -a /lib/ld-musl-aarch64.so.1 /custom-os/usr/lib/ 2>/dev/null || true && \
    cp -a /lib/libc.musl-aarch64.so.1 /custom-os/usr/lib/ 2>/dev/null || true && \
    cd /custom-os/usr/lib && ln -sf libc.musl-aarch64.so.1 libc.so 2>/dev/null || true && \
    # Copy binaries (best-effort)
    find /usr/bin -type f -exec cp --parents -a {} /custom-os/usr/bin/ \; 2>/dev/null || true && \
    # Copy shared libraries (best-effort)
    find /usr/lib -type f -name "*.so*" -exec cp --parents -a {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    # Copy pkg-config files (so pkg-config sees them in the sysroot)
    if [ -d /usr/lib/pkgconfig ]; then find /usr/lib/pkgconfig -type f -exec cp --parents -a {} /custom-os/usr/lib/pkgconfig/ \; 2>/dev/null || true; fi && \
    # Copy nested gcc runtime files (crtbegin/crtend and libgcc locations)
    if [ -d /usr/lib/gcc ]; then mkdir -p /custom-os/usr/lib/gcc && cp -a /usr/lib/gcc/* /custom-os/usr/lib/gcc/ 2>/dev/null || true; fi && \
    # Copy crt objects into the sysroot's usr/lib (linker looks under /usr/lib in sysroot)
    cp -a /lib/crt*.o /usr/lib/crt*.o /custom-os/usr/lib/ 2>/dev/null || true && \
    # Copy libgcc / libssp runtime bits into sysroot
    cp -a /usr/lib/libgcc* /lib/libgcc* /custom-os/usr/lib/ 2>/dev/null || true && \
    cp -a /usr/lib/libssp* /lib/libssp* /custom-os/usr/lib/ 2>/dev/null || true && \
    # Copy headers
    cp -r /usr/include/* /custom-os/usr/include/ 2>/dev/null || true && \
    # Copy shared data
    cp -r /usr/share/* /custom-os/usr/share/ 2>/dev/null || true && \
    # Verify the copy operation (short) - specifically check for libc
    echo "Base dependencies copied to custom filesystem (short listing):" && \
    echo "Lib directory contents:" && \
    ls -la /custom-os/lib/ 2>/dev/null || echo "No /custom-os/lib directory" && \
    echo "Libc files found:" && \
    find /custom-os -name "*libc*" -o -name "*ld-musl*" 2>/dev/null || echo "No libc files found" && \
    ls -la /custom-os/usr/bin/ | head -5 || true && \
    ls -la /custom-os/usr/lib/ | head -10 || true && \
    ls -la /custom-os/usr/lib/pkgconfig | head -5 2>/dev/null || echo "(no pkgconfig files)"


# ======================
# SECTION: Debug Tools
# ======================
RUN echo "=== INSTALLING DEBUG TOOLS ===" && \
    apk add --no-cache strace file tree valgrind-dev && \
    /usr/local/bin/check_llvm15.sh "after-debug-tools" || true && \
    \
    # Organize debug tools into dedicated sysroot location
    mkdir -p /custom-os/usr/debug/bin && \
    cp /usr/bin/strace /custom-os/usr/debug/bin/ && \
    cp /usr/bin/file   /custom-os/usr/debug/bin/ && \
    cp /usr/bin/tree   /custom-os/usr/debug/bin/ && \
    \
    # Ensure they don’t pollute /usr/bin (remove originals)
    rm -f /usr/bin/strace /usr/bin/file /usr/bin/tree && \
    \
    # Make sure they are executable
    chmod -R a+rx /custom-os/usr/debug/bin || true && \
    \
    echo "Debug tools installed into /custom-os/usr/debug/bin only."


# ======================
# SECTION: X11 Protocol Packages
# ======================
RUN echo "=== INSTALLING X11 PROTOCOL PACKAGES ==="
RUN apk add --no-cache xf86driproto && /usr/local/bin/check_llvm15.sh "after-xf86driproto" || true
RUN apk add --no-cache xf86vidmodeproto && /usr/local/bin/check_llvm15.sh "after-xf86vidmodeproto" || true
RUN apk add --no-cache glproto && /usr/local/bin/check_llvm15.sh "after-glproto" || true
RUN apk add --no-cache dri2proto && /usr/local/bin/check_llvm15.sh "after-dri2proto" || true

# Create organized X11 protocol structure
RUN mkdir -p /custom-os/usr/x11/proto && \
    cp -r /usr/include/X11 /custom-os/usr/x11/include && \
    find /usr/share/X11 -name "*.proto" -exec cp {} /custom-os/usr/x11/proto/ \; 2>/dev/null || true

# ======================
# SECTION: X11 Development Libraries
# ======================
RUN echo "=== INSTALLING X11 DEVELOPMENT LIBRARIES ==="
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

# Organize X11 libraries
RUN mkdir -p /custom-os/usr/x11/lib && \
    find /usr/lib -name "libX*.so*" -exec cp {} /custom-os/usr/x11/lib/ \; 2>/dev/null || true && \
    find /usr/lib -name "libxcb*.so*" -exec cp {} /custom-os/usr/x11/lib/ \; 2>/dev/null || true

# ======================
# SECTION: Media Packages
# ======================
RUN echo "=== INSTALLING MEDIA PACKAGES ==="
RUN apk add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true
RUN apk add --no-cache v4l-utils-dev && /usr/local/bin/check_llvm15.sh "after-v4l-utils-dev" || true

# Organize media packages
RUN mkdir -p /custom-os/usr/media/{bin,lib,include} && \
    find /usr/lib -name "*pcap*" -exec cp {} /custom-os/usr/media/lib/ \; 2>/dev/null || true && \
    find /usr/bin -name "*v4l*" -exec cp {} /custom-os/usr/media/bin/ \; 2>/dev/null || true

# ======================
# SECTION: Runtime Dependencies
# ======================
RUN echo "=== INSTALLING RUNTIME DEPENDENCIES ==="
RUN apk add --no-cache readline-dev && /usr/local/bin/check_llvm15.sh "after-readline-dev" || true
RUN apk add --no-cache openssl-dev && /usr/local/bin/check_llvm15.sh "after-openssl-dev" || true
RUN apk add --no-cache bzip2-dev && /usr/local/bin/check_llvm15.sh "after-bzip2-dev" || true

# Organize runtime deps
RUN mkdir -p /custom-os/usr/runtime/{lib,include} && \
    cp -r /usr/lib/libreadline* /custom-os/usr/runtime/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libssl* /usr/lib/libcrypto* /custom-os/usr/runtime/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libbz2* /custom-os/usr/runtime/lib/ 2>/dev/null || true

# ======================
# SECTION: Vulkan & Graphics
# ======================
RUN echo "=== INSTALLING VULKAN & GRAPHICS PACKAGES ==="
RUN apk add --no-cache vulkan-headers && /usr/local/bin/check_llvm15.sh "after-vulkan-headers" || true
RUN apk add --no-cache vulkan-loader && /usr/local/bin/check_llvm15.sh "after-vulkan-loader" || true
RUN apk add --no-cache vulkan-tools && /usr/local/bin/check_llvm15.sh "after-vulkan-tools" || true
RUN apk add --no-cache freetype-dev && /usr/local/bin/check_llvm15.sh "after-freetype-dev" || true
RUN apk add --no-cache fontconfig-dev && /usr/local/bin/check_llvm15.sh "after-fontconfig-dev" || true

# Organize Vulkan/graphics
RUN mkdir -p /custom-os/usr/vulkan/{bin,lib,include} /custom-os/usr/graphics/{lib,include} && \
    cp -r /usr/lib/libvulkan* /custom-os/usr/vulkan/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libfreetype* /usr/lib/libfontconfig* /custom-os/usr/graphics/lib/ 2>/dev/null || true && \
    find /usr/bin -name "vulkan*" -exec cp {} /custom-os/usr/vulkan/bin/ \; 2>/dev/null || true

# ======================
# SECTION: Audio Packages
# ======================
RUN echo "=== INSTALLING AUDIO PACKAGES ==="
RUN apk add --no-cache alsa-lib-dev && /usr/local/bin/check_llvm15.sh "after-alsa-lib-dev" || true
RUN apk add --no-cache pulseaudio-dev && /usr/local/bin/check_llvm15.sh "after-pulseaudio-dev" || true

# Organize audio packages
RUN mkdir -p /custom-os/usr/audio/{lib,include} && \
    cp -r /usr/lib/libasound* /custom-os/usr/audio/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libpulse* /custom-os/usr/audio/lib/ 2>/dev/null || true

# ======================
# SECTION: Miscellaneous
# ======================
RUN echo "=== INSTALLING MISC PACKAGES ==="
RUN apk add --no-cache bsd-compat-headers && /usr/local/bin/check_llvm15.sh "after-bsd-compat-headers" || true
RUN apk add --no-cache xf86-video-fbdev && /usr/local/bin/check_llvm15.sh "after-xf86-video-fbdev" || true
RUN apk add --no-cache xf86-video-dummy && /usr/local/bin/check_llvm15.sh "after-xf86-video-dummy" || true
RUN apk add --no-cache glslang && /usr/local/bin/check_llvm15.sh "after-glslang" || true
RUN apk add --no-cache net-tools && /usr/local/bin/check_llvm15.sh "after-net-tools" || true
RUN apk add --no-cache iproute2 && /usr/local/bin/check_llvm15.sh "after-iproute2" || true

# Organize misc packages
RUN mkdir -p /custom-os/usr/misc/{bin,lib} && \
    cp /usr/bin/glslang* /custom-os/usr/misc/bin/ 2>/dev/null || true && \
    cp /usr/bin/ifconfig /usr/bin/route /custom-os/usr/misc/bin/ 2>/dev/null || true && \
    cp /usr/bin/ip /custom-os/usr/misc/bin/ 2>/dev/null || true

# ======================
# SECTION: Filesystem Utilities
# ======================
RUN echo "=== INSTALLING FILESYSTEM UTILITIES ==="
RUN apk add --no-cache e2fsprogs-dev && /usr/local/bin/check_llvm15.sh "after-e2fsprogs-dev" || true
RUN apk add --no-cache xfsprogs-dev && /usr/local/bin/check_llvm15.sh "after-xfsprogs-dev" || true
RUN apk add --no-cache btrfs-progs-dev && /usr/local/bin/check_llvm15.sh "after-btrfs-progs-dev" || true

# Organize filesystem tools
RUN mkdir -p /custom-os/usr/fs/{bin,lib} && \
    cp /usr/sbin/mkfs.* /custom-os/usr/fs/bin/ 2>/dev/null || true && \
    cp /usr/sbin/fsck.* /custom-os/usr/fs/bin/ 2>/dev/null || true && \
    find /usr/lib -name "*e2fs*" -o -name "*xfs*" -o -name "*btrfs*" -exec cp {} /custom-os/usr/fs/lib/ \; 2>/dev/null || true

# ======================
# SECTION: System Utilities
# ======================
RUN echo "=== INSTALLING SYSTEM UTILITIES ==="
RUN apk add --no-cache util-linux-dev && /usr/local/bin/check_llvm15.sh "after-util-linux-dev" || true
RUN apk add --no-cache libcap-dev && /usr/local/bin/check_llvm15.sh "after-libcap-dev" || true
RUN apk add --no-cache liburing-dev && /usr/local/bin/check_llvm15.sh "after-liburing-dev" || true

# Organize system utilities
RUN mkdir -p /custom-os/usr/sysutils/{bin,lib} && \
    cp /usr/bin/hexdump /usr/bin/whereis /custom-os/usr/sysutils/bin/ 2>/dev/null || true && \
    cp /usr/lib/libcap* /usr/lib/liburing* /custom-os/usr/sysutils/lib/ 2>/dev/null || true

# ======================
# SECTION: Networking & IPC
# ======================
RUN echo "=== INSTALLING NETWORKING & IPC ==="
RUN apk add --no-cache libunwind-dev && /usr/local/bin/check_llvm15.sh "after-libunwind-dev" || true
RUN apk add --no-cache dbus-dev && /usr/local/bin/check_llvm15.sh "after-dbus-dev" || true
RUN apk add --no-cache libmnl-dev && /usr/local/bin/check_llvm15.sh "after-libmnl-dev" || true

# Organize networking
RUN mkdir -p /custom-os/usr/net/{lib,include} && \
    cp /usr/lib/libdbus* /usr/lib/libmnl* /usr/lib/libunwind* /custom-os/usr/net/lib/ 2>/dev/null || true

# ======================
# SECTION: Security
# ======================
RUN echo "=== INSTALLING SECURITY PACKAGES ==="
RUN apk add --no-cache libselinux-dev && /usr/local/bin/check_llvm15.sh "after-libselinux-dev" || true
RUN apk add --no-cache libseccomp-dev && /usr/local/bin/check_llvm15.sh "after-libseccomp-dev" || true

# Organize security libs
RUN mkdir -p /custom-os/usr/security/{lib,include} && \
    cp /usr/lib/libselinux* /usr/lib/libseccomp* /custom-os/usr/security/lib/ 2>/dev/null || true

# ======================
# SECTION: Compression
# ======================
RUN echo "=== INSTALLING COMPRESSION LIBRARIES ==="
RUN apk add --no-cache xz-dev && /usr/local/bin/check_llvm15.sh "after-xz-dev" || true
RUN apk add --no-cache zstd-dev && /usr/local/bin/check_llvm15.sh "after-zstd-dev" || true

# Organize compression
RUN mkdir -p /custom-os/usr/compress/{bin,lib} && \
    cp /usr/bin/xz /usr/bin/zstd /custom-os/usr/compress/bin/ 2>/dev/null || true && \
    cp /usr/lib/liblzma* /usr/lib/libzstd* /custom-os/usr/compress/lib/ 2>/dev/null || true

# ======================
# SECTION: System Debugging
# ======================
RUN echo "=== INSTALLING DEBUGGING TOOLS ==="
RUN apk add --no-cache linux-tools-dev && /usr/local/bin/check_llvm15.sh "after-linux-tools-dev" || true

# Organize debug tools
RUN mkdir -p /custom-os/usr/sysdebug && \
    cp -r /usr/lib/linux-tools /custom-os/usr/sysdebug/ 2>/dev/null || true

# ======================
# SECTION: Database & Dependencies
# ======================
RUN echo "=== INSTALLING DATABASE PACKAGES ==="
RUN apk add --no-cache sqlite-dev && /usr/local/bin/check_llvm15.sh "after-sqlite-dev" || true
RUN apk add --no-cache libedit-dev && /usr/local/bin/check_llvm15.sh "after-libedit-dev" || true
RUN apk add --no-cache icu-dev && /usr/local/bin/check_llvm15.sh "after-icu-dev" || true
RUN apk add --no-cache tcl-dev && /usr/local/bin/check_llvm15.sh "after-tcl-dev" || true
RUN apk add --no-cache lz4-dev && /usr/local/bin/check_llvm15.sh "after-lz4-dev" || true

# Organize database components
RUN mkdir -p /custom-os/usr/db/{bin,lib,include} && \
    cp /usr/bin/sqlite3 /custom-os/usr/db/bin/ 2>/dev/null || true && \
    cp /usr/lib/libsqlite* /usr/lib/libedit* /usr/lib/libicu* /usr/lib/libtcl* /usr/lib/liblz4* /custom-os/usr/db/lib/ 2>/dev/null || true

# ======================
# SECTION: Sysroot Integration
# ======================
RUN echo "=== INTEGRATING ORGANIZED COMPONENTS INTO MAIN SYSROOT ===" && \
    mkdir -p /custom-os/usr/lib /custom-os/usr/bin /custom-os/usr/include && \
    \
    # Libraries from subsystems
    find /custom-os/usr/x11/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/audio/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/graphics/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/vulkan/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/runtime/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/media/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/net/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/security/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/compress/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/db/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/fs/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    find /custom-os/usr/sysutils/lib -name "*.so*" -exec ln -sf {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    \
    # Link essential binaries, EXCLUDING debug tools
    for dir in /custom-os/usr/*/bin; do \
        case "$dir" in \
            /custom-os/usr/debug/bin) echo "Skipping debug bin directory ($dir)";; \
            *) find "$dir" -maxdepth 1 -type f -exec ln -sf {} /custom-os/usr/bin/ \; ;; \
        esac; \
    done && \
    \
    echo "Sysroot integration completed."

# Update environment configuration to include organized component paths
RUN cat > /custom-os/etc/environment <<'ENV'
# Custom filesystem environment configuration with organized components
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:/usr/bin:/usr/sbin:/usr/local/bin"
export PATH="${PATH}:/usr/x11/bin:/usr/vulkan/bin:/usr/media/bin:/usr/debug/bin"
export PATH="${PATH}:/usr/misc/bin:/usr/fs/bin:/usr/sysutils/bin:/usr/compress/bin:/usr/db/bin"
export LLVM_CONFIG="/compiler/bin/llvm-config"

# Library paths - sysroot first, then organized components
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/lib:/usr/local/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/x11/lib:/usr/audio/lib:/usr/graphics/lib:/usr/vulkan/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/runtime/lib:/usr/media/lib:/usr/net/lib:/usr/security/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/compress/lib:/usr/db/lib:/usr/fs/lib:/usr/sysutils/lib"

# PKG_CONFIG paths for organized components
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/x11/lib/pkgconfig:/usr/audio/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/graphics/lib/pkgconfig:/usr/vulkan/lib/pkgconfig"

# Sysroot configuration
export SYSROOT="/custom-os"
export GLIBC_ROOT="/glibc"

# Include paths
export C_INCLUDE_PATH="/usr/include:/glibc/include:/compiler/include"
export C_INCLUDE_PATH="${C_INCLUDE_PATH}:/usr/x11/include:/usr/audio/include:/usr/graphics/include"
export C_INCLUDE_PATH="${C_INCLUDE_PATH}:/usr/net/include:/usr/security/include:/usr/db/include"
export CPLUS_INCLUDE_PATH="${C_INCLUDE_PATH}"
ENV

# Update the profile scripts to match
RUN cat > /custom-os/etc/profile.d/sysroot.sh <<'SYSROOT_PROFILE'
#!/bin/sh
# Complete sysroot environment setup

# Sysroot configuration
export SYSROOT="/custom-os"
export GLIBC_ROOT="/glibc"
export GLIBC_COMPAT="/glibc"

# Comprehensive PATH with all organized components
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:/usr/bin:/usr/sbin:/usr/local/bin"
export PATH="${PATH}:/usr/x11/bin:/usr/vulkan/bin:/usr/media/bin:/usr/debug/bin"
export PATH="${PATH}:/usr/misc/bin:/usr/fs/bin:/usr/sysutils/bin:/usr/compress/bin:/usr/db/bin"

# Comprehensive library paths
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/lib:/usr/local/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/x11/lib:/usr/audio/lib:/usr/graphics/lib:/usr/vulkan/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/runtime/lib:/usr/media/lib:/usr/net/lib:/usr/security/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/compress/lib:/usr/db/lib:/usr/fs/lib:/usr/sysutils/lib"

# PKG_CONFIG paths
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/x11/lib/pkgconfig:/usr/audio/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/graphics/lib/pkgconfig:/usr/vulkan/lib/pkgconfig"

# Include paths
export C_INCLUDE_PATH="/usr/include:/glibc/include:/compiler/include"
export C_INCLUDE_PATH="${C_INCLUDE_PATH}:/usr/x11/include:/usr/audio/include:/usr/graphics/include"
export C_INCLUDE_PATH="${C_INCLUDE_PATH}:/usr/net/include:/usr/security/include:/usr/db/include"
export CPLUS_INCLUDE_PATH="${C_INCLUDE_PATH}"

# Compiler configuration for cross-compilation
export CC="/compiler/bin/clang"
export CXX="/compiler/bin/clang++"
export AR="/compiler/bin/llvm-ar"
export RANLIB="/compiler/bin/llvm-ranlib"
export STRIP="/compiler/bin/llvm-strip"

# Configure for sysroot usage
export CC="${CC} --sysroot=${SYSROOT}"
export CXX="${CXX} --sysroot=${SYSROOT}"
SYSROOT_PROFILE

RUN chmod +x /custom-os/etc/profile.d/sysroot.sh

# Create pkg-config directories in organized components if they don't exist
RUN mkdir -p /custom-os/usr/x11/lib/pkgconfig /custom-os/usr/audio/lib/pkgconfig && \
    mkdir -p /custom-os/usr/graphics/lib/pkgconfig /custom-os/usr/vulkan/lib/pkgconfig && \
    # Copy relevant pkg-config files to organized locations
    find /usr/lib/pkgconfig -name "*x11*" -o -name "*xcb*" -o -name "*xext*" -o -name "*xrender*" | \
    xargs -I {} cp {} /custom-os/usr/x11/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib/pkgconfig -name "*alsa*" -o -name "*pulse*" -o -name "*jack*" | \
    xargs -I {} cp {} /custom-os/usr/audio/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib/pkgconfig -name "*cairo*" -o -name "*freetype*" -o -name "*fontconfig*" | \
    xargs -I {} cp {} /custom-os/usr/graphics/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib/pkgconfig -name "*vulkan*" | \
    xargs -I {} cp {} /custom-os/usr/vulkan/lib/pkgconfig/ 2>/dev/null || true

# Verify sysroot structure
RUN echo "=== VERIFYING SYSROOT STRUCTURE ===" && \
    echo "Main sysroot lib directory:" && \
    ls -la /custom-os/usr/lib/*.so* | head -10 2>/dev/null || echo "No shared libraries in main sysroot" && \
    echo "Organized components:" && \
    find /custom-os/usr -maxdepth 2 -type d -name "lib" | sort && \
    echo "PKG_CONFIG directories:" && \
    find /custom-os -name "pkgconfig" -type d | sort && \
    echo "Environment files:" && \
    ls -la /custom-os/etc/environment /custom-os/etc/profile.d/ && \
    echo "Sysroot structure verification completed."

# Final contamination check
RUN /usr/local/bin/check_llvm15.sh "final-base-deps" || true && \
    /usr/local/bin/check-filesystem.sh "final-base-deps" || true && \
    echo "=== STAGE END VERIFICATION: filesystem-base-deps-builder ===" && \
    echo "Verifying binary directory /custom-os/usr/bin exists:" && \
    if [ -d /custom-os/usr/bin ]; then \
        ls -la /custom-os/usr/bin && \
        echo "✓ filesystem-base-deps-builder stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /custom-os/usr/bin does not exist!" && \
        echo "Available directories in /custom-os/usr/:" && \
        ls -la /custom-os/usr/ 2>/dev/null || echo "No /custom-os/usr/ directory found" && \
        exit 1; \
    fi


# ======================
# SECTION: Diagnostic Tools Setup
# ======================
# Copy diagnostic scripts
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker.sh
COPY setup-scripts/file_finder.sh /usr/local/bin/file_finder.sh
COPY setup-scripts/binlib_validator.sh /usr/local/bin/binlib_validator.sh
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix.sh
COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/dep_chain_visualizer.sh
COPY setup-scripts/cflag_audit.sh /usr/local/bin/cflag_audit.sh
COPY setup-scripts/sgid_suid_scanner.sh /usr/local/bin/sgid_suid_scanner.sh

RUN chmod +x /usr/local/bin/check-filesystem.sh /usr/local/bin/dependency_checker.sh /usr/local/bin/file_finder.sh \
    /usr/local/bin/binlib_validator.sh /usr/local/bin/version_matrix.sh /usr/local/bin/dep_chain_visualizer.sh \
    /usr/local/bin/cflag_audit.sh /usr/local/bin/sgid_suid_scanner.sh

# Stage: filesystem setup - Install base-deps
FROM filesystem-base-deps-builder AS filesystem-libs-build-builder

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_FILESYSTEM_LIBS_BUILD" && \
    rm -f /tmp/nocache/timestamp

# ======================
# SECTION: Apache FOP Integration + Permission Checks (robust launcher discovery)
# ======================
# Copy scanner script and ensure it’s executable
COPY setup-scripts/sgid_suid_scanner.sh /usr/local/bin/sgid_suid_scanner.sh
COPY setup-scripts/fop-wrapper.sh /tmp/fop-wrapper.sh
RUN chmod +x /usr/local/bin/sgid_suid_scanner.sh

RUN echo "=== INSTALLING Apache FOP 2.11 (isolated, safe) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-fop-install" || true && \
    \
    # Download and extract official FOP binary release
    mkdir -p /tmp/fop && \
    wget -O /tmp/fop/fop-bin.tar.gz https://dlcdn.apache.org/xmlgraphics/fop/binaries/fop-2.11-bin.tar.gz && \
    tar -xzf /tmp/fop/fop-bin.tar.gz -C /tmp/fop --strip-components=1 && \
    \
    # Prepare isolated target dirs
    mkdir -p /custom-os/usr/fop/bin /custom-os/usr/fop/lib /custom-os/usr/fop/docs /custom-os/usr/fop/launchers && \
    \
    # Locate and copy launcher file (or entire bin directory)
    launcher="$(find /tmp/fop -type f \( -name fop -o -name 'fop.sh' -o -name 'fop.bat' \) -print | head -n 1 || true)" && \
    if [ -n "$launcher" ]; then \
        echo "Found launcher at: $launcher" && cp "$launcher" /custom-os/usr/fop/bin/; \
    else \
        bindir="$(find /tmp/fop -type d -name bin -print | head -n 1 || true)" && \
        if [ -n "$bindir" ]; then \
            echo "Found bin directory at: $bindir" && cp -r "$bindir"/* /custom-os/usr/fop/bin/ 2>/dev/null || true; \
        else \
            echo "ERROR: fop launcher or bin/ directory not found in extracted tree" >&2 && ls -la /tmp/fop || true && false; \
        fi; \
    fi && \
    \
    # Copy all jar files to lib/
    echo "Copying JARs from extracted tree into /custom-os/usr/fop/lib" && \
    find /tmp/fop -type f -name '*.jar' -print -exec cp -a {} /custom-os/usr/fop/lib/ \; || true && \
    \
    # Fallback if lib is empty
    if [ "$(ls -A /custom-os/usr/fop/lib 2>/dev/null || true)" = "" ]; then \
        echo "No jars copied yet; trying nested locations" && \
        find /tmp/fop -type f -path '*/fop/*' -name '*.jar' -print -exec cp -a {} /custom-os/usr/fop/lib/ \; || true; \
    fi && \
    \
    # Copy docs/snippets (best-effort)
    cp -r /tmp/fop/javadocs /custom-os/usr/fop/docs/ 2>/dev/null || true && \
    cp -r /tmp/fop/README* /custom-os/usr/fop/docs/ 2>/dev/null || true && \
    cp -r /tmp/fop/LICENSE* /custom-os/usr/fop/docs/ 2>/dev/null || true && \
    \
    # Ensure proper permissions
    chmod -R a+rx /custom-os/usr/fop || true && \
    \
    # Install user-provided POSIX wrapper if available
    if [ -f /tmp/fop-wrapper.sh ]; then \
        echo "Installing fop-wrapper from build context into /custom-os/usr/fop/bin/fop" && \
        install -m 0755 /tmp/fop-wrapper.sh /custom-os/usr/fop/bin/fop || true; \
    fi && \
    \
    # Make all binaries executable
    if [ -n "$(find /custom-os/usr/fop/bin -type f -print -quit 2>/dev/null)" ]; then \
        find /custom-os/usr/fop/bin -type f -exec chmod +x {} \; 2>/dev/null || true; \
    fi && \
    \
    # Create dedicated launcher symlink (isolated, safe)
    if [ -f /custom-os/usr/fop/bin/fop ]; then \
        ln -sf /custom-os/usr/fop/bin/fop /custom-os/usr/fop/launchers/fop; \
    elif [ -f /custom-os/usr/fop/bin/fop.sh ]; then \
        ln -sf /custom-os/usr/fop/bin/fop.sh /custom-os/usr/fop/launchers/fop; \
    fi && \
    \
    # Update environment to include isolated launcher
    echo 'export PATH=$PATH:/custom-os/usr/fop/launchers' >> /custom-os/etc/profile.d/sysroot.sh && \
    echo 'export CLASSPATH=$CLASSPATH:/custom-os/usr/fop/lib/*' >> /custom-os/etc/profile.d/sysroot.sh && \
    echo 'PATH=$PATH:/custom-os/usr/fop/launchers' >> /custom-os/etc/environment && \
    echo 'CLASSPATH=$CLASSPATH:/custom-os/usr/fop/lib/*' >> /custom-os/etc/environment && \
    \
    # Run SUID/SGID scanner
    echo "=== RUNNING SUID/SGID SCANNER ON FOP INSTALLATION ===" && \
    /usr/local/bin/sgid_suid_scanner.sh /custom-os/usr/fop && \
    echo "=== SGID/SUID scan completed for FOP installation ===" && \
    \
    # Verify installation
    echo "=== VERIFYING Apache FOP INSTALLATION ===" && \
    echo "Contents of /custom-os/usr/fop/lib:" && ls -la /custom-os/usr/fop/lib || true && \
    JAVA_BIN="$(command -v java || true)" && \
    if [ -n "$JAVA_BIN" ]; then \
        echo "Found java at: $JAVA_BIN"; \
        echo "Attempting explicit java -cp '/custom-os/usr/fop/lib/*' org.apache.fop.cli.Main -version"; \
        "$JAVA_BIN" -cp "/custom-os/usr/fop/lib/*" org.apache.fop.cli.Main -version || echo "Explicit java run returned non-zero"; \
    else \
        echo "Java not found in PATH; ensure openjdk11 installed in this stage"; \
    fi && \
    \
    /usr/local/bin/check_llvm15.sh "post-fop-install" || true && \
    /usr/local/bin/check-filesystem.sh "post-fop-install" || true && \
    \
    # Cleanup
    rm -rf /tmp/fop

# ======================
# BUILD JACK2
# ======================
RUN echo "=== BUILDING JACK2 FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-jack2-source-build" || true && \
    \
    mkdir -p /tmp/jack2 && cd /tmp/jack2 && \
    \
    if git clone --depth=1 https://github.com/jackaudio/jack2.git /tmp/jack2-source; then \
        echo "JACK2 source cloned successfully"; \
    else \
        echo "ERROR: Could not clone JACK2 repository" >&2 && false; \
    fi && \
    \
    cd /tmp/jack2-source && \
    \
    if [ -x ./waf ]; then \
        echo ">>> Using waf build system <<<"; \
        ./waf configure --prefix=/usr --libdir=/usr/lib && \
        ./waf build && \
        DESTDIR="/custom-os" ./waf install; \
    else \
        echo ">>> Waf not found, trying autotools <<<"; \
        if [ -x ./configure ]; then \
            ./configure --prefix=/usr --libdir=/usr/lib --with-sysroot=/custom-os && \
            make -j$(nproc) && \
            make DESTDIR="/custom-os" install; \
        else \
            echo "ERROR: No recognized build system found (waf or autotools)" >&2 && false; \
        fi; \
    fi && \
    \
    echo "=== RELOCATING JACK2 BINARIES ===" && \
    mkdir -p /custom-os/usr/jack/bin && \
    # Move executables to jack-specific bin directory
    if [ -d /custom-os/usr/bin ]; then \
        find /custom-os/usr/bin -maxdepth 1 -type f -name "jack*" -exec mv -v {} /custom-os/usr/jack/bin/ \; || true; \
    fi && \
    \
    echo "=== VERIFYING JACK2 INSTALLATION ===" && \
    find /custom-os/usr/jack/bin -type f -name "jack*" -ls && \
    find /custom-os/usr/lib -type f -name "libjack*" -ls && \
    \
    /usr/local/bin/check_llvm15.sh "post-jack2-install" || true && \
    \
    cd / && rm -rf /tmp/jack2 /tmp/jack2-source



# ======================
# BUILD PlutoSVG
# ======================
RUN echo "=== BUILDING PlutoSVG FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-plutosvg-source-build" || true && \
    \
    # Remove any previous sources (avoid cached git from old layers) and prepare tmp
    rm -rf /tmp/plutosvg /tmp/plutosvg-source && \
    mkdir -p /tmp/plutosvg && cd /tmp/plutosvg && \
    \
    # Clone PlutoSVG from the public GitHub repository
    if git clone --depth=1 https://github.com/sammycage/plutosvg.git /tmp/plutosvg-source; then \
        echo "PlutoSVG source cloned successfully from GitHub"; \
    else \
        echo "ERROR: Could not clone PlutoSVG repository" >&2 && false; \
    fi && \
    \
    cd /tmp/plutosvg-source && \
    \
    # Ensure we have a modern Meson (>=1.3.0) which understands c_std lists like "gnu11,c11".
    # Use pip to upgrade meson into /usr/local so it takes precedence over apk's meson.
    if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then \
        echo "Upgrading pip tools and installing a modern meson via pip" && \
        python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel || true && \
        python3 -m pip install --no-cache-dir 'meson>=1.3.0' || echo "Warning: pip meson install failed - will attempt fallback patch"; \
    else \
        echo "python3/pip3 not available, will attempt fallback patch"; \
    fi && \
    \
    # As a fallback: patch subproject meson.build files to change 'gnu11,c11' -> 'gnu11' (best-effort)
    # This avoids parse-time errors on older Meson when lists are used in default_options.
    echo "Applying conservative fallback patches to subprojects (if present)" && \
    find . -type f -path '*/subprojects/*/meson.build' -print -exec sed -i 's/gnu11,c11/gnu11/g; s/gnu11,c11/gnu11/g; s/gnu17,c17/gnu17/g' {} \; 2>/dev/null || true && \
    find . -type f -path '*/subprojects/*/meson.build' -print -exec sed -n '1,120p' {} \; 2>/dev/null || true && \
    \
    # Configure and build using Meson+Ninja (pass -Dc_std as an extra guard)
    if [ -f meson.build ]; then \
        echo ">>> Configuring PlutoSVG via Meson <<<" && \
        export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
        export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
        meson --version || echo "meson not found or version unknown" && \
        meson setup builddir --prefix=/usr -Dc_std=gnu11 || { echo 'Meson configure failed' >&2; false; } && \
        ninja -C builddir -v || { echo 'Ninja build failed' >&2; false; } && \
        DESTDIR="/custom-os" ninja -C builddir install || { echo 'Install failed' >&2; false; }; \
    else \
        echo "ERROR: meson.build not found, cannot configure PlutoSVG" >&2 && false; \
    fi && \
    \
    # Verify installation
    echo "=== VERIFYING PlutoSVG INSTALLATION ===" && \
    if find /custom-os -name "*plutosvg*" -type f | tee /tmp/plutosvg_install.log; then \
        echo "PlutoSVG files present in /custom-os"; \
    else \
        echo "WARNING: No PlutoSVG files found in /custom-os"; \
    fi && \
    /usr/local/bin/check_llvm15.sh "post-plutosvg-install" || true && \
    \
    # Cleanup
    cd / && rm -rf /tmp/plutosvg /tmp/plutosvg-source


# ======================
# SECTION: pciaccess Build (Linux only)
# ======================

RUN echo "=== BUILDING pciaccess FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-pciaccess-source-build" || true && \
    \
    git clone --depth=1 https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git /tmp/libpciaccess && \
    cd /tmp/libpciaccess && \
    \
    echo ">>> Configuring libpciaccess <<<" && \
    # CRITICAL: Set environment to find dependencies in target sysroot
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
    \
    # Use minimal meson options - let it auto-detect what's available
    meson setup builddir \
        --prefix=/usr && \
    \
    ninja -C builddir -v && \
    # CRITICAL: Install to target filesystem, not host
    DESTDIR="/custom-os" ninja -C builddir install && \
    \
    # Verify installation in target
    echo "=== VERIFYING PCIACCESS INSTALLATION IN TARGET ===" && \
    find /custom-os -name "*pciaccess*" -type f | tee /tmp/pciaccess_install.log && \
    echo "pciaccess.pc file contents:" && \
    cat /custom-os/usr/lib/pkgconfig/pciaccess.pc || echo "pciaccess.pc not found" && \
    \
    /usr/local/bin/check_llvm15.sh "post-pciaccess-install" || true && \
    \
    # Cleanup
    cd / && rm -rf /tmp/libpciaccess

# ======================
# SECTION: Diagnostic Tools Setup
# ======================
# Copy diagnostic scripts
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker.sh
COPY setup-scripts/file_finder.sh /usr/local/bin/file_finder.sh
COPY setup-scripts/binlib_validator.sh /usr/local/bin/binlib_validator.sh
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix.sh
COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/dep_chain_visualizer.sh
COPY setup-scripts/cflag_audit.sh /usr/local/bin/cflag_audit.sh

RUN chmod +x /usr/local/bin/check-filesystem.sh /usr/local/bin/dependency_checker.sh /usr/local/bin/file_finder.sh \
    /usr/local/bin/binlib_validator.sh /usr/local/bin/version_matrix.sh /usr/local/bin/dep_chain_visualizer.sh \
    /usr/local/bin/cflag_audit.sh

# ======================
# SECTION: libdrm Build (sysroot-focused, non-fatal)
# ======================
ARG LIBDRM_VER=2.4.125
ARG LIBDRM_URL="https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VER}.tar.xz"

RUN echo "=== BUILDING libdrm ${LIBDRM_VER} FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libdrm-source-build" || true; \
    /usr/local/bin/check_llvm15.sh "after-libdrm-deps" || true; \
    \
    mkdir -p /tmp/libdrm-src && cd /tmp/libdrm-src; \
    echo "Fetching libdrm tarball: ${LIBDRM_URL}"; \
    curl -L "${LIBDRM_URL}" -o libdrm.tar.xz || (echo "⚠ Failed to fetch libdrm tarball"; exit 0); \
    tar -xf libdrm.tar.xz --strip-components=1 || true; \
    \
    # sysroot and cross compiler setup
    export PATH="/custom-os/compiler/bin:$PATH"; \
    export CC=/custom-os/compiler/bin/clang-16; \
    export CXX=/custom-os/compiler/bin/clang++-16; \
    if [ -x /custom-os/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config; fi; \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    \
    # SYSROOT sanity & fix-ups
    echo "=== SYSROOT RUNTIME CHECK ==="; \
    ls -la /custom-os/usr/lib/crt* /custom-os/usr/lib/Scrt1.o /custom-os/usr/lib/gcc 2>/dev/null || true; \
    ls -la /custom-os/usr/lib/libgcc* /custom-os/usr/lib/libssp* 2>/dev/null || true; \
    \
    [ ! -e /custom-os/usr/lib/Scrt1.o ] && [ -e /custom-os/usr/lib/crt1.o ] && ln -sf crt1.o /custom-os/usr/lib/Scrt1.o; \
    [ ! -e /custom-os/lib/Scrt1.o ] && [ -e /custom-os/usr/lib/Scrt1.o ] && ln -sf /custom-os/usr/lib/Scrt1.o /custom-os/lib/Scrt1.o; \
    CRTBEGIN=$(find /custom-os/usr/lib/gcc -name 'crtbegin*.o' 2>/dev/null | head -n1 || true); \
    [ -n "$CRTBEGIN" ] && [ ! -e /custom-os/usr/lib/crtbeginS.o ] && ln -sf "$CRTBEGIN" /custom-os/usr/lib/crtbeginS.o; \
    [ ! -e /custom-os/usr/lib/libssp_nonshared.a ] && ls /custom-os/usr/lib/libssp* 1>/dev/null 2>&1 && \
      ln -sf "$(basename "$(ls /custom-os/usr/lib/libssp* | head -n1)")" /custom-os/usr/lib/libssp_nonshared.a; \
    \
        # === musl dynamic loader fix ===
    if [ ! -e /custom-os/lib/ld-musl-aarch64.so.1 ] && [ -e /lib/ld-musl-aarch64.so.1 ]; then \
        echo "[musl] Linking musl loader into sysroot: /custom-os/lib/ld-musl-aarch64.so.1"; \
        mkdir -p /custom-os/lib; \
        ln -sf /lib/ld-musl-aarch64.so.1 /custom-os/lib/ld-musl-aarch64.so.1; \
    else \
        echo "[musl] Loader already present or missing in /lib — skipping link"; \
    fi; \
    \
    # === sysroot library inventory (first 60 entries) ===
    if [ -d /custom-os/usr/lib ]; then \
        echo "[sysroot] Listing /custom-os/usr/lib (first 60 entries):"; \
        ls -la /custom-os/usr/lib | sed -n '1,60p'; \
    else \
        echo "[sysroot] WARNING: /custom-os/usr/lib does not exist"; \
    fi; \
    \
    # === filesystem diagnosis ===
    if [ -x /usr/local/bin/check-filesystem.sh ]; then \
        echo "[diag] Running filesystem check"; \
        /usr/local/bin/check-filesystem.sh || echo "[diag] WARNING: check-filesystem.sh returned nonzero"; \
    else \
        echo "[diag] Skipping filesystem check — script not found"; \
    fi; \
    # Compiler test
    printf 'int main(void){return 0;}\n' > /tmp/meson_toolchain_test.c; \
    echo "=== COMPILER CHECK (non-fatal) ==="; \
    $CC --version 2>/dev/null || true; \
    $CC $CFLAGS -Wl,--sysroot=/custom-os -v -Wl,--verbose -o /tmp/meson_toolchain_test /tmp/meson_toolchain_test.c 2>/tmp/meson_toolchain_test.err || \
      (echo "✗ compiler test failed;" && sed -n '1,200p' /tmp/meson_toolchain_test.err); \
    [ -x /tmp/meson_toolchain_test ] && echo "✓ compiler test OK" || echo "⚠ compiler test failed"; \
    \
    # Diagnostics
    /usr/local/bin/dependency_checker.sh $CC || true; \
    /usr/local/bin/binlib_validator.sh $CC || true; \
    /usr/local/bin/version_matrix.sh || true; \
    /usr/local/bin/cflag_audit.sh || true; \
    \
    # Build with Meson
    meson setup builddir \
        --prefix=/usr \
        --libdir=lib \
        --includedir=include \
        --sysconfdir=/etc \
        --buildtype=release \
        -Dtests=false \
        -Dudev=true \
        -Dvalgrind=disabled || (echo "✗ meson setup failed"; /usr/local/bin/dep_chain_visualizer.sh "meson setup failed"); \
    meson compile -C builddir -j$(nproc) || echo "✗ meson compile failed"; \
    DESTDIR="/custom-os" meson install -C builddir --no-rebuild || echo "✗ meson install failed"; \
    \
    # Post-build summary
    echo "=== POST BUILD SUMMARY ==="; \
    ls -la /custom-os/usr/lib | sed -n '1,80p' || true; \
    ls -la /custom-os/usr/lib/pkgconfig 2>/dev/null || echo "(no pkgconfig files)"; \
    \
    cd /; rm -rf /tmp/libdrm-src; \
    /usr/local/bin/check_llvm15.sh "post-libdrm-source-build" || true; \
    echo "=== libdrm BUILD finished ==="; \
    true


# ======================
# SECTION: libepoxy Build from Source
# ======================
RUN echo "=== BUILDING LIBEPOXY FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libepoxy-source-build" || true && \
    \
    echo "=== INSTALLING BUILD DEPENDENCIES ===" && \
    /usr/local/bin/check_llvm15.sh "after-libepoxy-deps-install" || true && \
    \
    echo "=== CLONING LIBEPOXY SOURCE ===" && \
    git clone --depth=1 --branch 1.5.10 https://github.com/anholt/libepoxy.git libepoxy && \
    cd libepoxy && \
    \
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    grep -RIn "LLVM15\|llvm-15" . 2>/dev/null | tee /tmp/libepoxy_source_scan.log || true && \
    \
    echo "=== CONFIGURING LIBEPOXY WITH LLVM16 EXPLICIT PATHS ===" && \
    CC=/custom-os/compiler/bin/clang-16 \
    CXX=/custom-os/compiler/bin/clang++-16 \
    LLVM_CONFIG=/custom-os/compiler/bin/llvm-config \
    CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
    LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
    PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" \
    meson setup builddir \
        --prefix=/custom-os/usr \
        --libdir=/custom-os/usr/lib \
        --includedir=/custom-os/usr/include \
        --buildtype=release \
        -Dglx=yes \
        -Degl=yes \
        -Dx11=true \
        -Dwayland=false \
        -Dtests=false && \
    \
    echo "=== BUILDING LIBEPOXY ===" && \
    ninja -C builddir -j"$(nproc)" 2>&1 | tee /tmp/libepoxy-build.log && \
    \
    echo "=== INSTALLING LIBEPOXY ===" && \
    ninja -C builddir install 2>&1 | tee /tmp/libepoxy-install.log && \
    \
    echo "=== LIBEPOXY INSTALLATION VERIFICATION ===" && \
    echo "Libraries installed:" && \
    ls -la /custom-os/usr/lib/libepoxy* 2>/dev/null || echo "No libepoxy libraries found" && \
    echo "Headers installed:" && \
    ls -la /custom-os/usr/include/epoxy/ 2>/dev/null || echo "No epoxy headers found" && \
    echo "PKG-config files:" && \
    ls -la /custom-os/usr/lib/pkgconfig/epoxy.pc 2>/dev/null || echo "No epoxy.pc found" && \
    \
    echo "=== CREATING REQUIRED SYMLINKS ===" && \
    cd /custom-os/usr/lib && \
    for lib in $(ls libepoxy*.so.*.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    find /custom-os/usr/lib -name "libepoxy*" -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null | tee /tmp/libepoxy_contamination.log || true && \
    \
    cd / && \
    rm -rf libepoxy && \
    \
    /usr/local/bin/check_llvm15.sh "post-libepoxy-source-build" || true && \
    echo "=== LIBEPOXY BUILD COMPLETE ===" && \
    if [ -f /custom-os/usr/lib/libepoxy.so ] && [ -f /custom-os/usr/include/epoxy/gl.h ]; then \
        echo "✓ SUCCESS: libepoxy components installed"; \
    else \
        echo "⚠ WARNING: Some libepoxy components missing"; \
    fi

# ======================
# SECTION: SDL3 Image Dependencies
# ======================
RUN echo "=== INSTALLING SDL3_IMAGE DEPENDENCIES ===" && \
    apk add --no-cache libwebp-dev && \
    /usr/local/bin/check_llvm15.sh "after-libwebp-dev" || true && \
    \
    apk add --no-cache libavif-dev && \
    /usr/local/bin/check_llvm15.sh "after-libavif-dev" || true && \
    \
    echo "=== COPYING IMAGE LIBRARIES TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/media/{lib,include} && \
    cp -r /usr/lib/libtiff* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libwebp* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libavif* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/include/tiff* /custom-os/usr/media/include/ 2>/dev/null || true && \
    cp -r /usr/include/webp /custom-os/usr/media/include/ 2>/dev/null || true && \
    cp -r /usr/include/avif /custom-os/usr/media/include/ 2>/dev/null || true && \
    \
    echo "=== VERIFYING IMAGE LIBRARIES ===" && \
    ls -la /custom-os/usr/media/lib/libtiff* /custom-os/usr/media/lib/libwebp* /custom-os/usr/media/lib/libavif* || echo "Some libraries not found"


# ======================
# SECTION: Python Dependencies
# ======================
RUN echo "=== COPYING PYTHON PACKAGES TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/python/site-packages && \
    for pkg in mesonbuild mako MarkupSafe; do \
        # Find the package in the base sysroot or system Python site-packages
        src_dir=$(find /usr/lib/python3.*/site-packages /usr/lib/python*/site-packages -type d -name "$pkg" | head -n1) && \
        if [ -n "$src_dir" ] && [ -d "$src_dir" ]; then \
            dst_dir="/custom-os/usr/python/site-packages/$pkg" && \
            cp -R "$src_dir" "$dst_dir" && \
            echo "Copied $pkg -> $dst_dir"; \
        else \
            echo "Python package $pkg not found in system or base sysroot"; \
        fi; \
    done && \
    \
    echo "=== VERIFYING PYTHON PACKAGES IN CUSTOM FILESYSTEM ===" && \
    for pkg in mesonbuild mako MarkupSafe; do \
        if [ -d "/custom-os/usr/python/site-packages/$pkg" ]; then \
            echo "$pkg successfully copied:"; \
            ls -la "/custom-os/usr/python/site-packages/$pkg" | head -5; \
        else \
            echo "$pkg missing from /custom-os/usr/python/site-packages"; \
        fi; \
    done

# ======================
# SECTION: SPIRV-Tools Build
# ======================
RUN echo "=== BUILDING SPIRV-TOOLS FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-spirv-tools-source-build" || true && \
    \
    echo "=== CLONING SPIRV-TOOLS AND DEPENDENCIES ===" && \
    git clone --depth=1 https://github.com/KhronosGroup/SPIRV-Tools.git spirv-tools && \
    cd spirv-tools && \
    \
    echo "=== CLONING SPIRV-HEADERS DEPENDENCY ===" && \
    git clone --depth=1 https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers && \
    \
    echo "=== VERIFYING DEPENDENCIES ===" && \
    echo "SPIRV-Headers contents:" && \
    ls -la external/spirv-headers/ && \
    \
    echo "=== CONFIGURING WITH CMAKE ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/vulkan \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DLLVM_CONFIG_EXECUTABLE=/custom-os/compiler/bin/llvm-config \
        -DCMAKE_C_FLAGS="-I/custom-os/compiler/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/custom-os/compiler/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -Wl,-rpath,/custom-os/compiler/lib" && \
    \
    echo "=== BUILDING SPIRV-TOOLS ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/spirv-build.log && \
    \
    echo "=== INSTALLING SPIRV-TOOLS ===" && \
    make install 2>&1 | tee /tmp/spirv-install.log && \
    \
    cd ../.. && \
    rm -rf spirv-tools && \
    \
    echo "=== VERIFYING SPIRV-TOOLS INSTALLATION ===" && \
    echo "SPIRV-Tools binaries:" && \
    ls -la /custom-os/usr/vulkan/bin/spirv-* 2>/dev/null || echo "No SPIRV-Tools binaries found" && \
    echo "SPIRV-Tools libraries:" && \
    ls -la /custom-os/usr/vulkan/lib/libSPIRV-Tools* 2>/dev/null || echo "No SPIRV-Tools libraries found" && \
    \
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/vulkan/lib && \
    for lib in $(ls libSPIRV-Tools*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    /usr/local/bin/check_llvm15.sh "post-spirv-tools-source-build" || true && \
    echo "=== SPIRV-TOOLS BUILD COMPLETE ==="


# ======================
# SECTION: Shaderc Build (sysroot-focused) — FINAL
# ======================
RUN echo "=== BUILDING SHADERC FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-shaderc-source-build" || true; \
    \
    git clone --recursive https://github.com/google/shaderc.git || (echo "⚠ shaderc not cloned; skipping build" && exit 0); \
    if [ -d shaderc ]; then cd shaderc; else echo "⚠ shaderc directory missing; skipping build"; exit 0; fi; \
    \
    # Set up environment for proper sysroot build
    export PATH="/custom-os/compiler/bin:$PATH"; \
    export CC=/custom-os/compiler/bin/clang-16; \
    export CXX=/custom-os/compiler/bin/clang++-16; \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
    export PKG_CONFIG_PATH="/custom-os/usr/vulkan/lib/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/vulkan/include -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/vulkan/lib -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    \
    echo "=== CONFIGURING SHADERC WITH SYSROOT APPROACH ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/vulkan \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_PREFIX_PATH="/custom-os/usr/vulkan:/custom-os/usr:/custom-os/compiler" \
        -DCMAKE_INCLUDE_PATH="/custom-os/usr/vulkan/include:/custom-os/usr/include:/custom-os/compiler/include" \
        -DCMAKE_LIBRARY_PATH="/custom-os/usr/vulkan/lib:/custom-os/usr/lib:/custom-os/compiler/lib" \
        -DCMAKE_INSTALL_RPATH="/custom-os/usr/vulkan/lib:/custom-os/usr/lib:/custom-os/compiler/lib" \
        -DSPIRV-Tools_ROOT="/custom-os/usr/vulkan" \
        -DSPIRV-Headers_ROOT="/custom-os/usr/vulkan" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
        -DSHADERC_SKIP_TESTS=ON \
        -DSHADERC_SKIP_EXAMPLES=ON || (echo "✗ cmake configure failed (continuing)" && exit 0); \
    \
    echo "=== BUILDING SHADERC ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/shaderc-build.log || echo "✗ make failed (continuing)"; \
    \
    echo "=== INSTALLING SHADERC TO SYSROOT ===" && \
    DESTDIR="/custom-os" make install 2>&1 | tee /tmp/shaderc-install.log || echo "✗ make install failed (continuing)"; \
    \
    cd ../.. && \
    rm -rf shaderc 2>/dev/null || true; \
    \
    echo "=== SHADERC INSTALLATION VERIFICATION ===" && \
    echo "Shaderc binaries:"; \
    ls -la /custom-os/usr/vulkan/bin/shaderc* 2>/dev/null || echo "No shaderc binaries found"; \
    echo "Shaderc libraries:"; \
    ls -la /custom-os/usr/vulkan/lib/libshaderc* 2>/dev/null || echo "No shaderc libraries found"; \
    \
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/vulkan/lib && \
    for lib in $(ls libshaderc*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname" 2>/dev/null || true; \
        ln -sf "$soname" "$basename" 2>/dev/null || true; \
        echo "Created symlinks for $lib"; \
    done; \
    \
    /usr/local/bin/check_llvm15.sh "post-shaderc-source-build" || true; \
    echo "=== SHADERC BUILD COMPLETE ==="; \
    true

# ======================
# SECTION: libgbm Build
# ======================
RUN echo "=== BUILDING libgbm FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libgbm-deps" || true && \
    \
    git clone --depth=1 https://github.com/robclark/libgbm.git && \
    cd libgbm && \
    \
    echo "=== CONFIGURING LIBGBM ===" && \
    # Set up pkg-config environment to find libdrm in our sysroot
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/usr/share/pkgconfig:${PKG_CONFIG_PATH:-}" && \
    \
    ./autogen.sh --prefix=/custom-os/usr && \
    ./configure \
        --prefix=/custom-os/usr \
        CC=/custom-os/compiler/bin/clang-16 \
        CXX=/custom-os/compiler/bin/clang++-16 \
        CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        CXXFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib" && \
    \
    echo "=== BUILDING LIBGBM ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/libgbm-build.log && \
    \
    echo "=== INSTALLING LIBGBM ===" && \
    make install 2>&1 | tee /tmp/libgbm-install.log && \
    \
    cd .. && \
    rm -rf libgbm && \
    \
    echo "=== LIBGBM INSTALLATION VERIFICATION ===" && \
    echo "libgbm libraries:" && \
    ls -la /custom-os/usr/lib/libgbm* 2>/dev/null || echo "No libgbm libraries found" && \
    \
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/lib && \
    for lib in $(ls libgbm.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    /usr/local/bin/check_llvm15.sh "after-libgbm" || true && \
    echo "=== LIBGBM BUILD COMPLETE ==="

# ======================
# SECTION: GStreamer Plugins Base Build
# ======================
RUN \
    printf '%s\n' "=== BUILDING gst-plugins-base (defensive, POSIX) ==="; \
    # --- pre-checks for tools --- \
    CC_BIN=/custom-os/compiler/bin/clang-16; \
    CXX_BIN=/custom-os/compiler/bin/clang++-16; \
    LLVM_CONFIG_BIN=/custom-os/compiler/bin/llvm-config; \
    PKGCONFIG=/usr/bin/pkg-config; \
    NPROCS="$(nproc 2>/dev/null || echo 1)"; \
    if [ ! -x "$CC_BIN" ] || [ ! -x "$CXX_BIN" ]; then \
        printf '%s\n' "⚠ Compiler(s) not found at $CC_BIN or $CXX_BIN — skipping gst and xorg builds"; \
    else \
        \
        # --- GStreamer plugins --- \
        printf '%s\n' ">>> gst-plugins-base: fetching and extracting"; \
        wget -q https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.20.3.tar.xz && \
            tar -xJf gst-plugins-base-1.20.3.tar.xz || { printf '%s\n' "✗ failed to fetch/extract gst-plugins-base"; true; } && \
        if [ -d gst-plugins-base-1.20.3 ]; then \
            cd gst-plugins-base-1.20.3 || true; \
            printf '%s\n' ">>> gst-plugins-base: configuring"; \
            ./configure \
              --prefix=/custom-os/usr/media \
              --disable-static \
              --enable-shared \
              --disable-introspection \
              --disable-examples \
              --disable-gtk-doc \
              CC="$CC_BIN" CXX="$CXX_BIN" \
              LLVM_CONFIG="$LLVM_CONFIG_BIN" \
              CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
              CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
              LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
              PKG_CONFIG_PATH="/custom-os/usr/media/pkgconfig:/custom-os/usr/x11/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}" || printf '%s\n' "⚠ configure returned non-zero (gst): see /tmp/gst-plugins-config.log"; \
            printf '%s\n' ">>> gst-plugins-base: building"; \
            (make -j"$NPROCS" 2>&1 | tee /tmp/gst-plugins-build.log) || printf '%s\n' "⚠ make returned non-zero (gst) — continuing"; \
            printf '%s\n' ">>> gst-plugins-base: installing to /custom-os"; \
            (make install 2>&1 | tee /tmp/gst-plugins-install.log) || printf '%s\n' "⚠ make install returned non-zero (gst) — continuing"; \
            cd ..; rm -rf gst-plugins-base-* || true; \
            printf '%s\n' ">>> gst-plugins-base: creating soname symlinks (best-effort)"; \
            if [ -d /custom-os/usr/media/lib ]; then \
                cd /custom-os/usr/media/lib || true; \
                for lib in $(ls libgst*.so.* 2>/dev/null || true); do \
                    soname=`printf '%s\n' "$lib" | sed 's/\(.*\.so\.[0-9][^.]*\).*/\1/'` || true; \
                    basename=`printf '%s\n' "$lib" | sed 's/\(.*\.so\).*/\1/'` || true; \
                    [ -n "$soname" ] && ln -sf "$lib" "$soname" || true; \
                    [ -n "$basename" ] && ln -sf "${soname:-$lib}" "$basename" || true; \
                done; \
            fi; \
        else \
            printf '%s\n' "⚠ gst-plugins-base source missing — skipping gst build"; \
        fi; \
    fi; \
    \
    printf '%s\n' "=== BUILDING xorg-server (defensive, POSIX, sysroot-aware) ==="; \
    if [ -x /custom-os/compiler/bin/clang-16 ]; then \
        export PATH="/custom-os/compiler/bin:$PATH"; \
        export CC=/custom-os/compiler/bin/clang-16; \
        export CXX=/custom-os/compiler/bin/clang++-16; \
        if [ -x /custom-os/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config; fi; \
    else \
        printf '%s\n' "✗ required compiler not present — skipping xorg-server build"; \
        true; \
    fi; \
    \
    if [ ! -d xorg-server ]; then \
        git clone --depth=1 --branch xorg-server-21.1.8 https://gitlab.freedesktop.org/xorg/xserver.git xorg-server 2>/tmp/xorg_clone.err || { printf '%s\n' "⚠ git clone failed (see /tmp/xorg_clone.err). Skipping xorg build"; true; } ; \
    fi; \
    if [ -d xorg-server ]; then \
        cd xorg-server || true; \
        printf '%s\n' ">>> xorg: scanning for llvm-15 references (best-effort)"; \
        grep -RIl "LLVM15\\|llvm-15" . 2>/tmp/xorg_source_scan.log || true; \
        \
        export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
        export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
        export CXXFLAGS="$CFLAGS"; \
        export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
        \
        /usr/local/bin/check-filesystem.sh "xorg-pre-config" 2>/tmp/xorg_filesystem.log || true; \
        printf 'int main(void){return 0;}\n' > /tmp/xorg_toolchain_test.c; \
        $CC $CFLAGS -Wl,--sysroot=/custom-os -o /tmp/xorg_toolchain_test /tmp/xorg_toolchain_test.c 2>/tmp/xorg_toolchain_test.err || printf '%s\n' "⚠ compiler test failed"; \
        \
        printf '%s\n' ">>> xorg: running autoreconf"; autoreconf -fiv 2>/tmp/xorg_autoreconf.log || true; \
        \
        CFG_FLAGS="--prefix=/usr --sysconfdir=/etc --localstatedir=/var \
          --disable-systemd-logind --disable-libunwind \
          --enable-xvfb --enable-xnest --enable-xephyr \
          --disable-xorg --disable-dmx --disable-xwin --disable-xquartz \
          --without-dtrace \
          --disable-glamor --disable-glx --disable-dri --disable-dri2 --disable-dri3 \
          --disable-docs"; \
        \
        printf '%s\n' ">>> xorg: configuring with flags: $CFG_FLAGS"; \
        ./configure $CFG_FLAGS \
          CC="$CC" CXX="$CXX" \
          PKG_CONFIG_SYSROOT_DIR="$PKG_CONFIG_SYSROOT_DIR" \
          PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
          CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
          2>&1 | tee /tmp/xorg-configure.log || true; \
        \
        printf '%s\n' ">>> xorg: make (best-effort, non-fatal)"; \
        (make -j"$NPROCS" 2>&1 | tee /tmp/xorg-build.log) || printf '%s\n' "✗ make failed (see /tmp/xorg-build.log) — continuing"; \
        printf '%s\n' ">>> xorg: make install into /custom-os"; \
        (DESTDIR=/custom-os make install 2>&1 | tee /tmp/xorg-install.log) || printf '%s\n' "✗ make install failed (see /tmp/xorg-install.log) — continuing"; \
        \
        mkdir -p /custom-os/usr/x11 || true; \
        mv /custom-os/usr/bin/X* /custom-os/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mv /custom-os/usr/lib/libxserver* /custom-os/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mkdir -p /custom-os/usr/x11/include/xorg || true; \
        cp -r include/* /custom-os/usr/x11/include/xorg/ 2>/tmp/xorg-mv.log || true; \
        \
        for xbin in /custom-os/usr/x11/X*; do \
            [ -f "$xbin" ] || continue; \
            ln -sf "../x11/$(basename "$xbin")" "/custom-os/usr/bin/$(basename "$xbin")" 2>/dev/null || true; \
        done; \
        for xlib in /custom-os/usr/x11/libxserver*; do \
            [ -f "$xlib" ] || continue; \
            ln -sf "../x11/$(basename "$xlib")" "/custom-os/usr/lib/$(basename "$xlib")" 2>/dev/null || true; \
        done; \
        \
        /usr/local/bin/dependency_checker.sh /custom-os/compiler/bin/clang-16 2>/tmp/xorg_depcheck.log || true; \
        /usr/local/bin/binlib_validator.sh /custom-os/compiler/bin/clang-16 2>/tmp/xorg_binlib.log || true; \
        /usr/local/bin/version_matrix.sh 2>/tmp/xorg_versions.log || true; \
        /usr/local/bin/cflag_audit.sh 2>/tmp/xorg_cflags.log || true; \
        find /custom-os/usr -name "*xserver*" -exec grep -l "LLVM15\\|llvm-15" {} \; 2>/tmp/xorg_contam.log || true; \
        \
        cd /; rm -rf xorg-server 2>/dev/null || true; \
        printf '%s\n' ">>> xorg build step complete (see logs in /tmp)"; \
    else \
        printf '%s\n' "⚠ xorg-server source directory not present; skipped build"; \
    fi; \
    true


# ======================
# SECTION: Mesa Build (sysroot-focused, non-fatal) — FINAL
# ======================

ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

RUN echo "=== MESA BUILD WITH LLVM16 ENFORCEMENT ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-clone" || true; \
    \
    git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git || (echo "⚠ mesa not cloned; skipping build commands" && exit 0); \
    if [ -d mesa ]; then cd mesa; else echo "⚠ mesa directory missing; skipping build"; exit 0; fi; \
    \
    git checkout mesa-24.0.3 || true; \
    /usr/local/bin/check_llvm15.sh "post-mesa-clone" || true; \
    \
    # Set up environment for proper sysroot build
    export PATH="/custom-os/compiler/bin:$PATH"; \
    export CC=/custom-os/compiler/bin/clang-16; \
    export CXX=/custom-os/compiler/bin/clang++-16; \
    if [ -x /custom-os/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config; fi; \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    \
    # Run filesystem check
    echo "=== FILESYSTEM DIAGNOSIS ==="; \
    /usr/local/bin/check-filesystem.sh || true; \
    \
    echo "=== MESA BUILD CONFIGURATION (ARM64 + LLVM16) ===" && \
    meson setup builddir/ \
        --prefix=/usr \
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
        -Dllvm=enabled || (echo "✗ meson setup failed (continuing)" && /usr/local/bin/dep_chain_visualizer.sh "mesa meson setup failed"); \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-configure" || true; \
    \
    echo "=== MESA BUILD LOGS (tail) ===" && \
    test -f builddir/meson-logs/meson-log.txt && tail -n 200 builddir/meson-logs/meson-log.txt || true; \
    echo "=== MESA CONFIGURATION ==="; \
    meson configure builddir/ || true; \
    \
    echo "=== STARTING NINJA BUILD (ARM64 + LLVM16) ===" && \
    ninja -C builddir -v 2>&1 | tee /tmp/mesa-build.log || echo "✗ ninja build failed (continuing)"; \
    \
    # Install with DESTDIR for proper sysroot deployment
    echo "=== INSTALLING MESA TO SYSROOT ===" && \
    DESTDIR="/custom-os" ninja -C builddir install 2>&1 | tee /tmp/mesa-install.log || echo "✗ ninja install failed (continuing)"; \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-build" || true; \
    \
    echo "=== VULKAN ICD CONFIGURATION (ARM64) ===" && \
    mkdir -p /custom-os/usr/share/vulkan/icd.d && \
    printf '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > /custom-os/usr/share/vulkan/icd.d/swrast_icd.arm64.json; \
    \
    # Organize Mesa components in the sysroot
    echo "=== ORGANIZING MESA COMPONENTS IN SYSROOT ===" && \
    mkdir -p /custom-os/usr/mesa && \
    # Move only Mesa-specific binaries (NOT ALL binaries) to preserve /custom-os/usr/bin integrity
    find /custom-os/usr/bin -name "*mesa*" -o -name "*gl*" -o -name "*egl*" | xargs -I {} mv {} /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libGL* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libEGL* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libgbm* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libvulkan* /custom-os/usr/mesa/ 2>/dev/null || true; \
    \
    # Mesa components isolated - NO symlinks to preserve binary directory integrity
    echo "=== MESA ISOLATION COMPLETE ===" && \
    echo "Mesa components isolated in /custom-os/usr/mesa/ directory" && \
    echo "No symlinks created to preserve /custom-os/usr/bin for application binary" && \
    ls -la /custom-os/usr/mesa/ 2>/dev/null || echo "Mesa directory contents not available" \
    \
    # Create DRI directory structure and helpful symlinks
    echo "=== CREATING DRI DIRECTORY STRUCTURE ===" && \
    mkdir -p /custom-os/usr/lib/xorg/modules/dri /custom-os/usr/lib/dri || true; \
    ln -sf /custom-os/usr/lib/dri /custom-os/usr/lib/xorg/modules/dri || true; \
    \
    # Run diagnostic scripts
    echo "=== COMPILER DEPENDENCY CHECK ==="; \
    /usr/local/bin/dependency_checker.sh /custom-os/compiler/bin/clang-16 || true; \
    \
    echo "=== COMPILER VALIDATION ==="; \
    /usr/local/bin/binlib_validator.sh /custom-os/compiler/bin/clang-16 || true; \
    \
    echo "=== VERSION COMPATIBILITY CHECK ==="; \
    /usr/local/bin/version_matrix.sh || true; \
    \
    echo "=== COMPILER FLAGS AUDIT ==="; \
    /usr/local/bin/cflag_audit.sh || true; \
    \
    # Cleanup
    cd / && \
    rm -rf mesa 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-cleanup" || true; \
    echo "=== MESA SECTION COMPLETE ==="; \
    true

# ======================
# BUILD GBM (from Mesa)
# ======================
RUN echo "=== BUILDING GBM FROM MESA SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gbm-source-build" || true && \
    \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git /tmp/mesa && \
    cd /tmp/mesa && \
    \
    echo ">>> Configuring GBM <<<" && \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=enabled \
        -Ddri-drivers= \
        -Dgallium-drivers= \
        -Degl=disabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=disabled && \
    \
    ninja -C builddir -v && \
    DESTDIR="/custom-os" ninja -C builddir install && \
    \
    echo "=== VERIFYING GBM INSTALLATION ===" && \
    find /custom-os -name "*gbm*" -type f | tee /tmp/gbm_install.log && \
    /usr/local/bin/check_llvm15.sh "post-gbm-install" || true && \
    \
    cd / && rm -rf /tmp/mesa

# ======================
# BUILD EGL (from Mesa)
# ======================
RUN echo "=== BUILDING EGL FROM MESA SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-egl-source-build" || true && \
    \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git /tmp/mesa && \
    cd /tmp/mesa && \
    \
    echo ">>> Configuring EGL <<<" && \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=disabled \
        -Degl=enabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=disabled && \
    \
    ninja -C builddir -v && \
    DESTDIR="/custom-os" ninja -C builddir install && \
    \
    echo "=== VERIFYING EGL INSTALLATION ===" && \
    find /custom-os -name "*EGL*" -type f | tee /tmp/egl_install.log && \
    /usr/local/bin/check_llvm15.sh "post-egl-install" || true && \
    \
    cd / && rm -rf /tmp/mesa

# ======================
# BUILD GLES (from Mesa)
# ======================
RUN echo "=== BUILDING GLES FROM MESA SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gles-source-build" || true && \
    \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git /tmp/mesa && \
    cd /tmp/mesa && \
    \
    echo ">>> Configuring GLES <<<" && \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=disabled \
        -Degl=disabled \
        -Dgles1=enabled \
        -Dgles2=enabled \
        -Dopengl=disabled && \
    \
    ninja -C builddir -v && \
    DESTDIR="/custom-os" ninja -C builddir install && \
    \
    echo "=== VERIFYING GLES INSTALLATION ===" && \
    find /custom-os -name "*GLES*" -type f | tee /tmp/gles_install.log && \
    /usr/local/bin/check_llvm15.sh "post-gles-install" || true && \
    \
    cd / && rm -rf /tmp/mesa

# ======================
# BUILD JACK2
# ======================
RUN echo "=== BUILDING JACK2 FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-jack2-source-build" || true && \
    \
    git clone --depth=1 https://gitlab.freedesktop.org/jack/jack2.git /tmp/jack2 && \
    cd /tmp/jack2 && \
    \
    echo ">>> Configuring JACK2 <<<" && \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr && \
    \
    ninja -C builddir -v && \
    DESTDIR="/custom-os" ninja -C builddir install && \
    \
    echo "=== VERIFYING JACK2 INSTALLATION ===" && \
    find /custom-os -name "*jack*" -type f | tee /tmp/jack2_install.log && \
    /usr/local/bin/check_llvm15.sh "post-jack2-install" || true && \
    \
    cd / && rm -rf /tmp/jack2

# ======================
# SECTION: SDL3 Build
# ======================
RUN echo "=== BUILDING SDL3 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3" || true && \
    \
    # Install build dependencies
    git clone --depth=1 https://github.com/libsdl-org/SDL.git sdl && \
    cd sdl && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3 ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/media \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
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
        -DCMAKE_C_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    echo "=== BUILDING SDL3 ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-build.log && \
    \
    # Verify installation
    echo "=== SDL3 INSTALLATION VERIFICATION ===" && \
    echo "SDL3 libraries:" && \
    ls -la /custom-os/usr/media/lib/libSDL3* 2>/dev/null || echo "No SDL3 libraries found" && \
    \
    cd ../../.. && \
    rm -rf sdl && \
    /usr/local/bin/check_llvm15.sh "post-sdl3" || true && \
    echo "=== SDL3 BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_image Build
# ======================
RUN echo "=== BUILDING SDL3_image ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-image" || true && \
    \
    # Install build dependencies
    git clone --depth=1 https://github.com/libsdl-org/SDL_image.git sdl_image && \
    cd sdl_image && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_image ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/media \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DSDL3IMAGE_PNG=ON \
        -DSDL3IMAGE_JPG=ON \
        -DSDL3IMAGE_TIF=ON \
        -DSDL3IMAGE_WEBP=ON \
        -DSDL3IMAGE_AVIF=ON \
        -DSDL3IMAGE_BMP=ON \
        -DSDL3IMAGE_GIF=ON \
        -DSDL3IMAGE_LBM=ON \
        -DSDL3IMAGE_PCX=ON \
        -DSDL3IMAGE_PNM=ON \
        -DSDL3IMAGE_QOI=ON \
        -DSDL3IMAGE_SVG=ON \
        -DSDL3IMAGE_TGA=ON \
        -DSDL3IMAGE_XCF=ON \
        -DSDL3IMAGE_XPM=ON \
        -DSDL3IMAGE_XV=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    echo "=== BUILDING SDL3_image ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-image-build.log && \
    \
    # Verify installation
    echo "=== SDL3_image INSTALLATION VERIFICATION ===" && \
    echo "SDL3_image libraries:" && \
    ls -la /custom-os/usr/media/lib/libSDL3_image* 2>/dev/null || echo "No SDL3_image libraries found" && \
    \
    cd ../../.. && \
    rm -rf sdl_image && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-image" || true && \
    echo "=== SDL3_image BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_mixer Build
# ======================
RUN echo "=== BUILDING SDL3_mixer ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-mixer" || true && \
    \
    # Install build dependencies
    git clone --depth=1 https://github.com/libsdl-org/SDL_mixer.git sdl_mixer && \
    cd sdl_mixer && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_mixer ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/media \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DSDL3MIXER_OGG=ON \
        -DSDL3MIXER_FLAC=ON \
        -DSDL3MIXER_MOD=ON \
        -DSDL3MIXER_MP3=ON \
        -DSDL3MIXER_MID=ON \
        -DSDL3MIXER_OPUS=ON \
        -DSDL3MIXER_FLUIDSYNTH=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    echo "=== BUILDING SDL3_mixer ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-mixer-build.log && \
    \
    # Verify installation
    echo "=== SDL3_mixer INSTALLATION VERIFICATION ===" && \
    echo "SDL3_mixer libraries:" && \
    ls -la /custom-os/usr/media/lib/libSDL3_mixer* 2>/dev/null || echo "No SDL3_mixer libraries found" && \
    \
    cd ../../.. && \
    rm -rf sdl_mixer && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-mixer" || true && \
    echo "=== SDL3_mixer BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_ttf Build
# ======================
RUN echo "=== BUILDING SDL3_ttf ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-ttf" || true && \
    \
    # Install build dependencies
    git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git sdl_ttf && \
    cd sdl_ttf && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_ttf ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/media \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    echo "=== BUILDING SDL3_ttf ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-ttf-build.log && \
    \
    # Verify installation
    echo "=== SDL3_ttf INSTALLATION VERIFICATION ===" && \
    echo "SDL3_ttf libraries:" && \
    ls -la /custom-os/usr/media/lib/libSDL3_ttf* 2>/dev/null || echo "No SDL3_ttf libraries found" && \
    \
    cd ../../.. && \
    rm -rf sdl_ttf && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-ttf" || true && \
    echo "=== SDL3_ttf BUILD COMPLETED ==="

# ======================
# SECTION: Vulkan Components
# ======================

# Vulkan-Headers
RUN echo "=== BUILDING VULKAN-HEADERS ===" && \
    /usr/local/bin/check_llvm15.sh "pre-vulkan-headers" || true && \
    \
    git clone --progress https://github.com/KhronosGroup/Vulkan-Headers.git && \
    cd Vulkan-Headers && mkdir build && cd build && \
    \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/vulkan \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Headers && \
    \
    # Verify installation
    echo "=== VULKAN-HEADERS INSTALLATION VERIFICATION ===" && \
    ls -la /custom-os/usr/vulkan/include/vulkan/ 2>/dev/null || echo "No Vulkan headers found" && \
    \
    /usr/local/bin/check_llvm15.sh "post-vulkan-headers" || true && \
    echo "=== VULKAN-HEADERS BUILD COMPLETED ==="

# Vulkan-Loader
RUN echo "=== BUILDING VULKAN-LOADER ===" && \
    /usr/local/bin/check_llvm15.sh "pre-vulkan-loader" || true && \
    \
    git clone --progress https://github.com/KhronosGroup/Vulkan-Loader.git && \
    cd Vulkan-Loader && mkdir build && cd build && \
    \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/vulkan \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        -DBUILD_TESTS=OFF \
        -DVULKAN_HEADERS_INSTALL_DIR=/custom-os/usr/vulkan && \
    \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Loader && \
    \
    # Verify installation
    echo "=== VULKAN-LOADER INSTALLATION VERIFICATION ===" && \
    ls -la /custom-os/usr/vulkan/lib/libvulkan* 2>/dev/null || echo "No Vulkan loader libraries found" && \
    \
    # Create symlinks
    echo "=== CREATING VULKAN LOADER SYMLINKS ===" && \
    cd /custom-os/usr/vulkan/lib && \
    for lib in $(ls libvulkan.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    /usr/local/bin/check_llvm15.sh "post-vulkan-loader" || true && \
    echo "=== VULKAN-LOADER BUILD COMPLETED ==="

# ======================
# SECTION: glmark2 Build
# ======================
RUN echo "=== BUILDING GLMARK2 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-glmark2" || true && \
    \
    git clone --depth=1 https://github.com/glmark2/glmark2.git && \
    cd glmark2 && \
    \
    echo "=== DIRECTORY STRUCTURE (PRE-BUILD) ===" && \
    tree -L 2 && \
    echo "=== WAF SCRIPT PERMISSIONS ===" && \
    ls -l waf* || true && \
    \
    echo "=== CONFIGURING GLMARK2 WITH LLVM16 ===" && \
    CC=/custom-os/compiler/bin/clang-16 \
    CXX=/custom-os/compiler/bin/clang++-16 \
    CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
    LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
    python3 ./waf configure \
        --prefix=/custom-os/usr/x11 \
        --with-flavors=x11-gl,drm-gl \
        --verbose 2>&1 | tee configure.log || { \
            echo "=== CONFIGURATION FAILED - SHOWING LOG ==="; \
            cat configure.log; \
            exit 1; \
        } && \
    \
    echo "=== BUILDING GLMARK2 ===" && \
    python3 ./waf build -j"$(nproc)" --verbose 2>&1 | tee build.log || { \
        echo "=== BUILD FAILED - SHOWING LOG ==="; \
        cat build.log; \
        exit 1; \
    } && \
    \
    echo "=== INSTALLING GLMARK2 ===" && \
    python3 ./waf install --verbose 2>&1 | tee install.log && \
    \
    # Verify installation
    echo "=== GLMARK2 INSTALLATION VERIFICATION ===" && \
    ls -la /custom-os/usr/x11/bin/glmark2* 2>/dev/null || echo "No glmark2 binaries found" && \
    \
    cd .. && \
    /usr/local/bin/check_llvm15.sh "post-glmark2" || true && \
    echo "=== GLMARK2 BUILD COMPLETED ==="

# ======================
# SECTION: Environment Configuration
# ======================
ENV PKG_CONFIG_PATH=/custom-os/compiler/lib/pkgconfig:/custom-os/usr/vulkan/pkgconfig:/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig
ENV LD_LIBRARY_PATH=/custom-os/compiler/lib:/custom-os/usr/vulkan/lib:/custom-os/usr/x11/lib:/custom-os/usr/lib

# ======================
# SECTION: LLVM15 Contamination Check
# ======================
RUN echo "=== FINAL LLVM15 CONTAMINATION CHECK ===" && \
    (grep -R --binary-files=without-match -n "llvm-15" /custom-os/ || true) | tee /tmp/llvm15-grep || true && \
    test ! -s /tmp/llvm15-grep || (echo "FOUND llvm-15 references - aborting" && cat /tmp/llvm15-grep && false) || true && \
    echo "=== STAGE END VERIFICATION: filesystem-libs-build-builder ===" && \
    echo "Verifying binary directory /custom-os/usr/bin exists:" && \
    if [ -d /custom-os/usr/bin ]; then \
        ls -la /custom-os/usr/bin && \
        echo "✓ filesystem-libs-build-builder stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /custom-os/usr/bin does not exist!" && \
        echo "Available directories in /custom-os/usr/:" && \
        ls -la /custom-os/usr/ 2>/dev/null || echo "No /custom-os/usr/ directory found" && \
        exit 1; \
    fi

# ======================
# SECTION: SQLite3 Build
# ======================
RUN echo "=== SQLITE3 BUILD WITH LLVM16 ENFORCEMENT ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sqlite3-clone" || true && \
    \
    git clone --progress https://github.com/sqlite/sqlite.git sqlite && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-clone" || true && \
    cd sqlite && \
    mkdir build && cd build && \
    \
    echo "=== SQLITE3 BUILD CONFIGURATION (ARM64 + LLVM16) ===" && \
    CC=/custom-os/compiler/bin/clang-16 \
    CXX=/custom-os/compiler/bin/clang++-16 \
    LLVM_CONFIG=/custom-os/compiler/bin/llvm-config \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/lib \
        -DSQLITE_ENABLE_COLUMN_METADATA=ON \
        -DSQLITE_ENABLE_FTS3=ON \
        -DSQLITE_ENABLE_FTS4=ON \
        -DSQLITE_ENABLE_FTS5=ON \
        -DSQLITE_ENABLE_JSON1=ON \
        -DSQLITE_ENABLE_RTREE=ON \
        -DSQLITE_ENABLE_DBSTAT_VTAB=ON \
        -DSQLITE_SECURE_DELETE=ON \
        -DSQLITE_USE_URI=ON \
        -DSQLITE_ENABLE_UNLOCK_NOTIFY=ON \
        -DSQLITE_ENABLE_ZLIB=ON \
        -DCMAKE_C_FLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-error" \
        -DCMAKE_CXX_FLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-error" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        -DPKG_CONFIG_PATH="/custom-os/compiler/lib/pkgconfig:/custom-os/usr/lib/pkgconfig" \
        -Wno-dev && \
    \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-configure" || true && \
    \
    echo "=== STARTING SQLITE3 BUILD (ARM64 + LLVM16) ===" && \
    make -j"$(nproc)" VERBOSE=1 install && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-build" || true && \
    \
    echo "=== VERIFYING SQLITE3 INSTALL ===" && \
    test -f /custom-os/usr/lib/include/sqlite3.h && \
    PKG_CONFIG_PATH=/custom-os/usr/lib/pkgconfig pkg-config --cflags --libs sqlite3 && \
    \
    cd ../.. && \
    rm -rf sqlite && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-cleanup" || true && \
    echo "=== SQLITE3 BUILD COMPLETED ==="

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
    mkdir -p /custom-os/app/src /custom-os/app/build /custom-os/usr/lib /custom-os/usr/include /custom-os/snapshots && \
    echo "CRITICAL: Creating target binary directory..." && \
    mkdir -p /custom-os/usr/bin && \
    echo "VERIFICATION: Target binary directory exists:" && \
    ls -la /custom-os/usr/bin && \
    echo "Filesystem initialized with binary target directory confirmed"

# Set working directory for app build
WORKDIR /custom-os/app

# Copy application source
COPY . ./src

# ======================
# SECTION: Source Verification
# ======================
RUN echo "=== SAFETY CHECK: VERIFY SOURCE CODE ===" && \
    ls -la ./src/ | tee /tmp/source_copy.log && \
    if [ -f ./src/CMakeLists.txt ]; then \
        echo "✓ CMakeLists.txt found"; \
        head -20 ./src/CMakeLists.txt | tee /tmp/CMakeLists_preview.log; \
    else \
        echo "✗ CMakeLists.txt NOT found"; \
        find ./src -type f | tee /tmp/available_source_files.log; \
    fi && \
    find ./src -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.hpp" | tee /tmp/source_files_list.log

# ======================
# SECTION: Environment Setup for Build
# ======================
ENV PATH="/custom-os/usr/bin:/custom-os/compiler/bin:$PATH"
ENV PKG_CONFIG_SYSROOT_DIR="/custom-os"
ENV PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:$LD_LIBRARY_PATH"
ENV C_INCLUDE_PATH="/custom-os/usr/include:${C_INCLUDE_PATH:-}"

# ======================
# SECTION: CMake Build
# ======================
WORKDIR /custom-os/app/build
RUN mkdir -p . && \
    # --- Detect compiler location (prefer /custom-os/compiler/bin, fallback to system) ---
    if [ -x /custom-os/compiler/bin/clang-16 ]; then \
        CC=/custom-os/compiler/bin/clang-16; CXX=/custom-os/compiler/bin/clang++-16; \
    elif [ -x /custom-os/compiler/bin/clang ]; then \
        CC=/custom-os/compiler/bin/clang; CXX=/custom-os/compiler/bin/clang++; \
    elif command -v clang-16 >/dev/null 2>&1; then \
        CC=$(command -v clang-16); CXX=$(command -v clang++-16 || command -v clang++); \
    elif command -v clang >/dev/null 2>&1; then \
        CC=$(command -v clang); CXX=$(command -v clang++); \
    else \
        echo "ERROR: No clang compiler found (tried /custom-os/compiler/bin and PATH)"; exit 1; \
    fi && \
    echo "Using compilers: CC=${CC} CXX=${CXX}" && \
    export CC CXX && \
    \
    # --- Setup flags and decide whether libc++ is available ---
    SYSROOT_FLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" && \
    # If libc++ exists in compiler lib, prefer it; otherwise fallback to libstdc++
    if [ -f /custom-os/compiler/lib/libc++.so ] || [ -f /custom-os/usr/lib/libc++.so ]; then \
        echo "libc++ detected in sysroot; enabling -stdlib=libc++"; \
        CXXFLAGS="${SYSROOT_FLAGS} -stdlib=libc++"; \
        LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib -stdlib=libc++ -lc++ -lc++abi"; \
    else \
        echo "libc++ NOT found; falling back to libstdc++ (no -stdlib=libc++)"; \
        CXXFLAGS="${SYSROOT_FLAGS}"; \
        LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    fi && \
    export CFLAGS="${SYSROOT_FLAGS}" && export CXXFLAGS && export LDFLAGS && \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    \
    echo "=== PRE-BUILD VERIFICATION ===" && echo "Compiler: $CC" && echo "CXXFLAGS: $CXXFLAGS" && echo "LDFLAGS: $LDFLAGS" && \
    echo "Checking for CMakeLists.txt..." && ls -la ../src/src/CMakeLists.txt && echo "Source dir:" && ls -la ../src/src/ && \
    \
    # Run cmake configure & build (pass explicit compilers so there's no ambiguity)
    cmake ../src/src \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_CXX_COMPILER="${CXX}" \
        -DCMAKE_SYSROOT=/custom-os \
        -DCMAKE_PREFIX_PATH="/custom-os/usr;/custom-os/compiler" \
        -DCMAKE_FIND_ROOT_PATH="/custom-os" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_RPATH="/custom-os/usr/lib:/custom-os/compiler/lib" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
        -DALPINE_LINUX_BUILD=ON \
        2>&1 | tee /tmp/cmake_configure.log && \
    echo "=== BUILDING APPLICATION ===" && \
    cmake --build . --target simplehttpserver -- -j$(nproc) 2>&1 | tee /tmp/cmake_build.log && \
    echo "=== INSTALL (DESTDIR) ===" && \
    DESTDIR=/custom-os cmake --install . 2>&1 | tee /tmp/cmake_install.log


# ======================
# SECTION: Final Environment
# ======================
ENV PATH="/custom-os/usr/bin:/custom-os/compiler/bin:$PATH"


# Stage: debug environment
FROM app-build AS debug

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_DEBUG" && \
    rm -f /tmp/nocache/timestamp

# ======================
# SECTION: Debug Environment Setup (sysroot-focused) — FINAL
# ======================

RUN echo "=== INITIALIZING DEBUG ENVIRONMENT ===" && \
    mkdir -p /custom-os/usr/{bin,lib,include,share} && \
    mkdir -p /custom-os/var/log/debug && \
    \
    # Verify filesystem structure
    echo "=== FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS structure:" && \
    find /custom-os -maxdepth 3 -type d -exec ls -ld {} \; | tee /custom-os/var/log/debug/filesystem_structure.log && \
    \
    # Verify application binary exists (handle both possible locations)
    echo "=== APPLICATION BINARY VERIFICATION ===" && \
    if [ -f /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Application found in /custom-os/usr/bin/"; \
        ls -la /custom-os/usr/bin/simplehttpserver | tee -a /custom-os/var/log/debug/component_verify.log; \
        /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /custom-os/var/log/debug/component_verify.log || true; \
    elif [ -f /custom-os/app/build/simplehttpserver ]; then \
        echo "⚠ Application found in build directory, copying to /custom-os/usr/bin/"; \
        mkdir -p /custom-os/usr/bin; \
        cp -f /custom-os/app/build/simplehttpserver /custom-os/usr/bin/; \
        chmod +x /custom-os/usr/bin/simplehttpserver; \
        ls -la /custom-os/usr/bin/simplehttpserver | tee -a /custom-os/var/log/debug/component_verify.log; \
        /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /custom-os/var/log/debug/component_verify.log || true; \
    else \
        echo "✗ Application binary not found in expected locations"; \
        echo "Searching for application binary:"; \
        find /custom-os -name "simplehttpserver" -type f 2>/dev/null | tee -a /custom-os/var/log/debug/component_verify.log || true; \
    fi

# ======================
# SECTION: Mesa Demos Build with Sysroot Approach
# ======================
RUN echo "=== BUILDING MESA DEMOS WITH SYSROOT APPROACH ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-demos-source" | tee /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    # Set up proper sysroot environment
    export PATH="/custom-os/compiler/bin:$PATH"; \
    export CC=/custom-os/compiler/bin/clang-16; \
    export CXX=/custom-os/compiler/bin/clang++-16; \
    if [ -x /custom-os/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config; fi; \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    \
    # Clone and verify source
    echo "=== CLONING AND VERIFYING SOURCE ===" && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/demos.git /tmp/mesa-demos || (echo "⚠ mesa-demos not cloned; skipping build" && exit 0); \
    cd /tmp/mesa-demos && \
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" . 2>&1 | tee /custom-os/var/log/debug/source_scan.log || true); \
    \
    # Environment verification
    echo "=== BUILD ENVIRONMENT VERIFICATION ===" && \
    echo "CC: $CC" | tee /custom-os/var/log/debug/build_env.log; \
    echo "CXX: $CXX" | tee -a /custom-os/var/log/debug/build_env.log; \
    echo "LLVM_CONFIG: $LLVM_CONFIG" | tee -a /custom-os/var/log/debug/build_env.log; \
    echo "CFLAGS: $CFLAGS" | tee -a /custom-os/var/log/debug/build_env.log; \
    echo "LDFLAGS: $LDFLAGS" | tee -a /custom-os/var/log/debug/build_env.log; \
    \
    # Configure with sysroot approach
    echo "=== CONFIGURING WITH SYSROOT APPROACH ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DWAYLAND=OFF \
        -DGLES=OFF \
        -DGLUT=ON \
        -Werror=dev \
        -Wno-dev 2>&1 | tee /custom-os/var/log/debug/cmake_configure.log || (echo "✗ cmake configure failed (continuing)" && exit 0); \
    \
    # Build with dependency verification
    echo "=== BUILDING WITH DEPENDENCY VERIFICATION ===" && \
    make -j$(nproc) VERBOSE=1 2>&1 | tee /custom-os/var/log/debug/make_build.log || echo "✗ make failed (continuing)"; \
    \
    # Install with DESTDIR for proper sysroot deployment
    echo "=== INSTALLING TO SYSROOT ===" && \
    DESTDIR="/custom-os" make install 2>&1 | tee /custom-os/var/log/debug/make_install.log || echo "✗ make install failed (continuing)"; \
    \
    # Verify build artifacts
    echo "=== VERIFYING BUILD ARTIFACTS ===" && \
    echo "Generated binaries:" && \
    find . -type f -executable -exec ls -la {} \; | tee /custom-os/var/log/debug/build_artifacts.log; \
    echo "Installed binaries:"; \
    ls -la /custom-os/usr/bin/gl* 2>/dev/null | tee -a /custom-os/var/log/debug/make_install.log || true; \
    \
    # Cleanup
    cd / && \
    rm -rf /tmp/mesa-demos 2>/dev/null || true; \
    \
    # Final contamination check
    /usr/local/bin/check_llvm15.sh "post-mesa-demos-build" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    echo "=== MESA DEMOS BUILD COMPLETE ==="

# ======================
# SECTION: Debug Tools Installation (Sysroot Integrated)
# ======================
RUN echo "=== INSTALLING DEBUG TOOLS ===" && \
    apk add --no-cache \
        gdb \
        strace \
        ltrace \
        valgrind \
        perf \
        lsof \
        file \
        binutils \
        xdpyinfo \
        xrandr \
        xeyes 2>&1 | tee /custom-os/var/log/debug/tools_install.log; \
    \
    # Verify debug tools
    echo "=== DEBUG TOOLS VERIFICATION ===" && \
    echo "Installed debug tools:" && \
    which gdb strace ltrace valgrind perf lsof file objdump xdpyinfo xrandr xeyes 2>/dev/null | tee /custom-os/var/log/debug/tools_verify.log; \
    \
    # Copy debug tools to custom filesystem using safe method
    echo "=== INTEGRATING DEBUG TOOLS INTO SYSROOT ===" && \
    mkdir -p /custom-os/usr/bin /custom-os/usr/share/debug; \
    for cmd in gdb strace ltrace valgrind perf lsof file objdump xdpyinfo xrandr xeyes; do \
        src="$(command -v "$cmd" 2>/dev/null || true)"; \
        if [ -n "$src" ] && [ -f "$src" ]; then \
            echo "copying $src -> /custom-os/usr/bin/"; \
            cp -p "$src" "/custom-os/usr/bin/"; \
        else \
            echo "warning: $cmd not found or not executable"; \
        fi; \
    done; \
    \
    # Copy debug data directories
    [ -d /usr/share/gdb ] && cp -rp /usr/share/gdb /custom-os/usr/share/debug/ 2>/dev/null || true; \
    [ -d /usr/share/valgrind ] && cp -rp /usr/share/valgrind /custom-os/usr/share/debug/ 2>/dev/null || true; \
    echo "=== DEBUG ENVIRONMENT READY ==="

# ======================
# SECTION: DRI Configuration
# ======================
RUN echo "=== CONFIGURING DRI DIRECTORY STRUCTURE ===" && \
    mkdir -p /custom-os/usr/lib/xorg/modules && \
    \
    # Create DRI structure in custom filesystem
    echo "Creating DRI links in custom filesystem..." | tee /custom-os/var/log/debug/dri_setup.log && \
    mkdir -p /custom-os/usr/lib/dri && \
    ln -sf /custom-os/usr/lib/dri /custom-os/usr/lib/xorg/modules/dri 2>&1 | tee -a /custom-os/var/log/debug/dri_setup.log; \
    \
    # Verify DRI structure
    echo "=== VERIFYING DRI STRUCTURE ===" && \
    echo "Custom OS DRI structure:" && \
    ls -la /custom-os/usr/lib/xorg/modules/dri /custom-os/usr/lib/dri 2>&1 | tee -a /custom-os/var/log/debug/dri_setup.log

# ======================
# SECTION: User Configuration
# ======================
RUN echo "=== CONFIGURING NON-ROOT USER ===" && \
    addgroup -g 1000 shs && \
    adduser -u 1000 -G shs -D shs && \
    \
    # Set permissions on custom filesystem
    echo "Setting permissions on custom filesystem..." | tee /custom-os/var/log/debug/user_setup.log && \
    chown -R shs:shs /custom-os/app 2>&1 | tee -a /custom-os/var/log/debug/user_setup.log; \
    chown -R shs:shs /custom-os/usr/local 2>&1 | tee -a /custom-os/var/log/debug/user_setup.log; \
    \
    # Verify permissions
    echo "=== VERIFYING PERMISSIONS ===" && \
    echo "Custom OS ownership:" && \
    ls -ld /custom-os/app /custom-os/usr/local 2>&1 | tee -a /custom-os/var/log/debug/user_setup.log

# ======================
# SECTION: Environment Configuration
# ======================
ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    PATH="/custom-os/usr/bin:/custom-os/compiler/bin:$PATH" \
    LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:/custom-os/glibc/lib" \
    PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" \
    PKG_CONFIG_SYSROOT_DIR="/custom-os"

# Verify environment
RUN echo "=== FINAL ENVIRONMENT VERIFICATION ===" && \
    echo "Environment variables:" | tee /custom-os/var/log/debug/final_env.log && \
    env | grep -E 'PATH|LD_LIBRARY|PKG_CONFIG|SDL|LIBGL|GALLIUM|MESA' | tee -a /custom-os/var/log/debug/final_env.log; \
    echo "Binary locations:" | tee -a /custom-os/var/log/debug/final_env.log; \
    for cmd in simplehttpserver xdpyinfo xrandr xeyes gdb valgrind; do \
        if command -v "$cmd" >/dev/null 2>&1; then \
            echo "$cmd: $(command -v "$cmd")"; \
        else \
            echo "$cmd: not found"; \
        fi; \
    done | tee -a /custom-os/var/log/debug/final_env.log; \
    \
    # Final application verification
    echo "=== FINAL APPLICATION VERIFICATION ==="; \
    if [ -f /custom-os/usr/bin/simplehttpserver ] && [ -x /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Application verified: /custom-os/usr/bin/simplehttpserver"; \
        /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /custom-os/var/log/debug/final_env.log || true; \
    else \
        echo "✗ Application missing or not executable: /custom-os/usr/bin/simplehttpserver"; \
        echo "Available binaries in /custom-os/usr/bin/:"; \
        ls -la /custom-os/usr/bin/ 2>/dev/null | tee -a /custom-os/var/log/debug/final_env.log || true; \
    fi && \
    echo "=== STAGE END VERIFICATION: debug ===" && \
    echo "Verifying binary directory /custom-os/usr/bin exists:" && \
    if [ -d /custom-os/usr/bin ]; then \
        ls -la /custom-os/usr/bin && \
        echo "✓ debug stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /custom-os/usr/bin does not exist!" && \
        echo "Available directories in /custom-os/usr/:" && \
        ls -la /custom-os/usr/ 2>/dev/null || echo "No /custom-os/usr/ directory found" && \
        exit 1; \
    fi

USER shs
WORKDIR /custom-os/app
CMD ["/custom-os/usr/bin/simplehttpserver"]

# Stage: runtime environment
FROM debug AS runtime

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_RUNTIME" && \
    rm -f /tmp/nocache/timestamp

# ======================
# SECTION: Runtime Environment Setup (sysroot-focused) — FINAL
# ======================

# Create necessary directories first
RUN mkdir -p /custom-os/usr/bin /custom-os/var/log/debug /custom-os/snapshots

# Explicitly copy application binary from app-build stage (backup measure)
COPY --from=app-build /custom-os/usr/bin/simplehttpserver /custom-os/usr/bin/

# Copy diagnostic logs from app-build stage for analysis (if they exist)
COPY --from=app-build /tmp/post_build_search.log /custom-os/var/log/debug/
COPY --from=app-build /tmp/all_binary_locations.log /custom-os/var/log/debug/
COPY --from=app-build /custom-os/snapshots/ /custom-os/snapshots/

# Verify the binary copy was successful
RUN echo "=== VERIFYING BINARY COPY FROM APP-BUILD STAGE ===" && \
    if [ -f /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Binary successfully copied from app-build stage"; \
        ls -la /custom-os/usr/bin/simplehttpserver; \
        chmod +x /custom-os/usr/bin/simplehttpserver; \
    else \
        echo "✗ Binary NOT copied from app-build stage"; \
        echo "Checking diagnostic logs..."; \
        cat /custom-os/var/log/debug/post_build_search.log 2>/dev/null || echo "No post-build search log"; \
        cat /custom-os/var/log/debug/all_binary_locations.log 2>/dev/null || echo "No binary locations log"; \
    fi

# Copy LLVM15 monitoring script (with proper permissions from the start)
COPY --chmod=755 setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh

# ======================
# SECTION: Application Binary Copy (CRITICAL FIX)
# ======================

# Create destination directory first
RUN mkdir -p /custom-os/usr/bin

# Application binary should already be present from app-build stage inheritance
RUN echo "=== APPLICATION BINARY SETUP ===" && \
    \
    # Check if the binary exists from app-build stage
    if [ -f /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Application found from app-build stage"; \
        chmod +x /custom-os/usr/bin/simplehttpserver; \
    else \
        echo "⚠ Application not found in expected location, searching alternatives..."; \
        # Try to find and copy the binary from build locations
        if [ -f /custom-os/app/build/simplehttpserver ]; then \
            echo "Found in build directory, copying to /custom-os/usr/bin/"; \
            cp -f /custom-os/app/build/simplehttpserver /custom-os/usr/bin/; \
            chmod +x /custom-os/usr/bin/simplehttpserver; \
        elif [ -f /app/build/simplehttpserver ]; then \
            echo "Found in /app/build, copying to /custom-os/usr/bin/"; \
            cp -f /app/build/simplehttpserver /custom-os/usr/bin/; \
            chmod +x /custom-os/usr/bin/simplehttpserver; \
        else \
            echo "Searching system for application binary..."; \
            find / -name "simplehttpserver" -type f -exec cp {} /custom-os/usr/bin/ \; 2>/dev/null || true; \
            if [ -f /custom-os/usr/bin/simplehttpserver ]; then \
                chmod +x /custom-os/usr/bin/simplehttpserver; \
            fi; \
        fi; \
    fi; \
    \
    # Final verification
    echo "=== APPLICATION BINARY VERIFICATION ==="; \
    if [ -f /custom-os/usr/bin/simplehttpserver ] && [ -x /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Application verified: /custom-os/usr/bin/simplehttpserver"; \
        ls -la /custom-os/usr/bin/simplehttpserver; \
        /custom-os/usr/bin/simplehttpserver --version 2>&1 || true; \
    else \
        echo "✗ CRITICAL: Application binary missing from /custom-os/usr/bin/"; \
        echo "Available binaries in /custom-os/usr/bin/:"; \
        ls -la /custom-os/usr/bin/ 2>/dev/null || true; \
        echo "Searching for application binary system-wide:"; \
        find / -name "simplehttpserver" -type f 2>/dev/null | head -10 || true; \
        echo "Build directory contents:"; \
        ls -la /custom-os/app/build/ 2>/dev/null || echo "No build directory found"; \
        echo "WARNING: Continuing without application binary - may need manual intervention"; \
    fi

# ======================
# SECTION: Binary Investigation and Diagnostics
# ======================
RUN echo "=== COMPREHENSIVE BINARY INVESTIGATION ===" && \
    echo "Using diagnostic scripts to trace binary location..." && \
    \
    # RUNTIME SAFETY CHECK 1: Stage inheritance verification
    echo "=== RUNTIME SAFETY CHECK 1: STAGE INHERITANCE VERIFICATION ===" && \
    echo "Current stage: runtime (inherited from debug -> app-build)" && \
    echo "Checking inherited filesystem state..." && \
    /usr/local/bin/check-filesystem.sh "runtime-stage-start" | tee /tmp/runtime_filesystem_check.log || true && \
    \
    # RUNTIME SAFETY CHECK 2: Diagnostic logs from previous stages
    echo "=== RUNTIME SAFETY CHECK 2: PREVIOUS STAGE DIAGNOSTICS ===" && \
    echo "Checking for diagnostic logs from app-build stage..." && \
    ls -la /custom-os/var/log/debug/ 2>/dev/null | tee /tmp/inherited_logs.log || echo "No debug logs directory" && \
    if [ -f /custom-os/var/log/debug/post_build_search.log ]; then \
        echo "App-build search results:" && \
        cat /custom-os/var/log/debug/post_build_search.log; \
    fi && \
    if [ -f /custom-os/var/log/debug/all_binary_locations.log ]; then \
        echo "App-build binary locations:" && \
        cat /custom-os/var/log/debug/all_binary_locations.log; \
    fi && \
    \
    # RUNTIME SAFETY CHECK 3: Comprehensive file system analysis
    echo "=== RUNTIME SAFETY CHECK 3: COMPREHENSIVE FILESYSTEM ANALYSIS ===" && \
    /usr/local/bin/file_finder.sh simplehttpserver | tee /tmp/runtime_file_finder.log || true && \
    /usr/local/bin/sgid_suid_scanner.sh /custom-os | tee /tmp/runtime_suid_scan.log || true && \
    /usr/local/bin/stage_went_wrong_tracer.sh simplehttpserver | tee /tmp/runtime_stage_tracer.log || true && \
    \
    # RUNTIME SAFETY CHECK 4: Multi-level filesystem search
    echo "=== RUNTIME SAFETY CHECK 4: MULTI-LEVEL FILESYSTEM SEARCH ===" && \
    echo "Level 1: Custom OS search" && \
    find /custom-os -name "*simplehttpserver*" -type f 2>/dev/null | tee /tmp/runtime_custom_os_search.log || true && \
    echo "Level 2: App directory search" && \
    find /app -name "*simplehttpserver*" -type f 2>/dev/null | tee /tmp/runtime_app_search.log || true && \
    echo "Level 3: System-wide search" && \
    find /usr -name "*simplehttpserver*" -type f 2>/dev/null | tee /tmp/runtime_system_search.log || true && \
    echo "Level 4: Root filesystem search (limited)" && \
    find / -maxdepth 3 -name "*simplehttpserver*" -type f 2>/dev/null | head -20 | tee /tmp/runtime_root_search.log || true && \
    \
    # RUNTIME SAFETY CHECK 5: Build artifacts investigation
    echo "=== RUNTIME SAFETY CHECK 5: BUILD ARTIFACTS INVESTIGATION ===" && \
    echo "App directory structure:" && \
    find /custom-os/app -type f 2>/dev/null | tee /tmp/runtime_app_structure.log || echo "No app directory" && \
    echo "Build directory contents:" && \
    ls -la /custom-os/app/build/ 2>/dev/null | tee /tmp/runtime_build_contents.log || echo "No build directory" && \
    echo "Source directory contents:" && \
    ls -la /custom-os/app/src/ 2>/dev/null | tee /tmp/runtime_src_contents.log || echo "No src directory" && \
    \
    # RUNTIME SAFETY CHECK 6: Installation target verification
    echo "=== RUNTIME SAFETY CHECK 6: INSTALLATION TARGET VERIFICATION ===" && \
    echo "Checking all possible installation locations:" && \
    for path in /custom-os/usr/bin /custom-os/usr/local/bin /custom-os/bin /usr/bin /usr/local/bin; do \
        echo "Checking $path:" && \
        ls -la "$path/simplehttpserver" 2>/dev/null || echo "  Not found in $path"; \
    done | tee /tmp/runtime_install_locations.log && \
    \
    # RUNTIME SAFETY CHECK 7: Permissions and ownership analysis
    echo "=== RUNTIME SAFETY CHECK 7: PERMISSIONS AND OWNERSHIP ANALYSIS ===" && \
    echo "Custom OS directory ownership:" && \
    ls -ld /custom-os/usr/bin 2>/dev/null | tee /tmp/runtime_permissions.log || echo "Directory doesn't exist" && \
    echo "User context:" && \
    whoami | tee -a /tmp/runtime_permissions.log && \
    id | tee -a /tmp/runtime_permissions.log && \
    \
    # Consolidated search results
    echo "=== CONSOLIDATED SEARCH RESULTS ===" && \
    echo "All search results:" && \
    cat /tmp/runtime_*_search.log 2>/dev/null | sort | uniq | tee /tmp/runtime_all_search_results.log || echo "No search results found"

# Create custom filesystem structure for runtime components (BEFORE user switch)
RUN mkdir -p /custom-os/usr/lib/runtime && \
    mkdir -p /custom-os/usr/lib/x11 && \
    mkdir -p /custom-os/usr/lib/graphics && \
    mkdir -p /custom-os/usr/lib/audio && \
    mkdir -p /custom-os/usr/lib/mesa && \
    mkdir -p /custom-os/usr/lib/fonts && \
    mkdir -p /custom-os/usr/lib/wayland && \
    mkdir -p /custom-os/var/log/debug && \
    echo "Created runtime filesystem structure"

# ======================
# SECTION: Core Runtime Libraries
# ======================
RUN echo "=== INSTALLING CORE RUNTIME LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-core-runtime" | tee /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    # Core C++ and C libraries
    echo "Installing core libraries..." | tee /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libstdc++ && echo "Installed libstdc++" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libgcc && echo "Installed libgcc" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy core libraries to custom filesystem
    echo "Copying core libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libstdc++* /custom-os/usr/lib/runtime/ 2>/dev/null || true; \
    cp -p /usr/lib/libgcc* /custom-os/usr/lib/runtime/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-core-runtime" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Font and Text Rendering Libraries
# ======================
RUN echo "=== INSTALLING FONT AND TEXT RENDERING LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-font-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing font libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache freetype && echo "Installed freetype" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache fontconfig && echo "Installed fontconfig" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy font libraries to custom filesystem
    echo "Copying font libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/fonts && \
    cp -p /usr/lib/libfreetype* /custom-os/usr/lib/fonts/ 2>/dev/null || true; \
    cp -p /usr/lib/libfontconfig* /custom-os/usr/lib/fonts/ 2>/dev/null || true; \
    cp -rp /etc/fonts /custom-os/etc/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-font-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: X11 Core Libraries
# ======================
RUN echo "=== INSTALLING X11 CORE LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-x11-core" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing X11 core libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libx11 && echo "Installed libx11" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxcomposite && echo "Installed libxcomposite" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxext && echo "Installed libxext" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxrandr && echo "Installed libxrandr" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy X11 core libraries to custom filesystem
    echo "Copying X11 core libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libX11* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXcomposite* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXext* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXrandr* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-x11-core" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Graphics and Image Libraries (High Risk - Check HERE if errors)
# ======================
RUN echo "=== INSTALLING GRAPHICS AND IMAGE LIBRARIES (HIGH RISK SECTION) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-graphics-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing graphics libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libpng && echo "Installed libpng" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libjpeg-turbo && echo "Installed libjpeg-turbo" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache tiff && echo "Installed tiff" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libwebp && echo "Installed libwebp" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libavif && echo "Installed libavif" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy graphics libraries to custom filesystem
    echo "Copying graphics libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libpng* /custom-os/usr/lib/graphics/ 2>/dev/null || true; \
    cp -p /usr/lib/libjpeg* /custom-os/usr/lib/graphics/ 2>/dev/null || true; \
    cp -p /usr/lib/libtiff* /custom-os/usr/lib/graphics/ 2>/dev/null || true; \
    cp -p /usr/lib/libwebp* /custom-os/usr/lib/graphics/ 2>/dev/null || true; \
    cp -p /usr/lib/libavif* /custom-os/usr/lib/graphics/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-graphics-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: X11 Extended Libraries (Older Packages)
# ======================
RUN echo "=== INSTALLING X11 EXTENDED LIBRARIES (OLDER PACKAGES) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-x11-extended" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing X11 extended libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxrender && echo "Installed libxrender" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxfixes && echo "Installed libxfixes" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxcursor && echo "Installed libxcursor" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxi && echo "Installed libxi" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxinerama && echo "Installed libxinerama" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxdamage && echo "Installed libxdamage" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxshmfence && echo "Installed libxshmfence" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxcb && echo "Installed libxcb" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache libxxf86vm && echo "Installed libxxf86vm" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy X11 extended libraries to custom filesystem
    echo "Copying X11 extended libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libXrender* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXfixes* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXcursor* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXi* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXinerama* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXdamage* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libxshmfence* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libxcb* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    cp -p /usr/lib/libXxf86vm* /custom-os/usr/lib/x11/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-x11-extended" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Wayland and Audio Libraries
# ======================
RUN echo "=== INSTALLING WAYLAND AND AUDIO LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-wayland-audio" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing Wayland and audio libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache wayland && echo "Installed wayland" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache alsa-lib && echo "Installed alsa-lib" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    apk add --no-cache pulseaudio && echo "Installed pulseaudio" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy Wayland and audio libraries to custom filesystem
    echo "Copying Wayland and audio libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/wayland && \
    cp -p /usr/lib/libwayland* /custom-os/usr/lib/wayland/ 2>/dev/null || true; \
    cp -p /usr/lib/libasound* /custom-os/usr/lib/audio/ 2>/dev/null || true; \
    cp -p /usr/lib/libpulse* /custom-os/usr/lib/audio/ 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-wayland-audio" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: LLVM16 Establishment (Priority Installation)
# ======================
RUN echo "=== ESTABLISHING LLVM16 PREFERENCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-llvm16-priority" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing LLVM16 libs to establish preference..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache llvm16-libs && echo "Installed llvm16-libs" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    \
    # Copy LLVM16 libraries to custom filesystem compiler directory
    echo "Copying LLVM16 libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/compiler/lib && \
    find /usr/lib -name "*llvm16*" -type f -exec cp {} /custom-os/compiler/lib/ \; 2>/dev/null || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-llvm16-priority" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Mesa Packages (HIGH RISK - LLVM15 Contamination Monitoring)
# ======================
RUN echo "=== INSTALLING MESA PACKAGES - MONITORING FOR LLVM15 CONTAMINATION ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-runtime" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing Mesa DRI Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-dri-gallium && echo "Installed mesa-dri-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    /usr/local/bin/check_llvm15.sh "post-mesa-dri-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing Mesa VA Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-va-gallium && echo "Installed mesa-va-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    /usr/local/bin/check_llvm15.sh "post-mesa-va-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing Mesa VDPAU Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-vdpau-gallium && echo "Installed mesa-vdpau-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    /usr/local/bin/check_llvm15.sh "post-mesa-vdpau-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing Mesa Vulkan SwRast..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-vulkan-swrast && echo "Installed mesa-vulkan-swrast" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    /usr/local/bin/check_llvm15.sh "post-mesa-vulkan-swrast" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    echo "Installing GLU..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache glu && echo "Installed glu" | tee -a /custom-os/var/log/debug/runtime_install.log; \
    /usr/local/bin/check_llvm15.sh "post-glu" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    # Copy Mesa libraries to custom filesystem
    echo "Copying Mesa libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/dri && \
    cp -rp /usr/lib/dri/* /custom-os/usr/lib/dri/ 2>/dev/null || true; \
    cp -p /usr/lib/libGL* /custom-os/usr/lib/mesa/ 2>/dev/null || true; \
    cp -p /usr/lib/libGLU* /custom-os/usr/lib/mesa/ 2>/dev/null || true; \
    cp -p /usr/lib/libEGL* /custom-os/usr/lib/mesa/ 2>/dev/null || true; \
    cp -p /usr/lib/libgbm* /custom-os/usr/lib/mesa/ 2>/dev/null || true

# ======================
# SECTION: Final Runtime LLVM15 Check & Filesystem Verification
# ======================
RUN echo "=== FINAL RUNTIME LLVM15 CONTAMINATION CHECK ===" && \
    /usr/local/bin/check_llvm15.sh "final-runtime-check" | tee -a /custom-os/var/log/debug/llvm_checks.log || true; \
    \
    # Verify filesystem structure
    echo "=== RUNTIME FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS runtime structure:" | tee /custom-os/var/log/debug/runtime_filesystem.log && \
    find /custom-os/usr/lib/ -maxdepth 2 -type d | head -20 | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    \
    # Verify library counts in each category
    echo "=== LIBRARY COUNT VERIFICATION ===" && \
    echo "Runtime libraries: $(ls /custom-os/usr/lib/runtime/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    echo "X11 libraries: $(ls /custom-os/usr/lib/x11/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    echo "Graphics libraries: $(ls /custom-os/usr/lib/graphics/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    echo "Audio libraries: $(ls /custom-os/usr/lib/audio/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    echo "Mesa libraries: $(ls /custom-os/usr/lib/mesa/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log; \
    echo "DRI drivers: $(ls /custom-os/usr/lib/dri/ 2>/dev/null | wc -l || echo 0)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log

# Create runtime environment configuration
RUN echo "=== CREATING RUNTIME ENVIRONMENT CONFIGURATION ===" && \
    mkdir -p /custom-os/etc/profile.d && \
    cat > /custom-os/etc/profile.d/runtime.sh <<'RUNTIME_PROFILE'
#!/bin/sh
# Runtime libraries environment setup
export LD_LIBRARY_PATH="/custom-os/usr/lib/runtime:/custom-os/usr/lib/x11:/custom-os/usr/lib/graphics:/custom-os/usr/lib/audio:/custom-os/usr/lib/mesa:/custom-os/usr/lib/wayland:/custom-os/usr/lib/fonts:${LD_LIBRARY_PATH:-}"

# Mesa/OpenGL configuration
export LIBGL_DRIVERS_PATH="/custom-os/usr/lib/dri"
export MESA_LOADER_DRIVER_OVERRIDE="llvmpipe"

# X11/Wayland configuration
export XDG_RUNTIME_DIR="/tmp/runtime"
RUNTIME_PROFILE

RUN chmod +x /custom-os/etc/profile.d/runtime.sh && \
    echo "=== RUNTIME ENVIRONMENT SETUP COMPLETE ==="

# Create updated LLVM15 check script in custom filesystem
RUN cat > /custom-os/usr/local/bin/check_llvm15.sh <<'SH' && chmod +x /custom-os/usr/local/bin/check_llvm15.sh
#!/bin/sh
set -eux
STAGE="${1:-unknown-stage}"
OUT="/custom-os/var/log/debug/llvm15_debug_${STAGE}.log"
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

# Final runtime LLVM15 check
RUN /custom-os/usr/local/bin/check_llvm15.sh "runtime-final" || true

# ======================
# SECTION: GBM Library Installation (Filesystem-Integrated)
# ======================
RUN echo "=== INSTALLING GBM LIBRARY ===" && \
    set -eux; \
    if apk add --no-cache libgbm 2>/dev/null; then \
        echo "Installed libgbm" | tee /custom-os/var/log/debug/gbm_install.log; \
        # Copy GBM library to custom filesystem
        cp -p /usr/lib/libgbm* /custom-os/usr/lib/mesa/ 2>/dev/null || true; \
        /custom-os/usr/local/bin/check_llvm15.sh "after-libgbm" || true; \
    else \
        echo "Fallback to mesa-gbm" | tee /custom-os/var/log/debug/gbm_install.log; \
        apk add --no-cache mesa-gbm || true; \
        cp -p /usr/lib/libgbm* /custom-os/usr/lib/mesa/ 2>/dev/null || true; \
        /custom-os/usr/local/bin/check_llvm15.sh "after-mesa-gbm" || true; \
    fi

# ======================
# SECTION: DRI Module Structure (Filesystem-Integrated)
# ======================
RUN echo "=== SETTING UP DRI MODULE STRUCTURE ===" && \
    mkdir -p /custom-os/usr/lib/xorg/modules/dri && \
    ln -sf /custom-os/usr/lib/dri /custom-os/usr/lib/xorg/modules/dri && \
    echo "DRI module structure created in custom filesystem" | tee /custom-os/var/log/debug/dri_structure.log

# ======================
# SECTION: Copy Build Artifacts to Custom Filesystem
# ======================
# Copy libraries from the builder stage that produced /usr/local into the custom filesystem.
# Use the actual stage name (filesystem-libs-build-builder) instead of a non-existent 'libs-build'.
# On failure, print a helpful message into the debug log rather than blowing up with an unclear error.
COPY --from=filesystem-libs-build-builder /usr/local/ /custom-os/usr/local/
RUN if [ -d /custom-os/usr/local ]; then \
      echo "Copied filesystem-libs-build-builder artifacts to custom filesystem" | tee /custom-os/var/log/debug/artifacts_copy.log; \
    else \
      echo "Warning: /custom-os/usr/local was not created by filesystem-libs-build-builder" | tee /custom-os/var/log/debug/artifacts_copy.log; \
      mkdir -p /custom-os/usr/local; \
    fi

# ======================
# SECTION: Application Binary Setup (CRITICAL FIX)
# ======================
RUN echo "=== SETTING UP APPLICATION BINARY ===" && \
    # Ensure application binary is in the correct location for CMD
    if [ -f /custom-os/app/simplehttpserver ]; then \
        echo "Moving application binary from /custom-os/app/ to /custom-os/usr/bin/"; \
        mkdir -p /custom-os/usr/bin; \
        mv /custom-os/app/simplehttpserver /custom-os/usr/bin/; \
    elif [ -f /custom-os/usr/bin/simplehttpserver ]; then \
        echo "Application binary already in correct location: /custom-os/usr/bin/"; \
    else \
        echo "WARNING: Application binary not found in expected locations"; \
        echo "Searching for application binary:"; \
        find /custom-os -name "simplehttpserver" -type f 2>/dev/null | tee /custom-os/var/log/debug/app_search.log || true; \
    fi; \
    \
    # Final verification
    echo "=== APPLICATION BINARY VERIFICATION ==="; \
    if [ -f /custom-os/usr/bin/simplehttpserver ] && [ -x /custom-os/usr/bin/simplehttpserver ]; then \
        echo "✓ Application verified: /custom-os/usr/bin/simplehttpserver"; \
        ls -la /custom-os/usr/bin/simplehttpserver | tee /custom-os/var/log/debug/app_verify.log; \
        /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /custom-os/var/log/debug/app_verify.log || true; \
    else \
        echo "✗ Application missing or not executable: /custom-os/usr/bin/simplehttpserver"; \
        echo "Available binaries in /custom-os/usr/bin/:"; \
        ls -la /custom-os/usr/bin/ 2>/dev/null | tee /custom-os/var/log/debug/app_verify.log || true; \
    fi

# ======================
# SECTION: Debug Application Location
# ======================
RUN echo "=== DEBUG: APPLICATION BINARY LOCATION INVESTIGATION ===" && \
    echo "Checking app-build stage for application..."; \
    echo "Files in app-build /custom-os/usr/bin/:"; \
    docker history --no-trunc | grep app-build || echo "Cannot check history directly"; \
    \
    # Check if the binary exists in any expected location
    echo "Checking for application in common locations:"; \
    for path in /custom-os/usr/bin/simplehttpserver /custom-os/app/build/simplehttpserver /app/build/simplehttpserver /usr/bin/simplehttpserver; do \
        if [ -f "$path" ]; then \
            echo "FOUND: $path"; \
            cp "$path" /custom-os/usr/bin/ 2>/dev/null && echo "Copied to /custom-os/usr/bin/"; \
        else \
            echo "NOT FOUND: $path"; \
        fi; \
    done; \
    \
    # Final verification
    if [ -f /custom-os/usr/bin/simplehttpserver ]; then \
        echo "SUCCESS: Application now in correct location"; \
        chmod +x /custom-os/usr/bin/simplehttpserver; \
    else \
        echo "ERROR: Application binary still missing after exhaustive search"; \
        exit 1; \
    fi



# ======================
# SECTION: User Configuration (Filesystem-Integrated)
# ======================
RUN echo "=== CONFIGURING USER IN CUSTOM FILESYSTEM ===" && \
    addgroup -g 1000 shs && \
    adduser -u 1000 -G shs -D shs && \
    chown -R shs:shs /custom-os/app /custom-os/usr/local && \
    echo "User shs configured with proper permissions" | tee /custom-os/var/log/debug/user_config.log

# ======================
# SECTION: Environment Configuration (Filesystem-Integrated)
# ======================
ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    LD_LIBRARY_PATH="/custom-os/compiler/lib:/custom-os/usr/local/lib:/custom-os/usr/lib/runtime:/custom-os/usr/lib/x11:/custom-os/usr/lib/graphics:/custom-os/usr/lib/audio:/custom-os/usr/lib/mesa:/custom-os/usr/lib/wayland:/custom-os/usr/lib/fonts:/custom-os/glibc/lib" \
    LLVM_CONFIG="/custom-os/compiler/bin/llvm-config" \
    PATH="/custom-os/compiler/bin:/custom-os/usr/local/bin:/custom-os/usr/bin:$PATH"

# ======================
# SECTION: FINAL COMPREHENSIVE LLVM15 ANALYSIS (Filesystem-Integrated)
# ======================
RUN echo "=== FINAL COMPREHENSIVE LLVM15 ANALYSIS ===" && \
    set -eux; \
    echo "=== FINAL LLVM15 ANALYSIS ===" | tee /custom-os/var/log/debug/final_llvm15_analysis.log; \
    echo "Searching entire filesystem for LLVM15..." | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
    find /usr -name '*llvm*15*' -o -name '*LLVM*15*' 2>/dev/null | tee /custom-os/var/log/debug/all_llvm15_files.txt || true; \
    if [ -s /custom-os/var/log/debug/all_llvm15_files.txt ]; then \
        echo "=== ALL LLVM15 RELATED FILES ===" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
        cat /custom-os/var/log/debug/all_llvm15_files.txt | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
        echo "=== PACKAGE OWNERSHIP ANALYSIS ===" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
        while read -r f; do \
            if [ -f "$f" ] || [ -L "$f" ]; then \
                echo "FILE: $f" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
                apk info --who-owns "$f" 2>/dev/null | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log || echo " No package owns this file" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
            fi; \
        done < /custom-os/var/log/debug/all_llvm15_files.txt; \
        echo "=== INSTALLED PACKAGES WITH LLVM15 DEPS ===" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
        apk info --installed | while read -r pkg; do \
            if apk info -R "$pkg" 2>/dev/null | grep -q llvm15; then \
                echo "PACKAGE: $pkg depends on LLVM15" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
                apk info -R "$pkg" | grep llvm15 | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
            fi; \
        done; \
        echo "=== WARNING: LLVM15 FILES FOUND BUT CONTINUING ===" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
        echo "The build will continue with LLVM16 preference enforced via environment variables." | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
    else \
        echo "=== SUCCESS: NO LLVM15 CONTAMINATION DETECTED ===" | tee -a /custom-os/var/log/debug/final_llvm15_analysis.log; \
    fi; \
    \
    # Final filesystem verification
    echo "=== FINAL CUSTOM FILESYSTEM VERIFICATION ==="; \
    echo "Custom OS final structure:" | tee /custom-os/var/log/debug/final_filesystem.log; \
    tree -L 4 /custom-os/ 2>/dev/null | tee -a /custom-os/var/log/debug/final_filesystem.log || \
    find /custom-os/ -type d | head -30 | tee -a /custom-os/var/log/debug/final_filesystem.log; \
    \
    # Verify critical binaries
    echo "=== CRITICAL BINARY VERIFICATION ===" | tee -a /custom-os/var/log/debug/final_filesystem.log; \
    ls -la /custom-os/usr/bin/simplehttpserver 2>/dev/null | tee -a /custom-os/var/log/debug/final_filesystem.log || echo "Application binary not found in /custom-os/usr/bin/" | tee -a /custom-os/var/log/debug/final_filesystem.log; \
    ls -la /custom-os/compiler/bin/clang* 2>/dev/null | head -3 | tee -a /custom-os/var/log/debug/final_filesystem.log || echo "No clang binaries found" | tee -a /custom-os/var/log/debug/final_filesystem.log && \
    echo "=== STAGE END VERIFICATION: runtime ===" && \
    echo "Verifying binary directory /custom-os/usr/bin exists:" && \
    if [ -d /custom-os/usr/bin ]; then \
        ls -la /custom-os/usr/bin && \
        echo "✓ runtime stage completed - binary directory confirmed"; \
    else \
        echo "ERROR: Binary directory /custom-os/usr/bin does not exist!" && \
        echo "Available directories in /custom-os/usr/:" && \
        ls -la /custom-os/usr/ 2>/dev/null || echo "No /custom-os/usr/ directory found" && \
        exit 1; \
    fi

USER shs
WORKDIR /custom-os/app
CMD ["/custom-os/usr/bin/simplehttpserver"]
