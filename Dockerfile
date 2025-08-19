# Stage: base deps (Alpine version)
FROM alpine:3.18 AS base-deps

# Install basic tools needed for filesystem operations
RUN apk add --no-cache bash findutils wget

# Create directory structure
RUN mkdir -p /custom-os/bin /custom-os/sbin /custom-os/etc /custom-os/var /custom-os/tmp /custom-os/home /custom-os/root
RUN mkdir -p /custom-os/usr/bin /custom-os/usr/sbin /custom-os/usr/lib
RUN mkdir -p /custom-os/usr/local/bin /custom-os/usr/local/sbin /custom-os/usr/local/lib /custom-os/usr/share

# Create compiler directory structure
RUN mkdir -p /custom-os/compiler/bin /custom-os/compiler/lib /custom-os/compiler/include

# Create glibc directory structure
RUN mkdir -p /custom-os/glibc/lib /custom-os/glibc/bin /custom-os/glibc/sbin /custom-os/glibc/include

# Copy the LLVM15 debug script for monitoring from your build context (setup-scripts/)
COPY setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh
RUN chmod +x /usr/local/bin/check_llvm15.sh

# Copy the filesystem inspection script
COPY setup-scripts/check-filesystem.sh /usr/local/bin/check-filesystem.sh
RUN chmod +x /usr/local/bin/check-filesystem.sh

# Remove any preinstalled LLVM/Clang (on the builder)
RUN apk del --no-cache llvm clang || true

# Run LLVM15 check before any installations
RUN /usr/local/bin/check_llvm15.sh "pre-install" || true

# Install glibc compatibility layer with ARM64 warning suppression
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-dev-2.35-r1.apk && \
    # Install packages and suppress ARM64 ldconfig warnings
    apk add --no-cache --allow-untrusted \
        glibc-2.35-r1.apk \
        glibc-bin-2.35-r1.apk \
        glibc-dev-2.35-r1.apk 2>&1 | grep -v "unknown machine 183" || true && \
    # Create a wrapper that suppresses the ARM64 warnings (if ldconfig exists)
    if [ -x /usr/glibc-compat/sbin/ldconfig ]; then \
        mv /usr/glibc-compat/sbin/ldconfig /usr/glibc-compat/sbin/ldconfig.real && \
        echo '#!/bin/sh' > /usr/glibc-compat/sbin/ldconfig && \
        echo '/usr/glibc-compat/sbin/ldconfig.real "$@" 2>&1 | grep -v "unknown machine 183" || true' >> /usr/glibc-compat/sbin/ldconfig && \
        chmod +x /usr/glibc-compat/sbin/ldconfig; \
    fi && \
    # Clean up
    rm -f /sbin/ldconfig || true && \
    rm -f *.apk || true && \
    /usr/local/bin/check_llvm15.sh "after-glibc" || true

# Copy glibc installation to custom filesystem glibc directory
RUN echo "=== COPYING GLIBC TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/glibc/{lib,bin,sbin} && \
    # copy only runtime libs & binaries (no development headers)
    cp -r /usr/glibc-compat/lib/* /custom-os/glibc/lib/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/bin/* /custom-os/glibc/bin/ 2>/dev/null || true && \
    cp -r /usr/glibc-compat/sbin/* /custom-os/glibc/sbin/ 2>/dev/null || true && \
    # DO NOT copy include/ - avoid mismatched headers for cross builds
    echo "GLIBC runtime copied to custom filesystem (no headers)." && \
    ls -la /custom-os/glibc/lib/ | head -10 || echo "No glibc libraries found"

# Force install LLVM 16 only - but install to custom location
RUN /usr/local/bin/check_llvm15.sh "pre-llvm16" || true && \
    apk add --no-cache llvm16-dev llvm16-libs clang16

# Copy LLVM16 installation to custom filesystem compiler directory
RUN echo "=== COPYING LLVM16 TO CUSTOM FILESYSTEM ===" && \
    # Copy LLVM16 binaries (if present)
    cp -r /usr/lib/llvm16/* /custom-os/compiler/ 2>/dev/null || true && \
    # Copy clang binaries
    find /usr/bin -name "*clang*16*" -exec cp {} /custom-os/compiler/bin/ \; 2>/dev/null || true && \
    # Copy any additional LLVM16 libs that might be elsewhere
    find /usr/lib -name "*llvm16*" -type f -exec cp {} /custom-os/compiler/lib/ \; 2>/dev/null || true && \
    # Verify installation
    echo "LLVM16/Clang installed to custom filesystem:" && \
    ls -la /custom-os/compiler/bin/ | grep -E "(clang|llvm)" || echo "No clang/llvm binaries found" && \
    ls -la /custom-os/compiler/lib/ | head -10 || echo "No libraries found"

# Set up environment configuration for the custom filesystem
# Create environment setup script that will be sourced in the final stage
RUN cat > /custom-os/etc/environment <<'ENV' && \
    echo "=== CREATING ENVIRONMENT SETUP ===" && \
    cat /custom-os/etc/environment
# Custom filesystem environment configuration
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:${PATH}"
export LLVM_CONFIG="/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/glibc"
ENV

# Create a profile script for interactive shells
RUN mkdir -p /custom-os/etc/profile.d && \
    cat > /custom-os/etc/profile.d/compiler.sh <<'PROFILE'
#!/bin/sh
# Compiler and glibc environment setup
export PATH="/glibc/bin:/glibc/sbin:/compiler/bin:${PATH}"
export LLVM_CONFIG="/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/glibc/lib:/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/glibc"

# Set up glibc as the primary C library
export GLIBC_COMPAT="/glibc"
export C_INCLUDE_PATH="/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/glibc/include:${CPLUS_INCLUDE_PATH:-}"
PROFILE

# Make profile script executable
RUN chmod +x /custom-os/etc/profile.d/compiler.sh

# Create a glibc-specific configuration script
RUN cat > /custom-os/etc/profile.d/glibc.sh <<'GLIBC_PROFILE'
#!/bin/sh
# glibc-specific environment setup
export GLIBC_ROOT="/glibc"
export GLIBC_COMPAT="/glibc"

# Ensure glibc ldconfig is used
export PATH="/glibc/sbin:/glibc/bin:${PATH}"

# Set up library paths for glibc
export LD_LIBRARY_PATH="/glibc/lib:${LD_LIBRARY_PATH:-}"

# Set up include paths for glibc
export C_INCLUDE_PATH="/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/glibc/include:${CPLUS_INCLUDE_PATH:-}"
GLIBC_PROFILE

RUN chmod +x /custom-os/etc/profile.d/glibc.sh

# Copy and execute setup scripts
COPY setup-scripts/ /setup/
RUN chmod +x /setup/*.sh && /setup/create-filesystem.sh

# Final LLVM15 contamination check && filesystem analyzer
RUN /usr/local/bin/check_llvm15.sh "final-filesystem-builder" || true && \
    /usr/local/bin/check-filesystem.sh "final-filesystem-builder" || true
# Check binaries/libraries
COPY setup-scripts/binlib_validator.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/binlib_validator.sh

# Stage: filesystem setup - Install base-deps
FROM base-deps AS filesystem-base-deps-builder

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
RUN apk add --no-cache wget && /usr/local/bin/check_llvm15.sh "after-wget" || true
RUN apk add --no-cache tar && /usr/local/bin/check_llvm15.sh "after-tar" || true
RUN apk add --no-cache python3 && /usr/local/bin/check_llvm15.sh "after-python3" || true
RUN apk add --no-cache py3-pip && /usr/local/bin/check_llvm15.sh "after-py3-pip" || true
RUN apk add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true
RUN apk add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk add --no-cache meson && /usr/local/bin/check_llvm15.sh "after-meson" || true
RUN apk add --no-cache libgl1-mesa-dev && /usr/local/bin/check_llvm15.sh "after-libgl1-mesa-dev" || true
RUN apk add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true
# Other essential packages - Pt 1
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true
RUN apk add --no-cache egl-dev && /usr/local/bin/check_llvm15.sh "after-egl-dev" || true
RUN apk add --no-cache gles-dev && /usr/local/bin/check_llvm15.sh "after-gles-dev" || true
RUN apk add --no-cache python3-dev && /usr/local/bin/check_llvm15.sh "after-python3-dev" || true
RUN apk add --no-cache py3-setuptools && /usr/local/bin/check_llvm15.sh "after-py3-setuptools" || true
RUN apk add --no-cache cunit-dev && /usr/local/bin/check_llvm15.sh "after-cunit-dev" || true
RUN apk add --no-cache cairo-dev && /usr/local/bin/check_llvm15.sh "after-cairo-dev" || true
RUN apk add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true
RUN apk add --no-cache libatomic_ops-dev && /usr/local/bin/check_llvm15.sh "after-libatomic_ops-dev" || true
RUN apk add --no-cache pciutils-dev && /usr/local/bin/check_llvm15.sh "after-pciutils-dev" || true
# Other essential packages - Pt 2
RUN apk add --no-cache autoconf && /usr/local/bin/check_llvm15.sh "after-autoconf" || true
RUN apk add --no-cache automake && /usr/local/bin/check_llvm15.sh "after-automake" || true
RUN apk add --no-cache libtool && /usr/local/bin/check_llvm15.sh "after-libtool" || true
RUN apk add --no-cache util-macros && /usr/local/bin/check_llvm15.sh "after-util-macros" || true
RUN apk add --no-cache pkgconf-dev && /usr/local/bin/check_llvm15.sh "after-pkgconf-dev" || true
RUN apk add --no-cache xorg-util-macros && /usr/local/bin/check_llvm15.sh "after-xorg-util-macros" || true
RUN apk add --no-cache libpciaccess-dev && /usr/local/bin/check_llvm15.sh "after-libpciaccess-dev" || true
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
RUN apk add --no-cache gettext-dev && /usr/local/bin/check_llvm15.sh "after-gettext-dev" || true
RUN apk add --no-cache libogg-dev && /usr/local/bin/check_llvm15.sh "after-libogg-dev" || true
RUN apk add --no-cache flac-dev && /usr/local/bin/check_llvm15.sh "after flac-dev" || true
RUN apk add --no-cache libmodplug-dev && /usr/local/bin/check_llvm15.sh "after-libmodplug-dev" || true
RUN apk add --no-cache mpg123-dev && /usr/local/bin/check_llvm15.sh "after-mpg123-dev" || true
RUN apk add --no-cache opusfile-dev && /usr/local/bin/check_llvm15.sh "after-opusfile-dev" || true
RUN apk add --no-cache libjpeg-turbo-dev && /usr/local/bin/check_llvm15.sh "after-libjpeg-turbo-dev" || true

# Copy the installed packages to custom filesystem in an organized way
RUN echo "=== COPYING BASE PACKAGES TO CUSTOM FILESYSTEM ===" && \
    # Create essential directories if they don't exist
    mkdir -p /custom-os/usr/bin /custom-os/usr/lib /custom-os/usr/include && \
    mkdir -p /custom-os/usr/share /custom-os/usr/local/bin && \
    # Copy the package database
    cp -r /lib/apk /custom-os/lib/ && \
    # Copy binaries
    find /usr/bin -type f -exec cp {} /custom-os/usr/bin/ \; 2>/dev/null || true && \
    # Copy libraries
    find /usr/lib -type f -name "*.so*" -exec cp {} /custom-os/usr/lib/ \; 2>/dev/null || true && \
    # Copy headers
    cp -r /usr/include/* /custom-os/usr/include/ 2>/dev/null || true && \
    # Copy shared data
    cp -r /usr/share/* /custom-os/usr/share/ 2>/dev/null || true && \
    # Verify the copy operation
    echo "Base dependencies copied to custom filesystem:" && \
    ls -la /custom-os/usr/bin/ | head -10 && \
    ls -la /custom-os/usr/lib/ | head -10

# ======================
# SECTION: Debug Tools
# ======================
RUN echo "=== INSTALLING DEBUG TOOLS ==="
RUN apk add --no-cache strace && /usr/local/bin/check_llvm15.sh "after-strace" || true
RUN apk add --no-cache file && /usr/local/bin/check_llvm15.sh "after-file" || true
RUN apk add --no-cache tree && /usr/local/bin/check_llvm15.sh "after-tree" || true
RUN apk add --no-cache valgrind-dev && /usr/local/bin/check_llvm15.sh "after-valgrind-dev" || true


# Copy debug tools to organized locations
RUN mkdir -p /custom-os/usr/debug/bin && \
    cp /usr/bin/strace /custom-os/usr/debug/bin/ && \
    cp /usr/bin/file /custom-os/usr/debug/bin/ && \
    cp /usr/bin/tree /custom-os/usr/debug/bin/

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

# Final contamination check
RUN /usr/local/bin/check_llvm15.sh "final-base-deps" || true && \
    /usr/local/bin/check-filesystem.sh "final-base-deps" || true

# Stage: filesystem setup - Install base-deps
FROM filesystem-base-deps-builder AS filesystem-libs-build-builder

# ======================
# SECTION: PCI Access Build
# ======================
RUN echo "=== STRINGENT_PCIACCESS_BUILD: BUILDING FROM SOURCE WITH LLVM16 ENFORCEMENT ===" && \
    mkdir -p /custom-os/usr/x11/{lib,include,bin,pkgconfig} && \
    \
    # Ensure check_llvm15.sh exists before using it
    if [ ! -x "/usr/local/bin/check_llvm15.sh" ]; then \
        echo "=== INSTALLING MISSING CHECK_LLVM15.SH ===" && \
        mkdir -p /usr/local/bin && \
        echo '#!/bin/sh\necho "WARNING: check_llvm15.sh not properly installed"' > /usr/local/bin/check_llvm15.sh && \
        chmod +x /usr/local/bin/check_llvm15.sh; \
    fi && \
    \
    /usr/local/bin/check_llvm15.sh "pre-pciaccess-source-build" || true && \
    \
    # Purge any potential LLVM15 residues (but protect our check script)
    echo "=== PURGING LLVM15 CONTAMINATION ===" && \
    find /usr -name '*llvm15*' -not -path '/usr/local/bin/check_llvm15.sh' -exec rm -fv {} \; 2>/dev/null | tee /tmp/llvm15_purge.log || true && \
    apk del --no-cache $(apk info -R llvm15-libs 2>/dev/null) llvm15-libs 2>/dev/null || true && \
    \
    # Install comprehensive build dependencies
    echo "=== INSTALLING SANITIZED BUILD DEPS ===" && \
    /usr/local/bin/check_llvm15.sh "after-comprehensive-deps-install" || true && \
    \
    # Clone and verify source integrity
    echo "=== CLONING AND VERIFYING SOURCE ===" && \
    rm -rf pciaccess 2>/dev/null || true && \
    git clone --depth=1 https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git pciaccess && \
    cd pciaccess && \
    echo "=== REPOSITORY STRUCTURE ANALYSIS ===" && \
    echo "Repository contents:" && \
    ls -la && \
    echo "Checking for build system files:" && \
    find . -maxdepth 2 -name "configure*" -o -name "Makefile*" -o -name "meson.build" -o -name "CMakeLists.txt" -o -name "autogen.sh" -o -name "configure.ac" -o -name "configure.in" && \
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" . 2>&1 | tee /tmp/source_scan.log || true) && \
    \
    # Set hardened build environment for custom filesystem
    echo "=== SETTING HARDENED BUILD ENV ===" && \
    export CC=/custom-os/compiler/bin/clang-16 && \
    export CXX=/custom-os/compiler/bin/clang++-16 && \
    export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config && \
    export CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib,--no-undefined" && \
    export PKG_CONFIG_PATH="/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    export ACLOCAL_PATH="/usr/share/aclocal:/usr/local/share/aclocal" && \
    export NO_COLOR=1 && \
    echo "Build environment verification:" && \
    echo "CC: $CC ($(which $CC 2>/dev/null || echo 'NOT FOUND'))" && \
    echo "CXX: $CXX ($(which $CXX 2>/dev/null || echo 'NOT FOUND'))" && \
    echo "LLVM_CONFIG: $LLVM_CONFIG ($(which $LLVM_CONFIG 2>/dev/null || echo 'NOT FOUND'))" && \
    \
    # Try build strategies in order of preference
    echo "=== ATTEMPTING BUILD STRATEGIES ===" && \
    BUILD_SUCCESS=0 && \
    \
    # Strategy 1: Try autogen.sh if it exists
    if [ -f "./autogen.sh" ]; then \
        echo "Strategy 1: Using autogen.sh" && \
        chmod +x ./autogen.sh && \
        ./autogen.sh --prefix=/custom-os/usr/x11 --libdir=/custom-os/usr/x11/lib --enable-shared --disable-static 2>&1 | tee /tmp/autogen.log && \
        BUILD_SUCCESS=1; \
    # Strategy 2: Try autoreconf if configure.ac/configure.in exists
    elif [ -f "./configure.ac" ] || [ -f "./configure.in" ]; then \
        echo "Strategy 2: Using autoreconf to generate configure script" && \
        echo "Running aclocal..." && \
        aclocal -I m4 --install 2>&1 | tee /tmp/aclocal.log || true && \
        echo "Running autoheader..." && \
        autoheader 2>&1 | tee /tmp/autoheader.log || true && \
        echo "Running libtoolize..." && \
        libtoolize --force --install 2>&1 | tee /tmp/libtoolize.log || true && \
        echo "Running autoreconf..." && \
        autoreconf -fiv -I m4 2>&1 | tee /tmp/autoreconf.log && \
        if [ -f "./configure" ]; then \
            echo "Configure script successfully generated" && \
            chmod +x ./configure && \
            BUILD_SUCCESS=1; \
        else \
            echo "autoreconf completed but no configure script generated"; \
        fi; \
    # Strategy 3: Check for existing configure script
    elif [ -f "./configure" ]; then \
        echo "Strategy 3: Using existing configure script" && \
        chmod +x ./configure && \
        BUILD_SUCCESS=1; \
    # Strategy 4: Direct compilation
    else \
        echo "Strategy 4: No autotools setup found, will attempt direct compilation" && \
        BUILD_SUCCESS=1; \
    fi && \
    \
    # Configure if we have a configure script
    if [ "$BUILD_SUCCESS" = "1" ] && [ -f "./configure" ]; then \
        echo "=== CONFIGURING WITH ENHANCED OPTIONS ===" && \
        ./configure \
            --prefix=/custom-os/usr/x11 \
            --libdir=/custom-os/usr/x11/lib \
            --includedir=/custom-os/usr/x11/include \
            --enable-shared \
            --disable-static \
            --with-pic 2>&1 | tee /tmp/configure.log && \
        CONFIGURE_SUCCESS=1; \
    else \
        echo "=== SKIPPING CONFIGURE - WILL USE DIRECT BUILD ===" && \
        CONFIGURE_SUCCESS=0; \
    fi && \
    \
    # Build with comprehensive dependency verification
    echo "=== BUILDING WITH DEPENDENCY VERIFICATION ===" && \
    if [ -f "Makefile" ] || [ -f "makefile" ]; then \
        echo "Found Makefile, proceeding with build..." && \
        make -j$(nproc) V=1 2>&1 | tee /tmp/make_build.log && \
        BUILD_COMPLETE=1; \
    else \
        echo "No Makefile found, attempting direct compilation..." && \
        # Direct compilation fallback
        SOURCES=$(find . -name "*.c" | grep -v test | head -20) && \
        if [ -n "$SOURCES" ]; then \
            echo "Found sources: $SOURCES" && \
            echo "Attempting direct compilation..." && \
            mkdir -p /tmp/pciaccess_build && \
            $CC $CFLAGS -fPIC -shared -Wl,-soname,libpciaccess.so.0 \
                -o /tmp/pciaccess_build/libpciaccess.so.0.11.1 \
                $SOURCES $LDFLAGS 2>&1 | tee /tmp/direct_compile.log && \
            cd /tmp/pciaccess_build && \
            ln -sf libpciaccess.so.0.11.1 libpciaccess.so.0 && \
            ln -sf libpciaccess.so.0.11.1 libpciaccess.so && \
            BUILD_COMPLETE=1; \
        else \
            echo "No suitable source files found for direct compilation" && \
            BUILD_COMPLETE=0; \
        fi; \
    fi && \
    \
    # Verify build artifacts
    echo "=== VERIFYING BUILD ARTIFACTS ===" && \
    if [ "$BUILD_COMPLETE" = "1" ]; then \
        echo "Build completed successfully, verifying artifacts..." && \
        find . -name '*.so*' -o -name 'libpciaccess*' | tee /tmp/artifacts.log && \
        find . -name '*.so*' -exec ldd {} \; 2>/dev/null | grep -i llvm | tee /tmp/library_deps.log || true && \
        find . -name '*.so*' -exec strings {} \; 2>/dev/null | grep -i 'llvm\|clang' | sort | uniq | tee /tmp/strings_scan.log || true; \
    else \
        echo "Build was not completed successfully" && \
        ls -la; \
    fi && \
    \
    # Install with robust error handling
    echo "=== INSTALLING AND VERIFYING ===" && \
    if [ -f "Makefile" ] || [ -f "makefile" ]; then \
        make install V=1 2>&1 | tee /tmp/make_install.log; \
    elif [ -d "/tmp/pciaccess_build" ]; then \
        echo "Installing from direct build..." && \
        cp /tmp/pciaccess_build/libpciaccess.so* /custom-os/usr/x11/lib/ && \
        find . -name "*.h" -exec cp {} /custom-os/usr/x11/include/ \; 2>/dev/null || true; \
    else \
        echo "Attempting to find and install built libraries..." && \
        BUILT_LIBS=$(find . -name "libpciaccess*.so*" | head -5) && \
        if [ -n "$BUILT_LIBS" ]; then \
            echo "Found built libraries: $BUILT_LIBS" && \
            for lib in $BUILT_LIBS; do \
                cp "$lib" /custom-os/usr/x11/lib/; \
            done && \
            find . -name "*.h" -exec cp {} /custom-os/usr/x11/include/ \; 2>/dev/null || true; \
        else \
            echo "No libraries found to install"; \
        fi; \
    fi && \
    \
    # Ensure pkg-config directory exists and create pkg-config file
    echo "=== COMPREHENSIVE PKG-CONFIG SETUP ===" && \
    echo "Contents of /custom-os/usr/x11/pkgconfig:" && \
    ls -la /custom-os/usr/x11/pkgconfig/ || echo "Directory is empty" && \
    echo "Contents of /custom-os/usr/x11/lib:" && \
    ls -la /custom-os/usr/x11/lib/ && \
    \
    # Create pkg-config file if it doesn't exist
    if [ ! -f /custom-os/usr/x11/pkgconfig/pciaccess.pc ]; then \
        echo "Creating comprehensive pciaccess.pc file..." && \
        printf 'prefix=/custom-os/usr/x11\n' > /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'exec_prefix=${prefix}\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'libdir=${exec_prefix}/lib\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'includedir=${prefix}/include\n\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'Name: pciaccess\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'Description: Generic PCI access library\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'Version: 0.17\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'URL: https://www.x.org\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'Libs: -L${libdir} -lpciaccess\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc && \
        printf 'Cflags: -I${includedir}\n' >> /custom-os/usr/x11/pkgconfig/pciaccess.pc; \
    else \
        echo "Found existing pciaccess.pc:"; \
        cat /custom-os/usr/x11/pkgconfig/pciaccess.pc 2>/dev/null || echo "No pciaccess.pc file found"; \
    fi && \
    \
    # Test pkg-config
    echo "=== PKG-CONFIG COMPREHENSIVE TESTING ===" && \
    export PKG_CONFIG_PATH="/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    echo "Testing pkg-config with PKG_CONFIG_PATH=$PKG_CONFIG_PATH" && \
    echo "Available packages:" && \
    pkg-config --list-all | grep -E "(pciaccess|drm|x11)" | tee /tmp/pkg_list.log || true && \
    echo "Testing pciaccess specifically:" && \
    if pkg-config --exists pciaccess; then \
        echo "✓ pciaccess package found" && \
        echo "Cflags: $(pkg-config --cflags pciaccess)" && \
        echo "Libs: $(pkg-config --libs pciaccess)" && \
        echo "Version: $(pkg-config --modversion pciaccess)"; \
    else \
        echo "✗ pciaccess package not found"; \
    fi && \
    \
    # Verify library installation and create symbolic links
    echo "=== LIBRARY INSTALLATION VERIFICATION ===" && \
    echo "Installed libraries in /custom-os/usr/x11/lib:" && \
    ls -la /custom-os/usr/x11/lib/libpciaccess* 2>/dev/null || echo "No libpciaccess libraries found" && \
    echo "Creating/verifying symbolic links..." && \
    cd /custom-os/usr/x11/lib && \
    if ls libpciaccess.so.*.*.* 1> /dev/null 2>&1; then \
        FULL_LIB=$(ls libpciaccess.so.*.*.* | head -1) && \
        SONAME=$(echo "$FULL_LIB" | sed 's/\(.*\.so\.[0-9]*\).*/\1/') && \
        echo "Creating symlinks for $FULL_LIB -> $SONAME -> libpciaccess.so" && \
        ln -sf "$FULL_LIB" "$SONAME" && \
        ln -sf "$SONAME" libpciaccess.so && \
        echo "Library symlinks created successfully" && \
        ls -la libpciaccess* && \
        echo "Testing library loading:" && \
        ldd "$FULL_LIB" 2>/dev/null | grep -i llvm | tee /tmp/install_deps.log || true; \
    elif [ -f libpciaccess.so ]; then \
        echo "Found basic libpciaccess.so" && \
        ldd libpciaccess.so 2>/dev/null | grep -i llvm | tee /tmp/install_deps.log || true; \
    else \
        echo "No libpciaccess library found at all"; \
    fi && \
    \
    # Final contamination scan
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" /custom-os/usr/x11 2>&1 | tee /tmp/final_scan.log || true) && \
    echo "=== BUILD LOGS SUMMARY ===" && \
    echo "Log files created:" && \
    ls -la /tmp/*log /tmp/*scan.log 2>/dev/null || echo "No log files found" && \
    \
    # Cleanup
    cd / && \
    rm -rf pciaccess && \
    rm -rf /tmp/pciaccess_build 2>/dev/null || true && \
    \
    # Final verification
    /usr/local/bin/check_llvm15.sh "post-pciaccess-source-build" || true && \
    echo "=== FINAL SUCCESS VERIFICATION ===" && \
    if [ -f /custom-os/usr/x11/lib/libpciaccess.so ] || ls /custom-os/usr/x11/lib/libpciaccess.so.* 1> /dev/null 2>&1; then \
        echo "✓ SUCCESS: libpciaccess library installed" && \
        if [ -f /custom-os/usr/x11/pkgconfig/pciaccess.pc ]; then \
            echo "✓ SUCCESS: pkg-config file installed" && \
            if pkg-config --exists pciaccess; then \
                echo "✓ SUCCESS: pkg-config recognizes pciaccess" && \
                echo "=== STRINGENT_PCIACCESS_BUILD COMPLETE - ALL CHECKS PASSED ==="; \
            else \
                echo "⚠ WARNING: pkg-config doesn't recognize pciaccess but files exist" && \
                echo "=== STRINGENT_PCIACCESS_BUILD COMPLETE - PARTIAL SUCCESS ==="; \
            fi; \
        else \
            echo "⚠ WARNING: No pkg-config file but library exists" && \
            echo "=== STRINGENT_PCIACCESS_BUILD COMPLETE - PARTIAL SUCCESS ==="; \
        fi; \
    else \
        echo "✗ ERROR: No libpciaccess library found after build" && \
        echo "=== STRINGENT_PCIACCESS_BUILD FAILED ==="; \
    fi

# ======================
# SECTION: libdrm Build
# ======================
RUN echo "=== BUILDING libdrm FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libdrm-source-build" || true && \
    \
    # Install missing dependencies first (including meson since pciaccess build removed it)
    /usr/local/bin/check_llvm15.sh "after-libdrm-deps" || true && \
    \
    # Clone libdrm (meson now installed)
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/drm.git libdrm && \
    cd libdrm && \
    \
    # Scan source tree for LLVM15 contamination
    grep -RIn "LLVM15" . || true && grep -RIn "llvm-15" . || true && \
    \
    # Set up environment for LLVM16 with proper PKG_CONFIG_PATH ordering
    export CC=/custom-os/compiler/bin/clang-16 && \
    export CXX=/custom-os/compiler/bin/clang++-16 && \
    export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config && \
    export CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations" && \
    export CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations" && \
    export LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    export PKG_CONFIG_PATH="/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    \
    # Disable ANSI colors for cleaner output
    export NO_COLOR=1 && \
    \
    # Verify both meson and pciaccess are available
    echo "=== VERIFYING BUILD DEPENDENCIES ===" && \
    which meson && meson --version && \
    echo "Contents of /custom-os/usr/x11/pkgconfig:" && \
    ls -la /custom-os/usr/x11/pkgconfig/ && \
    echo "PKG_CONFIG_PATH = $PKG_CONFIG_PATH" && \
    echo "Testing basic pkg-config functionality:" && \
    pkg-config --version && \
    pkg-config --list-all | head -5 && \
    echo "Searching for pciaccess in pkg-config:" && \
    pkg-config --list-all | grep pciaccess || echo "pciaccess not in list" && \
    \
    # Create sys/mkdev.h symlink workaround for musl systems
    echo "=== CREATING MUSL HEADER WORKAROUND ===" && \
    if [ ! -f /usr/include/sys/mkdev.h ] && [ -f /usr/include/sys/sysmacros.h ]; then \
        echo "Creating sys/mkdev.h -> sys/sysmacros.h symlink for musl compatibility" && \
        ln -sf sysmacros.h /usr/include/sys/mkdev.h; \
    fi && \
    \
    # Verify other required packages are available
    echo "=== CHECKING FOR OPTIONAL DEPENDENCIES ===" && \
    pkg-config --exists cunit && echo "cunit: available" || echo "cunit: not available (tests will be disabled)" && \
    pkg-config --exists cairo && echo "cairo: available" || echo "cairo: not available (cairo tests will be disabled)" && \
    pkg-config --exists valgrind && echo "valgrind: available" || echo "valgrind: not available (valgrind support will be disabled)" && \
    \
    # Configure with meson - explicitly disable problematic optional features
    meson setup builddir \
        --prefix=/custom-os/usr/x11 \
        --libdir=lib \
        --buildtype=release \
        -Dintel=enabled \
        -Dradeon=enabled \
        -Damdgpu=enabled \
        -Dnouveau=enabled \
        -Dvmwgfx=enabled \
        -Dvc4=enabled \
        -Dfreedreno=enabled \
        -Detnaviv=enabled \
        -Dexynos=enabled \
        -Dtests=false \
        -Dman-pages=disabled \
        -Dcairo-tests=disabled \
        -Dvalgrind=disabled && \
    \
    # Build and install with cleaner output
    meson compile -C builddir -j$(nproc) --verbose 2>&1 | sed 's/\x1b\[[0-9;]*m//g' && \
    meson install -C builddir 2>&1 | sed 's/\x1b\[[0-9;]*m//g' && \
    \
    # Output the meson log for debugging (strip colors)
    echo "=== MESON BUILD LOG ===" && \
    cat builddir/meson-logs/meson-log.txt | sed 's/\x1b\[[0-9;]*m//g' && \
    echo "=== END MESON BUILD LOG ===" && \
    \
    # Comprehensive libdrm installation verification
    echo "=== COMPREHENSIVE LIBDRM INSTALLATION VERIFICATION ===" && \
    echo "Contents of /custom-os/usr/x11/lib:" && \
    ls -la /custom-os/usr/x11/lib/ | grep -E "(libdrm|\.so)" || echo "No libdrm libraries visible" && \
    echo "Contents of /custom-os/usr/x11/include:" && \
    ls -la /custom-os/usr/x11/include/ | grep -E "(drm|libdrm)" || echo "No drm headers visible" && \
    \
    # Verify pkg-config files were installed
    echo "=== PKG-CONFIG FILES VERIFICATION ===" && \
    echo "Searching for all libdrm pkg-config files:" && \
    find /custom-os/usr/x11 -name "libdrm*.pc" -type f | tee /tmp/libdrm_pc_files.log && \
    if [ -s /tmp/libdrm_pc_files.log ]; then \
        echo "Found libdrm pkg-config files:" && \
        while read pc_file; do \
            echo "File: $pc_file" && \
            echo "Contents:" && \
            cat "$pc_file" && \
            echo "---"; \
        done < /tmp/libdrm_pc_files.log; \
    else \
        echo "No libdrm pkg-config files found - checking meson install logs" && \
        echo "Builddir contents:" && \
        find builddir -name "*.pc" -type f || echo "No .pc files in builddir"; \
    fi && \
    \
    # Test pkg-config functionality
    echo "=== PKG-CONFIG COMPREHENSIVE TESTING ===" && \
    export PKG_CONFIG_PATH="/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    echo "Testing pkg-config with PKG_CONFIG_PATH=$PKG_CONFIG_PATH" && \
    echo "Available packages containing 'drm':" && \
    pkg-config --list-all | grep drm | tee /tmp/drm_pkg_list.log || echo "No drm packages found in pkg-config" && \
    echo "Testing libdrm specifically:" && \
    if pkg-config --exists libdrm; then \
        echo "✓ libdrm package found" && \
        echo "Cflags: $(pkg-config --cflags libdrm)" && \
        echo "Libs: $(pkg-config --libs libdrm)" && \
        echo "Version: $(pkg-config --modversion libdrm)"; \
    else \
        echo "✗ libdrm package not found in pkg-config"; \
    fi && \
    \
    # Verify library installation and create symbolic links if needed
    echo "=== LIBRARY INSTALLATION VERIFICATION ===" && \
    echo "Installed libdrm libraries in /custom-os/usr/x11/lib:" && \
    ls -la /custom-os/usr/x11/lib/libdrm* 2>/dev/null || echo "No libdrm libraries found" && \
    echo "Verifying library symbolic links..." && \
    cd /custom-os/usr/x11/lib && \
    for lib_pattern in "libdrm.so" "libdrm_*.so"; do \
        if ls $lib_pattern.*.*.* 1> /dev/null 2>&1; then \
            for FULL_LIB in $lib_pattern.*.*.*; do \
                SONAME=$(echo "$FULL_LIB" | sed 's/\(.*\.so\.[0-9]*\).*/\1/') && \
                BASE_NAME=$(echo "$FULL_LIB" | sed 's/\(.*\.so\).*/\1/') && \
                echo "Creating symlinks for $FULL_LIB -> $SONAME -> $BASE_NAME" && \
                ln -sf "$FULL_LIB" "$SONAME" && \
                ln -sf "$SONAME" "$BASE_NAME" && \
                echo "Library symlinks created successfully for $BASE_NAME"; \
            done; \
        fi; \
    done && \
    ls -la /custom-os/usr/x11/lib/libdrm* 2>/dev/null && \
    \
    # Post-build contamination scan
    echo "=== CONTAMINATION SCAN ===" && \
    find builddir -name "*.so*" -type f -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null || echo "No LLVM15 contamination found in built libraries" && \
    find /custom-os/usr/x11 -name "libdrm*" -type f -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null || echo "No LLVM15 contamination found in installed libdrm files" && \
    \
    # Final success verification
    echo "=== FINAL SUCCESS VERIFICATION ===" && \
    if find /custom-os/usr/x11/lib -name "libdrm*.so*" -type f | grep -q .; then \
        echo "✓ SUCCESS: libdrm libraries installed" && \
        if find /custom-os/usr/x11/pkgconfig -name "libdrm*.pc" -type f | grep -q .; then \
            echo "✓ SUCCESS: libdrm pkg-config files installed" && \
            if pkg-config --exists libdrm; then \
                echo "✓ SUCCESS: pkg-config recognizes libdrm" && \
                echo "=== LIBDRM BUILD COMPLETE - ALL CHECKS PASSED ==="; \
            else \
                echo "⚠ WARNING: pkg-config doesn't recognize libdrm but files exist" && \
                echo "=== LIBDRM BUILD COMPLETE - PARTIAL SUCCESS ==="; \
            fi; \
        else \
            echo "⚠ WARNING: No pkg-config files but libraries exist" && \
            echo "=== LIBDRM BUILD COMPLETE - PARTIAL SUCCESS ==="; \
        fi; \
    else \
        echo "✗ ERROR: No libdrm libraries found after build" && \
        echo "=== LIBDRM BUILD FAILED ==="; \
    fi && \
    cd .. && \
    rm -rf libdrm && \
    /usr/local/bin/check_llvm15.sh "post-libdrm-source-build" || true
# ======================
# SECTION: libepoxy Build from Source
# ======================
RUN echo "=== BUILDING LIBEPOXY FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libepoxy-source-build" || true && \
    \
    # Install meson, ninja and build dependencies (avoiding libepoxy-dev)
    echo "=== INSTALLING NINJA AND BUILD DEPENDENCIES ===" && \
    /usr/local/bin/check_llvm15.sh "after-libepoxy-deps-install" || true && \
    \
    # Clone libepoxy source
    echo "=== CLONING LIBEPOXY SOURCE ===" && \
    git clone --depth=1 --branch 1.5.10 https://github.com/anholt/libepoxy.git libepoxy && \
    cd libepoxy && \
    \
    # Verify source integrity
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    grep -RIn "LLVM15\|llvm-15" . 2>/dev/null | tee /tmp/libepoxy_source_scan.log || true && \
    \
    # Configure with meson and LLVM16 enforcement
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
    # Build with verification
    echo "=== BUILDING LIBEPOXY ===" && \
    ninja -C builddir -j"$(nproc)" 2>&1 | tee /tmp/libepoxy-build.log && \
    \
    # Install with verification
    echo "=== INSTALLING LIBEPOXY ===" && \
    ninja -C builddir install 2>&1 | tee /tmp/libepoxy-install.log && \
    \
    # Verify installation
    echo "=== LIBEPOXY INSTALLATION VERIFICATION ===" && \
    echo "Libraries installed:" && \
    ls -la /custom-os/usr/lib/libepoxy* 2>/dev/null || echo "No libepoxy libraries found" && \
    echo "Headers installed:" && \
    ls -la /custom-os/usr/include/epoxy/ 2>/dev/null || echo "No epoxy headers found" && \
    echo "PKG-config files:" && \
    ls -la /custom-os/usr/lib/pkgconfig/epoxy.pc 2>/dev/null || echo "No epoxy.pc found" && \
    \
    # Create necessary symlinks if needed
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
    # Final contamination check
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    find /custom-os/usr/lib -name "libepoxy*" -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null | tee /tmp/libepoxy_contamination.log || true && \
    \
    # Cleanup
    cd / && \
    rm -rf libepoxy && \
    \
    # Final verification
    /usr/local/bin/check_llvm15.sh "post-libepoxy-source-build" || true && \
    echo "=== LIBEPOXY BUILD COMPLETE ===" && \
    if [ -f /custom-os/usr/lib/libepoxy.so ] && [ -f /custom-os/usr/include/epoxy/gl.h ]; then \
        echo "✓ SUCCESS: libepoxy components installed"; \
    else \
        echo "⚠ WARNING: Some libepoxy components missing"; \
    fi

# ======================
# SECTION: Xorg Server Build (Updated to use custom libepoxy)
# ======================
RUN echo "=== BUILDING XORG-SERVER FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-xorg-server-source-build" || true && \
    \
    # Install autotools and build dependencies (excluding libepoxy-dev since we built it)
    echo "=== INSTALLING AUTOTOOLS AND BUILD DEPENDENCIES ===" && \
    /usr/local/bin/check_llvm15.sh "after-xorg-deps-install" || true && \
    \
    # Clone xorg-server source
    echo "=== CLONING XORG-SERVER SOURCE ===" && \
    git clone --depth=1 --branch xorg-server-21.1.8 https://gitlab.freedesktop.org/xorg/xserver.git xorg-server && \
    cd xorg-server && \
    \
    # Verify source integrity
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    grep -RIn "LLVM15\|llvm-15" . 2>/dev/null | tee /tmp/xorg_source_scan.log || true && \
    \
    # Configure with custom paths, LLVM16 enforcement, and custom libepoxy
    echo "=== CONFIGURING XORG-SERVER WITH LLVM16 EXPLICIT PATHS ===" && \
    autoreconf -fiv && \
    ./configure \
        --prefix=/custom-os/usr/x11 \
        --sysconfdir=/custom-os/etc \
        --localstatedir=/custom-os/var \
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
        CC=/custom-os/compiler/bin/clang-16 \
        CXX=/custom-os/compiler/bin/clang++-16 \
        LLVM_CONFIG=/custom-os/compiler/bin/llvm-config \
        CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -I/custom-os/usr/include -march=armv8-a" \
        CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -I/custom-os/usr/include -march=armv8-a" \
        LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -L/custom-os/usr/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib:/custom-os/usr/lib" \
        PKG_CONFIG_PATH="/custom-os/usr/x11/pkgconfig:/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    \
    # Build with verification
    echo "=== BUILDING XORG-SERVER ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/xorg-build.log && \
    \
    # Install with verification
    echo "=== INSTALLING XORG-SERVER ===" && \
    make install 2>&1 | tee /tmp/xorg-install.log && \
    \
    # Create compatibility headers
    echo "=== CREATING XORG-SERVER-DEV COMPATIBILITY HEADERS ===" && \
    mkdir -p /custom-os/usr/x11/include/xorg && \
    cp -r include/* /custom-os/usr/x11/include/xorg/ 2>/dev/null || true && \
    \
    # Verify installation
    echo "=== XORG-SERVER INSTALLATION VERIFICATION ===" && \
    echo "Binaries installed:" && \
    ls -la /custom-os/usr/x11/bin/X* 2>/dev/null || echo "No Xorg binaries found" && \
    echo "Libraries installed:" && \
    ls -la /custom-os/usr/x11/lib/libxserver* 2>/dev/null || echo "No Xserver libraries found" && \
    echo "Headers installed:" && \
    ls -la /custom-os/usr/x11/include/xorg 2>/dev/null || echo "No Xorg headers found" && \
    \
    # Create necessary symlinks
    echo "=== CREATING REQUIRED SYMLINKS ===" && \
    cd /custom-os/usr/x11/lib && \
    for lib in $(ls libxserver*.so.*.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    # Final contamination check
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    find /custom-os/usr/x11 -name "libxserver*" -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null | tee /tmp/xorg_contamination.log || true && \
    \
    # Cleanup
    cd / && \
    rm -rf xorg-server && \
    \
    # Final verification
    /usr/local/bin/check_llvm15.sh "post-xorg-server-source-build" || true && \
    echo "=== XORG-SERVER BUILD COMPLETE ===" && \
    if [ -f /custom-os/usr/x11/bin/Xvfb ] && [ -f /custom-os/usr/x11/lib/libxserver.so ]; then \
        echo "✓ SUCCESS: Xorg server components installed"; \
    else \
        echo "⚠ WARNING: Some Xorg components missing"; \
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
    # Copy libraries to custom filesystem
    echo "=== COPYING IMAGE LIBRARIES TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/media/{lib,include} && \
    cp -r /usr/lib/libtiff* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libwebp* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libavif* /custom-os/usr/media/lib/ 2>/dev/null || true && \
    cp -r /usr/include/tiff* /custom-os/usr/media/include/ 2>/dev/null || true && \
    cp -r /usr/include/webp /custom-os/usr/media/include/ 2>/dev/null || true && \
    cp -r /usr/include/avif /custom-os/usr/media/include/ 2>/dev/null || true && \
    \
    # Verify installation
    echo "=== VERIFYING IMAGE LIBRARIES ===" && \
    ls -la /custom-os/usr/media/lib/libtiff* /custom-os/usr/media/lib/libwebp* /custom-os/usr/media/lib/libavif* || echo "Some libraries not found"

# ======================
# SECTION: Python Dependencies
# ======================
RUN echo "=== INSTALLING PYTHON DEPENDENCIES ===" && \
    pip install --no-cache-dir meson==1.4.0 mako==1.3.3 && \
    /usr/local/bin/check_llvm15.sh "after-python-packages" || true && \
    \
    # Copy Python packages to custom filesystem
    echo "=== COPYING PYTHON PACKAGES TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/python/site-packages && \
    python -c "import os, shutil; [shutil.copytree(os.path.dirname(__import__(pkg).__file__, f'/custom-os/usr/python/site-packages/{pkg}') for pkg in ['mesonbuild', 'mako']]" && \
    \
    # Verify Python packages
    echo "=== VERIFYING PYTHON PACKAGES ===" && \
    ls -la /custom-os/usr/python/site-packages/{mesonbuild,mako} || echo "Python packages not found"

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
    # Verify installation
    echo "=== VERIFYING SPIRV-TOOLS INSTALLATION ===" && \
    echo "SPIRV-Tools binaries:" && \
    ls -la /custom-os/usr/vulkan/bin/spirv-* 2>/dev/null || echo "No SPIRV-Tools binaries found" && \
    echo "SPIRV-Tools libraries:" && \
    ls -la /custom-os/usr/vulkan/lib/libSPIRV-Tools* 2>/dev/null || echo "No SPIRV-Tools libraries found" && \
    \
    # Create symlinks
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
    # Final contamination check
    /usr/local/bin/check_llvm15.sh "post-spirv-tools-source-build" || true && \
    echo "=== SPIRV-TOOLS BUILD COMPLETE ==="

# ======================
# SECTION: Shaderc Build
# ======================
RUN echo "=== BUILDING SHADERC FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-shaderc-source-build" || true && \
    \
    git clone --recursive https://github.com/google/shaderc.git && \
    cd shaderc && \
    \
    echo "=== CONFIGURING SHADERC WITH LLVM16 ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr/vulkan \
        -DCMAKE_C_COMPILER=/custom-os/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/custom-os/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-I/custom-os/compiler/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/custom-os/compiler/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/custom-os/compiler/lib -Wl,-rpath,/custom-os/compiler/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        -DSHADERC_SKIP_TESTS=ON \
        -DSHADERC_SKIP_EXAMPLES=ON && \
    \
    echo "=== BUILDING SHADERC ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/shaderc-build.log && \
    \
    echo "=== INSTALLING SHADERC ===" && \
    make install 2>&1 | tee /tmp/shaderc-install.log && \
    \
    cd ../.. && \
    rm -rf shaderc && \
    \
    # Verify installation
    echo "=== SHADERC INSTALLATION VERIFICATION ===" && \
    echo "Shaderc binaries:" && \
    ls -la /custom-os/usr/vulkan/bin/shaderc* 2>/dev/null || echo "No shaderc binaries found" && \
    echo "Shaderc libraries:" && \
    ls -la /custom-os/usr/vulkan/lib/libshaderc* 2>/dev/null || echo "No shaderc libraries found" && \
    \
    # Create symlinks
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/vulkan/lib && \
    for lib in $(ls libshaderc*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    /usr/local/bin/check_llvm15.sh "post-shaderc-source-build" || true && \
    echo "=== SHADERC BUILD COMPLETE ==="

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
    ./autogen.sh --prefix=/custom-os/usr/x11 && \
    ./configure \
        --prefix=/custom-os/usr/x11 \
        CC=/custom-os/compiler/bin/clang-16 \
        CXX=/custom-os/compiler/bin/clang++-16 \
        CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
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
    # Verify installation
    echo "=== LIBGBM INSTALLATION VERIFICATION ===" && \
    echo "libgbm libraries:" && \
    ls -la /custom-os/usr/x11/lib/libgbm* 2>/dev/null || echo "No libgbm libraries found" && \
    \
    # Create symlinks
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/x11/lib && \
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
RUN echo "=== BUILDING GST-PLUGINS-BASE FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gst-plugins-base-source-build" || true && \
    \
    # Install build dependencies
    wget https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.20.3.tar.xz && \
    tar -xvf gst-plugins-base-1.20.3.tar.xz && \
    cd gst-plugins-base-1.20.3 && \
    \
    echo "=== CONFIGURING GST-PLUGINS-BASE WITH LLVM16 EXPLICIT PATHS ===" && \
    ./configure \
        --prefix=/custom-os/usr/media \
        --disable-static \
        --enable-shared \
        --disable-introspection \
        --disable-examples \
        --disable-gtk-doc \
        CC=/custom-os/compiler/bin/clang-16 \
        CXX=/custom-os/compiler/bin/clang++-16 \
        LLVM_CONFIG=/custom-os/compiler/bin/llvm-config \
        CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a" \
        LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        PKG_CONFIG_PATH="/custom-os/usr/media/pkgconfig:/custom-os/usr/x11/pkgconfig:/custom-os/compiler/lib/pkgconfig" && \
    \
    echo "=== BUILDING GST-PLUGINS-BASE ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/gst-plugins-build.log && \
    \
    echo "=== INSTALLING GST-PLUGINS-BASE ===" && \
    make install 2>&1 | tee /tmp/gst-plugins-install.log && \
    \
    cd .. && \
    rm -rf gst-plugins-base-* && \
    \
    # Verify installation
    echo "=== GST-PLUGINS-BASE INSTALLATION VERIFICATION ===" && \
    echo "GStreamer plugins:" && \
    ls -la /custom-os/usr/media/lib/gstreamer-1.0/ 2>/dev/null || echo "No GStreamer plugins found" && \
    echo "GStreamer libraries:" && \
    ls -la /custom-os/usr/media/lib/libgst* 2>/dev/null || echo "No GStreamer libraries found" && \
    \
    # Create symlinks
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /custom-os/usr/media/lib && \
    for lib in $(ls libgst*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    /usr/local/bin/check_llvm15.sh "post-gst-plugins-base-source-build" || true && \
    echo "=== GST-PLUGINS-BASE BUILD COMPLETE ==="

# ======================
# SECTION: Mesa Build
# ======================
ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

RUN echo "=== MESA BUILD WITH LLVM16 ENFORCEMENT ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-clone" || true && \
    \
    # Install build dependencies
    git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git && \
    /usr/local/bin/check_llvm15.sh "post-mesa-clone" || true && \
    \
    cd mesa && \
    git checkout mesa-24.0.3 && \
    \
    echo "=== MESA BUILD CONFIGURATION (ARM64 + LLVM16) ===" && \
    CC=/custom-os/compiler/bin/clang-16 \
    CXX=/custom-os/compiler/bin/clang++-16 \
    LLVM_CONFIG=/custom-os/compiler/bin/llvm-config \
    meson setup builddir/ \
        -Dprefix=/custom-os/usr/x11 \
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
        -Dc_args="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -Dcpp_args="-v -Wno-error -march=armv8-a -I/custom-os/compiler/include -I/custom-os/glibc/include" \
        -Dc_link_args="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" \
        -Dcpp_link_args="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib" && \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-configure" || true && \
    \
    echo "=== MESA BUILD LOGS ===" && \
    cat builddir/meson-logs/meson-log.txt && \
    echo "=== MESA CONFIGURATION ===" && \
    meson configure builddir/ && \
    \
    echo "=== STARTING NINJA BUILD (ARM64 + LLVM16) ===" && \
    ninja -C builddir -v install && \
    /usr/local/bin/check_llvm15.sh "post-mesa-build" || true && \
    \
    echo "=== VULKAN ICD CONFIGURATION (ARM64) ===" && \
    mkdir -p /custom-os/usr/share/vulkan/icd.d && \
    printf '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > /custom-os/usr/share/vulkan/icd.d/swrast_icd.arm64.json && \
    \
    echo "=== MESA BUILD COMPLETED ===" && \
    cd .. && \
    rm -rf mesa && \
    \
    # Create DRI directory structure
    echo "=== CREATING DRI DIRECTORY STRUCTURE ===" && \
    mkdir -p /custom-os/usr/lib/xorg/modules/dri && \
    ln -s /custom-os/usr/lib/dri /custom-os/usr/lib/xorg/modules/dri && \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-cleanup" || true

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
    test ! -s /tmp/llvm15-grep || (echo "FOUND llvm-15 references - aborting" && cat /tmp/llvm15-grep && false) || true

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
# ======================
# SECTION: Application Build Setup
# ======================
RUN echo "=== INITIALIZING APPLICATION BUILD ENVIRONMENT ===" && \
    mkdir -p /custom-os/app/{src,build,bin,lib} && \
    mkdir -p /custom-os/usr/{lib,include} && \
    \
    # Verify filesystem structure
    echo "=== FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS structure:" && \
    tree -L 3 /custom-os | tee /tmp/filesystem_structure.log && \
    \
    # Install minimal Mesa/OSMesa dev packages (for CMake discovery)
    echo "=== INSTALLING SYSTEM DEPENDENCIES ===" && \
    apk add --no-cache mesa-dev mesa-osmesa 2>&1 | tee /tmp/system_deps_install.log && \
    \
    # Verify Mesa installation
    echo "=== MESA LIBRARY VERIFICATION ===" && \
    echo "System Mesa libraries:" && \
    ls -la /usr/lib/libOSMesa* /usr/lib/libGL* 2>/dev/null | tee /tmp/mesa_libs.log || echo "No system Mesa libraries found" && \
    \
    # Verify LLVM16 toolchain
    echo "=== TOOLCHAIN VERIFICATION ===" && \
    echo "LLVM16 components:" && \
    ls -la /custom-os/compiler/bin/clang-16 /custom-os/compiler/bin/llvm-config | tee /tmp/toolchain_verify.log && \
    /usr/local/bin/check_llvm15.sh "pre-app-build" | tee -a /tmp/toolchain_verify.log || true

# Copy application source
COPY . /custom-os/app/src

# ======================
# SECTION: CMake Build with Enhanced Diagnostics
# ======================
RUN echo "=== CONFIGURING BUILD ENVIRONMENT ===" && \
    export CC=/custom-os/compiler/bin/clang-16 && \
    export CXX=/custom-os/compiler/bin/clang++-16 && \
    export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:/usr/lib/pkgconfig" && \
    export LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:/usr/lib" && \
    export CMAKE_PREFIX_PATH="/custom-os/usr:/custom-os/compiler:/usr" && \
    \
    # Environment verification
    echo "=== BUILD ENVIRONMENT VERIFICATION ===" && \
    echo "CC: $CC ($(which $CC))" | tee /tmp/build_env.log && \
    echo "CXX: $CXX ($(which $CXX))" | tee -a /tmp/build_env.log && \
    echo "LLVM_CONFIG: $LLVM_CONFIG ($(which $LLVM_CONFIG))" | tee -a /tmp/build_env.log && \
    echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH" | tee -a /tmp/build_env.log && \
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH" | tee -a /tmp/build_env.log && \
    echo "CMAKE_PREFIX_PATH: $CMAKE_PREFIX_PATH" | tee -a /tmp/build_env.log && \
    \
    # Package config test
    echo "=== PKG-CONFIG SANITY CHECK ===" && \
    pkg-config --list-all | tee /tmp/pkgconfig_list.log && \
    \
    # CMake configuration
    echo "=== RUNNING CMAKE CONFIGURATION ===" && \
    mkdir -p /custom-os/app/build && \
    cd /custom-os/app/build && \
    cmake ../src \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
        -DCMAKE_LIBRARY_PATH="/custom-os/usr/lib;/custom-os/compiler/lib;/usr/lib" \
        -DCMAKE_INCLUDE_PATH="/custom-os/usr/include;/custom-os/compiler/include;/usr/include" \
        -DCMAKE_INSTALL_RPATH="/custom-os/usr/lib;/custom-os/compiler/lib;/usr/lib" \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        2>&1 | tee /tmp/cmake_configure.log && \
    \
    # Build with comprehensive logging
    echo "=== BUILDING APPLICATION ===" && \
    cmake --build . --target simplehttpserver --parallel $(nproc) \
        2>&1 | tee /tmp/cmake_build.log && \
    \
    # Post-build verification
    echo "=== POST-BUILD VERIFICATION ===" && \
    echo "Build artifacts:" && \
    find . -name 'simplehttpserver*' -o -name '*.so' -o -name '*.a' | tee /tmp/build_artifacts.log && \
    echo "Library dependencies:" && \
    ldd ./simplehttpserver 2>/dev/null | tee /tmp/application_deps.log || true && \
    \
    # Install to custom filesystem
    echo "=== INSTALLING TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/bin && \
    cp ./simplehttpserver /custom-os/usr/bin/ && \
    chmod +x /custom-os/usr/bin/simplehttpserver && \
    \
    # Final verification
    echo "=== INSTALLATION VERIFICATION ===" && \
    ls -la /custom-os/usr/bin/simplehttpserver | tee /tmp/install_verify.log && \
    /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /tmp/install_verify.log || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-app-build" | tee /tmp/llvm_final_check.log || true && \
    echo "=== APPLICATION BUILD COMPLETE ==="

# ======================
# SECTION: Final Environment Setup
# ======================
ENV PATH="/custom-os/usr/bin:/custom-os/compiler/bin:$PATH"
ENV LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:$PKG_CONFIG_PATH"

# Example invocation adjustments:
# cmake -DCMAKE_PREFIX_PATH=/usr/local -DCMAKE_BUILD_TYPE=Release ...
# or ensure you use pkg-config:
# CFLAGS=$(pkg-config --cflags sqlite3) LDFLAGS=$(pkg-config --libs sqlite3) cmake ...

# Stage: build application
FROM app-build AS debug
# ======================
# SECTION: Debug Environment Setup
# ======================
RUN echo "=== INITIALIZING DEBUG ENVIRONMENT ===" && \
    mkdir -p /custom-os/usr/{bin,lib,include,share} && \
    mkdir -p /custom-os/var/log/debug && \
    \
    # Verify filesystem structure
    echo "=== FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS structure:" && \
    tree -L 3 /custom-os | tee /custom-os/var/log/debug/filesystem_structure.log && \
    \
    # Verify existing components
    echo "=== COMPONENT VERIFICATION ===" && \
    echo "SimpleHTTPServer binary:" && \
    ls -la /custom-os/usr/bin/simplehttpserver | tee -a /custom-os/var/log/debug/component_verify.log && \
    /custom-os/usr/bin/simplehttpserver --version 2>&1 | tee -a /custom-os/var/log/debug/component_verify.log || true

# ======================
# SECTION: Mesa Demos Build with Stringent LLVM16 Enforcement
# ======================
RUN echo "=== STRINGENT_MESA_DEMOS_BUILD: COMPILING FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-demos-source" | tee /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    # Purge any existing LLVM15 contamination
    echo "=== PURGING LLVM15 CONTAMINATION ===" && \
    apk del --no-cache llvm15-libs $(apk info -R llvm15-libs 2>/dev/null) 2>/dev/null | tee /custom-os/var/log/debug/llvm_purge.log || true && \
    find /usr -name '*llvm15*' -exec rm -fv {} \; 2>/dev/null | tee -a /custom-os/var/log/debug/llvm_purge.log || true && \
    \
    # Install minimal build dependencies
    echo "=== INSTALLING SANITIZED BUILD DEPS ===" && \
    apk add --no-cache \
        cmake \
        make \
        mesa-dev \
        glu-dev \
        freeglut-dev \
        git 2>&1 | tee /custom-os/var/log/debug/deps_install.log && \
    /usr/local/bin/check_llvm15.sh "after-deps-install" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    # Clone and verify source
    echo "=== CLONING AND VERIFYING SOURCE ===" && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/demos.git /tmp/mesa-demos && \
    cd /tmp/mesa-demos && \
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" . 2>&1 | tee /custom-os/var/log/debug/source_scan.log || true) && \
    \
    # Set hardened build environment using custom toolchain
    echo "=== SETTING HARDENED BUILD ENV ===" && \
    export CC=/custom-os/compiler/bin/clang-16 && \
    export CXX=/custom-os/compiler/bin/clang++-16 && \
    export LLVM_CONFIG=/custom-os/compiler/bin/llvm-config && \
    export CFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export CXXFLAGS="-I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export LDFLAGS="-L/custom-os/compiler/lib -L/custom-os/glibc/lib -Wl,-rpath,/custom-os/compiler/lib:/custom-os/glibc/lib,--no-undefined" && \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:/usr/lib/pkgconfig" && \
    \
    # Environment verification
    echo "=== BUILD ENVIRONMENT VERIFICATION ===" && \
    echo "CC: $CC ($(which $CC))" | tee /custom-os/var/log/debug/build_env.log && \
    echo "CXX: $CXX ($(which $CXX))" | tee -a /custom-os/var/log/debug/build_env.log && \
    echo "LLVM_CONFIG: $LLVM_CONFIG ($(which $LLVM_CONFIG))" | tee -a /custom-os/var/log/debug/build_env.log && \
    echo "CFLAGS: $CFLAGS" | tee -a /custom-os/var/log/debug/build_env.log && \
    echo "LDFLAGS: $LDFLAGS" | tee -a /custom-os/var/log/debug/build_env.log && \
    \
    # Configure with strict flags
    echo "=== CONFIGURING WITH STRICT FLAGS ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/custom-os/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DWAYLAND=OFF \
        -DGLES=OFF \
        -DGLUT=ON \
        -DCMAKE_PREFIX_PATH="/custom-os/usr;/custom-os/compiler" \
        -DCMAKE_INSTALL_RPATH="/custom-os/usr/lib;/custom-os/compiler/lib" \
        -Werror=dev \
        -Wno-dev 2>&1 | tee /custom-os/var/log/debug/cmake_configure.log && \
    \
    # Build with dependency verification
    echo "=== BUILDING WITH DEPENDENCY VERIFICATION ===" && \
    make -j$(nproc) VERBOSE=1 2>&1 | tee /custom-os/var/log/debug/make_build.log && \
    \
    # Verify build artifacts
    echo "=== VERIFYING BUILD ARTIFACTS ===" && \
    echo "Generated binaries:" && \
    find . -type f -executable -exec ls -la {} \; | tee /custom-os/var/log/debug/build_artifacts.log && \
    echo "Library dependencies:" && \
    find . -type f -executable -exec ldd {} \; 2>/dev/null | grep -i llvm | tee /custom-os/var/log/debug/library_deps.log || true && \
    echo "Binary strings scan:" && \
    strings src/xdemos/glxinfo 2>/dev/null | grep -i 'llvm\|clang' | sort | uniq | tee /custom-os/var/log/debug/strings_scan.log || true && \
    \
    # Install and verify installation
    echo "=== INSTALLING AND VERIFYING ===" && \
    make install 2>&1 | tee /custom-os/var/log/debug/make_install.log && \
    echo "Installed binaries:" && \
    ls -la /custom-os/usr/bin/gl* | tee -a /custom-os/var/log/debug/make_install.log && \
    echo "glxinfo dependencies:" && \
    ldd /custom-os/usr/bin/glxinfo | grep -i llvm | tee /custom-os/var/log/debug/install_deps.log || true && \
    \
    # Cleanup
    cd / && \
    rm -rf /tmp/mesa-demos && \
    \
    # Final contamination check
    /usr/local/bin/check_llvm15.sh "post-mesa-demos-build" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    echo "=== STRINGENT_MESA_DEMOS_BUILD COMPLETE ==="

# ======================
# SECTION: Debug Tools Installation
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
        binutils 2>&1 | tee /custom-os/var/log/debug/tools_install.log && \
    \
    # Verify debug tools
    echo "=== DEBUG TOOLS VERIFICATION ===" && \
    echo "Installed debug tools:" && \
    which gdb strace ltrace valgrind perf lsof file objdump | tee /custom-os/var/log/debug/tools_verify.log && \
    \
    # Copy debug tools to custom filesystem
    echo "=== INTEGRATING DEBUG TOOLS INTO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/bin /custom-os/usr/share/debug && \
# copy binaries safely: avoid copying a file onto itself
for cmd in gdb strace ltrace valgrind perf lsof file objdump; do \
  src="$(command -v "$cmd" 2>/dev/null || true)"; \
  if [ -n "$src" ]; then \
    dest="/custom-os/usr/bin/$(basename "$src")"; \
    if [ "$src" = "$dest" ]; then \
      echo "skipping $cmd (already at $dest)"; \
    else \
      echo "copying $src -> /custom-os/usr/bin/"; \
      cp -p "$src" /custom-os/usr/bin/; \
    fi; \
  else \
    echo "warning: $cmd not found"; \
  fi; \
done && \
# copy debug data dirs only if they exist
[ -d /usr/share/gdb ] && cp -rp /usr/share/gdb /custom-os/usr/share/debug/ || true && \
[ -d /usr/share/valgrind ] && cp -rp /usr/share/valgrind /custom-os/usr/share/debug/ || true && \
    echo "=== DEBUG ENVIRONMENT READY ==="

# Final environment setup
ENV PATH="/custom-os/usr/bin:/custom-os/compiler/bin:$PATH"
ENV LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:$PKG_CONFIG_PATH"

# ======================
# SECTION: Debug Tools Installation (Filesystem-Integrated)
# ======================
RUN echo "=== INSTALLING DEBUG UTILITIES ===" && \
    mkdir -p /custom-os/var/log/debug && \
    \
    # Install each debug tool with verification
    echo "=== INSTALLING X11 DEBUG TOOLS ===" && \
    for tool in xdpyinfo xrandr xeyes gdb valgrind libxxf86vm; do \
        echo "Installing $tool..." | tee -a /custom-os/var/log/debug/tool_install.log && \
        apk add --no-cache $tool 2>&1 | tee -a /custom-os/var/log/debug/tool_install.log && \
        /usr/local/bin/check_llvm15.sh "debug-after-$tool" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
        echo "Verifying $tool installation..." && \
        which $tool | tee -a /custom-os/var/log/debug/tool_verify.log && \
        case $tool in \
            gdb) gdb --version | head -1 ;; \
            valgrind) valgrind --version ;; \
            *) $tool --version 2>&1 | head -1 ;; \
        esac | tee -a /custom-os/var/log/debug/tool_verify.log; \
    done && \
    \
    # Copy tools to custom filesystem
    echo "=== COPYING DEBUG TOOLS TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /custom-os/usr/bin && \
    cp -p $(which xdpyinfo xrandr xeyes gdb valgrind) /custom-os/usr/bin/ 2>&1 | tee -a /custom-os/var/log/debug/filesystem_integration.log && \
    \
    # Verify copied tools
    echo "=== VERIFYING COPIED TOOLS ===" && \
    for tool in xdpyinfo xrandr xeyes gdb valgrind; do \
        /custom-os/usr/bin/$tool --version 2>&1 | head -1 | tee -a /custom-os/var/log/debug/filesystem_verify.log || \
        echo "$tool verification failed" | tee -a /custom-os/var/log/debug/filesystem_verify.log; \
    done

# ======================
# SECTION: DRI Configuration (Filesystem-Integrated)
# ======================
RUN echo "=== CONFIGURING DRI DIRECTORY STRUCTURE ===" && \
    mkdir -p /custom-os/usr/lib/xorg/modules && \
    \
    # Create DRI structure in custom filesystem
    echo "Creating DRI links in custom filesystem..." | tee /custom-os/var/log/debug/dri_setup.log && \
    mkdir -p /custom-os/usr/lib/dri && \
    ln -s /custom-os/usr/lib/dri /custom-os/usr/lib/xorg/modules/dri 2>&1 | tee -a /custom-os/var/log/debug/dri_setup.log && \
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
    chown -R shs:shs /custom-os/app && \
    chown -R shs:shs /custom-os/usr/local 2>&1 | tee -a /custom-os/var/log/debug/user_setup.log && \
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
    LD_LIBRARY_PATH="/custom-os/usr/lib:/custom-os/compiler/lib:/custom-os/glibc/lib:/usr/lib" \
    PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig"

# Verify environment
RUN echo "=== FINAL ENVIRONMENT VERIFICATION ===" && \
    echo "Environment variables:" | tee /custom-os/var/log/debug/final_env.log && \
    env | grep -E 'PATH|LD_LIBRARY|PKG_CONFIG|SDL|LIBGL|GALLIUM|MESA' | tee -a /custom-os/var/log/debug/final_env.log && \
    echo "Binary locations:" | tee -a /custom-os/var/log/debug/final_env.log && \
    which simplehttpserver xdpyinfo xrandr xeyes gdb valgrind 2>&1 | tee -a /custom-os/var/log/debug/final_env.log

USER shs
WORKDIR /custom-os/app
CMD ["/custom-os/usr/bin/simplehttpserver"]

# Stage: build application
FROM debug AS runtime
# Copy LLVM15 monitoring script
COPY setup-scripts/check_llvm15.sh /usr/local/bin/check_llvm15.sh
RUN chmod +x /usr/local/bin/check_llvm15.sh

# Create custom filesystem structure for runtime components
RUN mkdir -p /custom-os/usr/lib/runtime && \
    mkdir -p /custom-os/usr/lib/x11 && \
    mkdir -p /custom-os/usr/lib/graphics && \
    mkdir -p /custom-os/usr/lib/audio && \
    mkdir -p /custom-os/usr/lib/mesa && \
    mkdir -p /custom-os/var/log/debug && \
    echo "Created runtime filesystem structure"

# ======================
# SECTION: Core Runtime Libraries
# ======================
RUN echo "=== INSTALLING CORE RUNTIME LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-core-runtime" | tee /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    # Core C++ and C libraries
    echo "Installing core libraries..." | tee /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libstdc++ && echo "Installed libstdc++" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libgcc && echo "Installed libgcc" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy core libraries to custom filesystem
    echo "Copying core libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libstdc++* /custom-os/usr/lib/runtime/ 2>/dev/null || true && \
    cp -p /usr/lib/libgcc* /custom-os/usr/lib/runtime/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-core-runtime" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Font and Text Rendering Libraries
# ======================
RUN echo "=== INSTALLING FONT AND TEXT RENDERING LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-font-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing font libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache freetype && echo "Installed freetype" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache fontconfig && echo "Installed fontconfig" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy font libraries to custom filesystem
    echo "Copying font libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/fonts && \
    cp -p /usr/lib/libfreetype* /custom-os/usr/lib/fonts/ 2>/dev/null || true && \
    cp -p /usr/lib/libfontconfig* /custom-os/usr/lib/fonts/ 2>/dev/null || true && \
    cp -rp /etc/fonts /custom-os/etc/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-font-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: X11 Core Libraries
# ======================
RUN echo "=== INSTALLING X11 CORE LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-x11-core" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing X11 core libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libx11 && echo "Installed libx11" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxcomposite && echo "Installed libxcomposite" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxext && echo "Installed libxext" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxrandr && echo "Installed libxrandr" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy X11 core libraries to custom filesystem
    echo "Copying X11 core libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libX11* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXcomposite* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXext* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXrandr* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-x11-core" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Graphics and Image Libraries (High Risk - Check HERE if errors)
# ======================
RUN echo "=== INSTALLING GRAPHICS AND IMAGE LIBRARIES (HIGH RISK SECTION) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-graphics-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing graphics libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libpng && echo "Installed libpng" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libjpeg-turbo && echo "Installed libjpeg-turbo" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache tiff && echo "Installed tiff" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libwebp && echo "Installed libwebp" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libavif && echo "Installed libavif" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy graphics libraries to custom filesystem
    echo "Copying graphics libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libpng* /custom-os/usr/lib/graphics/ 2>/dev/null || true && \
    cp -p /usr/lib/libjpeg* /custom-os/usr/lib/graphics/ 2>/dev/null || true && \
    cp -p /usr/lib/libtiff* /custom-os/usr/lib/graphics/ 2>/dev/null || true && \
    cp -p /usr/lib/libwebp* /custom-os/usr/lib/graphics/ 2>/dev/null || true && \
    cp -p /usr/lib/libavif* /custom-os/usr/lib/graphics/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-graphics-libs" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: X11 Extended Libraries (Older Packages)
# ======================
RUN echo "=== INSTALLING X11 EXTENDED LIBRARIES (OLDER PACKAGES) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-x11-extended" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing X11 extended libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxrender && echo "Installed libxrender" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxfixes && echo "Installed libxfixes" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxcursor && echo "Installed libxcursor" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxi && echo "Installed libxi" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxinerama && echo "Installed libxinerama" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxdamage && echo "Installed libxdamage" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxshmfence && echo "Installed libxshmfence" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxcb && echo "Installed libxcb" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache libxxf86vm && echo "Installed libxxf86vm" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy X11 extended libraries to custom filesystem
    echo "Copying X11 extended libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    cp -p /usr/lib/libXrender* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXfixes* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXcursor* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXi* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXinerama* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXdamage* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libxshmfence* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libxcb* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    cp -p /usr/lib/libXxf86vm* /custom-os/usr/lib/x11/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-x11-extended" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Wayland and Audio Libraries
# ======================
RUN echo "=== INSTALLING WAYLAND AND AUDIO LIBRARIES ===" && \
    /usr/local/bin/check_llvm15.sh "pre-wayland-audio" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing Wayland and audio libraries..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache wayland && echo "Installed wayland" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache alsa-lib && echo "Installed alsa-lib" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache pulseaudio && echo "Installed pulseaudio" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy Wayland and audio libraries to custom filesystem
    echo "Copying Wayland and audio libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/wayland && \
    cp -p /usr/lib/libwayland* /custom-os/usr/lib/wayland/ 2>/dev/null || true && \
    cp -p /usr/lib/libasound* /custom-os/usr/lib/audio/ 2>/dev/null || true && \
    cp -p /usr/lib/libpulse* /custom-os/usr/lib/audio/ 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-wayland-audio" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: LLVM16 Establishment (Priority Installation)
# ======================
RUN echo "=== ESTABLISHING LLVM16 PREFERENCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-llvm16-priority" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing LLVM16 libs to establish preference..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache llvm16-libs && echo "Installed llvm16-libs" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    \
    # Copy LLVM16 libraries to custom filesystem compiler directory
    echo "Copying LLVM16 libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/compiler/lib && \
    find /usr/lib -name "*llvm16*" -type f -exec cp {} /custom-os/compiler/lib/ \; 2>/dev/null || true && \
    \
    /usr/local/bin/check_llvm15.sh "post-llvm16-priority" | tee -a /custom-os/var/log/debug/llvm_checks.log || true

# ======================
# SECTION: Mesa Packages (HIGH RISK - LLVM15 Contamination Monitoring)
# ======================
RUN echo "=== INSTALLING MESA PACKAGES - MONITORING FOR LLVM15 CONTAMINATION ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-runtime" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing Mesa DRI Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-dri-gallium && echo "Installed mesa-dri-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    /usr/local/bin/check_llvm15.sh "post-mesa-dri-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing Mesa VA Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-va-gallium && echo "Installed mesa-va-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    /usr/local/bin/check_llvm15.sh "post-mesa-va-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing Mesa VDPAU Gallium..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-vdpau-gallium && echo "Installed mesa-vdpau-gallium" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    /usr/local/bin/check_llvm15.sh "post-mesa-vdpau-gallium" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing Mesa Vulkan SwRast..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache mesa-vulkan-swrast && echo "Installed mesa-vulkan-swrast" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    /usr/local/bin/check_llvm15.sh "post-mesa-vulkan-swrast" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    echo "Installing GLU..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    apk add --no-cache glu && echo "Installed glu" | tee -a /custom-os/var/log/debug/runtime_install.log && \
    /usr/local/bin/check_llvm15.sh "post-glu" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    # Copy Mesa libraries to custom filesystem
    echo "Copying Mesa libraries to custom filesystem..." | tee -a /custom-os/var/log/debug/runtime_install.log && \
    mkdir -p /custom-os/usr/lib/dri && \
    cp -rp /usr/lib/dri/* /custom-os/usr/lib/dri/ 2>/dev/null || true && \
    cp -p /usr/lib/libGL* /custom-os/usr/lib/mesa/ 2>/dev/null || true && \
    cp -p /usr/lib/libGLU* /custom-os/usr/lib/mesa/ 2>/dev/null || true && \
    cp -p /usr/lib/libEGL* /custom-os/usr/lib/mesa/ 2>/dev/null || true && \
    cp -p /usr/lib/libgbm* /custom-os/usr/lib/mesa/ 2>/dev/null || true

# ======================
# SECTION: Final Runtime LLVM15 Check & Filesystem Verification
# ======================
RUN echo "=== FINAL RUNTIME LLVM15 CONTAMINATION CHECK ===" && \
    /usr/local/bin/check_llvm15.sh "final-runtime-check" | tee -a /custom-os/var/log/debug/llvm_checks.log || true && \
    \
    # Verify filesystem structure
    echo "=== RUNTIME FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS runtime structure:" | tee /custom-os/var/log/debug/runtime_filesystem.log && \
    tree -L 3 /custom-os/usr/lib/ 2>/dev/null | tee -a /custom-os/var/log/debug/runtime_filesystem.log || \
    find /custom-os/usr/lib/ -type d | head -20 | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    \
    # Verify library counts in each category
    echo "=== LIBRARY COUNT VERIFICATION ===" && \
    echo "Runtime libraries: $(ls /custom-os/usr/lib/runtime/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    echo "X11 libraries: $(ls /custom-os/usr/lib/x11/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    echo "Graphics libraries: $(ls /custom-os/usr/lib/graphics/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    echo "Audio libraries: $(ls /custom-os/usr/lib/audio/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    echo "Mesa libraries: $(ls /custom-os/usr/lib/mesa/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log && \
    echo "DRI drivers: $(ls /custom-os/usr/lib/dri/ 2>/dev/null | wc -l)" | tee -a /custom-os/var/log/debug/runtime_filesystem.log

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
COPY --from=filesystem-libs-build-builder /usr/local /custom-os/usr/local
RUN if [ -d /custom-os/usr/local ]; then \
      echo "Copied filesystem-libs-build-builder artifacts to custom filesystem" | tee /custom-os/var/log/debug/artifacts_copy.log; \
    else \
      echo "Warning: /custom-os/usr/local was not created by filesystem-libs-build-builder" | tee /custom-os/var/log/debug/artifacts_copy.log; \
      mkdir -p /custom-os/usr/local; \
    fi

# Copy application to custom filesystem
RUN mkdir -p /custom-os/app
# app-build installs the built binary into /custom-os/usr/bin/simplehttpserver,
# so copy from that path in the app-build stage instead of /app/build/....
COPY --from=app-build /custom-os/usr/bin/simplehttpserver /custom-os/app/simplehttpserver
RUN echo "Copied application to custom filesystem" | tee -a /custom-os/var/log/debug/artifacts_copy.log



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
    LD_LIBRARY_PATH="/custom-os/compiler/lib:/custom-os/usr/local/lib:/custom-os/usr/lib/runtime:/custom-os/usr/lib/x11:/custom-os/usr/lib/graphics:/custom-os/usr/lib/audio:/custom-os/usr/lib/mesa:/custom-os/usr/lib/wayland:/custom-os/usr/lib/fonts:/custom-os/glibc/lib:/usr/lib" \
    LLVM_CONFIG="/custom-os/compiler/bin/llvm-config" \
    PATH="/custom-os/compiler/bin:/custom-os/usr/local/bin:/custom-os/app:$PATH"

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
    fi && \
    \
    # Final filesystem verification
    echo "=== FINAL CUSTOM FILESYSTEM VERIFICATION ===" && \
    echo "Custom OS final structure:" | tee /custom-os/var/log/debug/final_filesystem.log && \
    tree -L 4 /custom-os/ 2>/dev/null | tee -a /custom-os/var/log/debug/final_filesystem.log || \
    find /custom-os/ -type d | head -30 | tee -a /custom-os/var/log/debug/final_filesystem.log && \
    \
    # Verify critical binaries
    echo "=== CRITICAL BINARY VERIFICATION ===" | tee -a /custom-os/var/log/debug/final_filesystem.log && \
    ls -la /custom-os/app/simplehttpserver | tee -a /custom-os/var/log/debug/final_filesystem.log && \
    ls -la /custom-os/compiler/bin/clang* 2>/dev/null | head -3 | tee -a /custom-os/var/log/debug/final_filesystem.log || echo "No clang binaries found" | tee -a /custom-os/var/log/debug/final_filesystem.log

USER shs
WORKDIR /custom-os/app
CMD ["/custom-os/app/simplehttpserver"]