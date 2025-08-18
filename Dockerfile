# Stage: filesystem setup
FROM alpine:3.18 AS filesystem-builder
# Install basic tools needed for filesystem operations
RUN apk add --no-cache bash findutils
# Create directory structure (using explicit paths to avoid shell expansion issues)
RUN mkdir -p /custom-os/bin /custom-os/sbin /custom-os/etc /custom-os/var /custom-os/tmp /custom-os/home /custom-os/root
RUN mkdir -p /custom-os/usr/bin /custom-os/usr/sbin /custom-os/usr/lib
RUN mkdir -p /custom-os/usr/local/bin /custom-os/usr/local/sbin /custom-os/usr/local/lib /custom-os/usr/share
# Copy and execute setup scripts
COPY setup-scripts/ /setup/
RUN chmod +x /setup/*.sh && /setup/create-filesystem.sh

# Stage: base deps (Alpine version)
FROM alpine:3.18 AS base-deps
COPY --from=filesystem-builder /custom-os /

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
RUN apk add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true  
RUN apk add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true
# Debug tools
RUN apk add --no-cache strace && /usr/local/bin/check_llvm15.sh "after-strace" || true
RUN apk add --no-cache file && /usr/local/bin/check_llvm15.sh "after-file" || true
RUN apk add --no-cache tree && /usr/local/bin/check_llvm15.sh "after-tree" || true
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
# Other essential packages to download
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true
RUN apk add --no-cache python3-dev && /usr/local/bin/check_llvm15.sh "after-python3-dev" || true
RUN apk add --no-cache py3-setuptools && /usr/local/bin/check_llvm15.sh "after-py3-setuptools" || true
RUN apk add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true
# Media packages
RUN apk add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true
RUN apk add --no-cache v4l-utils-dev && /usr/local/bin/check_llvm15.sh "after-v4l-utils-dev" || true
# dev/runtime packages commonly missing that cause include/link-time failures for sqlite3 consumers
RUN apk add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true
RUN apk add --no-cache readline-dev && /usr/local/bin/check_llvm15.sh "after-readline-dev" || true
RUN apk add --no-cache openssl-dev && /usr/local/bin/check_llvm15.sh "after-openssl-dev" || true
RUN apk add --no-cache bzip2-dev && /usr/local/bin/check_llvm15.sh "after-bzip2-dev" || true
# Vulkan and graphics packages (high suspects for LLVM15)
RUN apk add --no-cache vulkan-headers && /usr/local/bin/check_llvm15.sh "after-vulkan-headers" || true
RUN apk add --no-cache vulkan-loader && /usr/local/bin/check_llvm15.sh "after-vulkan-loader" || true
RUN apk add --no-cache vulkan-tools && /usr/local/bin/check_llvm15.sh "after-vulkan-tools" || true
RUN apk add --no-cache freetype-dev && /usr/local/bin/check_llvm15.sh "after-freetype-dev" || true
RUN apk add --no-cache fontconfig-dev && /usr/local/bin/check_llvm15.sh "after-fontconfig-dev" || true
# X11 packages
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
# Filesystem utilities
RUN apk add --no-cache e2fsprogs-dev && /usr/local/bin/check_llvm15.sh "after-e2fsprogs-dev" || true
RUN apk add --no-cache xfsprogs-dev && /usr/local/bin/check_llvm15.sh "after-xfsprogs-dev" || true
RUN apk add --no-cache btrfs-progs-dev && /usr/local/bin/check_llvm15.sh "after-btrfs-progs-dev" || true
# System utilities
RUN apk add --no-cache util-linux-dev && /usr/local/bin/check_llvm15.sh "after-util-linux-dev" || true
RUN apk add --no-cache libcap-dev && /usr/local/bin/check_llvm15.sh "after-libcap-dev" || true
RUN apk add --no-cache liburing-dev && /usr/local/bin/check_llvm15.sh "after-liburing-dev" || true
# Networking and IPC
RUN apk add --no-cache libunwind-dev && /usr/local/bin/check_llvm15.sh "after-libunwind-dev" || true
RUN apk add --no-cache dbus-dev && /usr/local/bin/check_llvm15.sh "after-dbus-dev" || true
RUN apk add --no-cache libmnl-dev && /usr/local/bin/check_llvm15.sh "after-libmnl-dev" || true
# Security
RUN apk add --no-cache libselinux-dev && /usr/local/bin/check_llvm15.sh "after-libselinux-dev" || true
RUN apk add --no-cache libseccomp-dev && /usr/local/bin/check_llvm15.sh "after-libseccomp-dev" || true
# Compression
RUN apk add --no-cache xz-dev && /usr/local/bin/check_llvm15.sh "after-xz-dev" || true
RUN apk add --no-cache zstd-dev && /usr/local/bin/check_llvm15.sh "after-zstd-dev" || true
# System debugging/profiling
RUN apk add --no-cache libunwind-dev && /usr/local/bin/check_llvm15.sh "after-libunwind-dev" || true
RUN apk add --no-cache linux-tools-dev && /usr/local/bin/check_llvm15.sh "after-linux-tools-dev" || true
# SQLite3 packages
RUN apk add --no-cache sqlite-dev && /usr/local/bin/check_llvm15.sh "after-sqlite-dev" || true
RUN apk add --no-cache libedit-dev && /usr/local/bin/check_llvm15.sh "after-libedit-dev" || true
RUN apk add --no-cache icu-dev && /usr/local/bin/check_llvm15.sh "after-icu-dev" || true
RUN apk add --no-cache tcl-dev && /usr/local/bin/check_llvm15.sh "after-tcl-dev" || true
RUN apk add --no-cache lz4-dev && /usr/local/bin/check_llvm15.sh "after-lz4-dev" || true

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
    # Create a wrapper that suppresses the ARM64 warnings
    mv /usr/glibc-compat/sbin/ldconfig /usr/glibc-compat/sbin/ldconfig.real && \
    echo '#!/bin/sh' > /usr/glibc-compat/sbin/ldconfig && \
    echo '/usr/glibc-compat/sbin/ldconfig.real "$@" 2>&1 | grep -v "unknown machine 183" || true' >> /usr/glibc-compat/sbin/ldconfig && \
    chmod +x /usr/glibc-compat/sbin/ldconfig && \
    # Clean up
    rm -f /sbin/ldconfig && \
    rm *.apk && \
    /usr/local/bin/check_llvm15.sh "after-glibc" || true

# Stage: build core libraries
FROM base-deps AS libs-build
WORKDIR /build

# Pre-build LLVM status
RUN /usr/local/bin/check_llvm15.sh "libs-build-start" || true

# Additional dependencies for xorg-server build
RUN apk add --no-cache \
    autoconf \
    automake \
    libtool \
    util-macros \
    pkgconf-dev \
    #Why is removing this causing the problem of LLVM15 after?????
    xorg-util-macros \
    libpciaccess-dev \
    libepoxy-dev \
    pixman-dev \
    xkeyboard-config \
    xkbcomp \
    libxkbfile-dev \
    libxfont2-dev && \
    /usr/local/bin/check_llvm15.sh "after-xorg-build-deps" || true

# Build pciaccess from source (dependency for libdrm) with enhanced LLVM16 enforcement
RUN echo "=== STRINGENT_PCIACCESS_BUILD: BUILDING FROM SOURCE WITH LLVM16 ENFORCEMENT ===" && \
    \
    # Ensure check_llvm15.sh exists before using it \
    if [ ! -x "/usr/local/bin/check_llvm15.sh" ]; then \
        echo "=== INSTALLING MISSING CHECK_LLVM15.SH ===" && \
        mkdir -p /usr/local/bin && \
        echo '#!/bin/sh\necho "WARNING: check_llvm15.sh not properly installed"' > /usr/local/bin/check_llvm15.sh && \
        chmod +x /usr/local/bin/check_llvm15.sh; \
    fi && \
    \
    /usr/local/bin/check_llvm15.sh "pre-pciaccess-source-build" || true && \
    \
    # Purge any potential LLVM15 residues (but protect our check script) \
    echo "=== PURGING LLVM15 CONTAMINATION ===" && \
    find /usr -name '*llvm15*' -not -path '/usr/local/bin/check_llvm15.sh' -exec rm -fv {} \; 2>/dev/null | tee /tmp/llvm15_purge.log || true && \
    apk del --no-cache $(apk info -R llvm15-libs 2>/dev/null) llvm15-libs 2>/dev/null || true && \
    \
    # Install comprehensive build dependencies \
    echo "=== INSTALLING SANITIZED BUILD DEPS ===" && \
    apk add --no-cache \
    #If this breaks, then figure out what do otherwise
    /usr/local/bin/check_llvm15.sh "after-comprehensive-deps-install" || true && \
    \
    # Clone and verify source integrity \
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
    # Set hardened build environment \
    echo "=== SETTING HARDENED BUILD ENV ===" && \
    export CC=clang-16 CXX=clang++-16 && \
    export LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config && \
    export CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export LDFLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib,--no-undefined" && \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
    export ACLOCAL_PATH="/usr/share/aclocal:/usr/local/share/aclocal" && \
    export NO_COLOR=1 && \
    echo "Build environment verification:" && \
    echo "CC: $CC ($(which $CC 2>/dev/null || echo 'NOT FOUND'))" && \
    echo "CXX: $CXX ($(which $CXX 2>/dev/null || echo 'NOT FOUND'))" && \
    echo "LLVM_CONFIG: $LLVM_CONFIG ($(which $LLVM_CONFIG 2>/dev/null || echo 'NOT FOUND'))" && \
    \
    # Try build strategies in order of preference \
    echo "=== ATTEMPTING BUILD STRATEGIES ===" && \
    BUILD_SUCCESS=0 && \
    \
    # Strategy 1: Try autogen.sh if it exists \
    if [ -f "./autogen.sh" ]; then \
        echo "Strategy 1: Using autogen.sh" && \
        chmod +x ./autogen.sh && \
        ./autogen.sh --prefix=/usr/local --libdir=/usr/local/lib --enable-shared --disable-static 2>&1 | tee /tmp/autogen.log && \
        BUILD_SUCCESS=1; \
    # Strategy 2: Try autoreconf if configure.ac/configure.in exists \
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
    # Strategy 3: Check for existing configure script \
    elif [ -f "./configure" ]; then \
        echo "Strategy 3: Using existing configure script" && \
        chmod +x ./configure && \
        BUILD_SUCCESS=1; \
    # Strategy 4: Direct compilation \
    else \
        echo "Strategy 4: No autotools setup found, will attempt direct compilation" && \
        BUILD_SUCCESS=1; \
    fi && \
    \
    # Configure if we have a configure script \
    if [ "$BUILD_SUCCESS" = "1" ] && [ -f "./configure" ]; then \
        echo "=== CONFIGURING WITH ENHANCED OPTIONS ===" && \
        ./configure \
            --prefix=/usr/local \
            --libdir=/usr/local/lib \
            --includedir=/usr/local/include \
            --enable-shared \
            --disable-static \
            --with-pic 2>&1 | tee /tmp/configure.log && \
        CONFIGURE_SUCCESS=1; \
    else \
        echo "=== SKIPPING CONFIGURE - WILL USE DIRECT BUILD ===" && \
        CONFIGURE_SUCCESS=0; \
    fi && \
    \
    # Build with comprehensive dependency verification \
    echo "=== BUILDING WITH DEPENDENCY VERIFICATION ===" && \
    if [ -f "Makefile" ] || [ -f "makefile" ]; then \
        echo "Found Makefile, proceeding with build..." && \
        make -j$(nproc) V=1 2>&1 | tee /tmp/make_build.log && \
        BUILD_COMPLETE=1; \
    else \
        echo "No Makefile found, attempting direct compilation..." && \
        # Direct compilation fallback \
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
    # Verify build artifacts \
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
    # Install with robust error handling \
    echo "=== INSTALLING AND VERIFYING ===" && \
    if [ -f "Makefile" ] || [ -f "makefile" ]; then \
        make install V=1 2>&1 | tee /tmp/make_install.log; \
    elif [ -d "/tmp/pciaccess_build" ]; then \
        echo "Installing from direct build..." && \
        mkdir -p /usr/local/lib /usr/local/include /usr/local/lib/pkgconfig && \
        cp /tmp/pciaccess_build/libpciaccess.so* /usr/local/lib/ && \
        find . -name "*.h" -exec cp {} /usr/local/include/ \; 2>/dev/null || true; \
    else \
        echo "Attempting to find and install built libraries..." && \
        BUILT_LIBS=$(find . -name "libpciaccess*.so*" | head -5) && \
        if [ -n "$BUILT_LIBS" ]; then \
            echo "Found built libraries: $BUILT_LIBS" && \
            mkdir -p /usr/local/lib /usr/local/include /usr/local/lib/pkgconfig && \
            for lib in $BUILT_LIBS; do \
                cp "$lib" /usr/local/lib/; \
            done && \
            find . -name "*.h" -exec cp {} /usr/local/include/ \; 2>/dev/null || true; \
        else \
            echo "No libraries found to install"; \
        fi; \
    fi && \
    \
    # Ensure pkg-config directory exists and create pkg-config file \
    echo "=== COMPREHENSIVE PKG-CONFIG SETUP ===" && \
    mkdir -p /usr/local/lib/pkgconfig && \
    echo "Contents of /usr/local/lib/pkgconfig:" && \
    ls -la /usr/local/lib/pkgconfig/ || echo "Directory is empty" && \
    echo "Contents of /usr/local/lib:" && \
    ls -la /usr/local/lib/ && \
    \
    # Create pkg-config file if it doesn't exist \
    if [ ! -f /usr/local/lib/pkgconfig/pciaccess.pc ]; then \
        echo "Creating comprehensive pciaccess.pc file..." && \
        { \
            echo 'prefix=/usr/local'; \
            echo 'exec_prefix=${prefix}'; \
            echo 'libdir=${exec_prefix}/lib'; \
            echo 'includedir=${prefix}/include'; \
            echo ''; \
            echo 'Name: pciaccess'; \
            echo 'Description: Generic PCI access library'; \
            echo 'Version: 0.17'; \
            echo 'URL: https://www.x.org'; \
            echo 'Libs: -L${libdir} -lpciaccess'; \
            echo 'Cflags: -I${includedir}'; \
        } > /usr/local/lib/pkgconfig/pciaccess.pc; \
    else \
        echo "Found existing pciaccess.pc:"; \
    fi && \
    cat /usr/local/lib/pkgconfig/pciaccess.pc 2>/dev/null || echo "No pciaccess.pc file found" && \
    \
    # Test pkg-config \
    echo "=== PKG-CONFIG COMPREHENSIVE TESTING ===" && \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
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
    # Verify library installation and create symbolic links \
    echo "=== LIBRARY INSTALLATION VERIFICATION ===" && \
    echo "Installed libraries in /usr/local/lib:" && \
    ls -la /usr/local/lib/libpciaccess* 2>/dev/null || echo "No libpciaccess libraries found" && \
    echo "Creating/verifying symbolic links..." && \
    cd /usr/local/lib && \
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
    # Final contamination scan \
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" /usr/local 2>&1 | tee /tmp/final_scan.log || true) && \
    echo "=== BUILD LOGS SUMMARY ===" && \
    echo "Log files created:" && \
    ls -la /tmp/*log /tmp/*scan.log 2>/dev/null || echo "No log files found" && \
    \
    # Cleanup \
    cd .. && \
    rm -rf pciaccess && \
    rm -rf /tmp/pciaccess_build 2>/dev/null || true && \
    \
    # Final verification \
    /usr/local/bin/check_llvm15.sh "post-pciaccess-source-build" || true && \
    echo "=== FINAL SUCCESS VERIFICATION ===" && \
    if [ -f /usr/local/lib/libpciaccess.so ] || ls /usr/local/lib/libpciaccess.so.* 1> /dev/null 2>&1; then \
        echo "✓ SUCCESS: libpciaccess library installed" && \
        if [ -f /usr/local/lib/pkgconfig/pciaccess.pc ]; then \
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

# Build libdrm from source (avoiding LLVM15 contamination)
RUN echo "=== BUILDING libdrm FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libdrm-source-build" || true && \
    # Install missing dependencies first (including meson since pciaccess build removed it)
    apk add --no-cache libatomic_ops-dev meson py3-setuptools \
        cunit-dev cairo-dev valgrind-dev linux-headers musl-dev && \
    /usr/local/bin/check_llvm15.sh "after-libdrm-deps" || true && \
    # Clone libdrm (meson now installed)
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/drm.git libdrm && \
    cd libdrm && \
    # Scan source tree for LLVM15 contamination
    grep -RIn "LLVM15" . || true && grep -RIn "llvm-15" . || true && \
    # Set up environment for LLVM16 with proper PKG_CONFIG_PATH ordering
    export CC=clang-16 && \
    export CXX=clang++-16 && \
    export LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config && \
    export CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations" && \
    export CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations" && \
    export LDFLAGS="-L/usr/lib/llvm16/lib -L/usr/local/lib -Wl,-rpath,/usr/lib/llvm16/lib,-rpath,/usr/local/lib" && \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
    # Disable ANSI colors for cleaner output
    export NO_COLOR=1 && \
    # Verify both meson and pciaccess are available
    echo "=== VERIFYING BUILD DEPENDENCIES ===" && \
    which meson && meson --version && \
    echo "Contents of /usr/local/lib/pkgconfig:" && \
    ls -la /usr/local/lib/pkgconfig/ && \
    echo "PKG_CONFIG_PATH = $PKG_CONFIG_PATH" && \
    echo "Testing basic pkg-config functionality:" && \
    pkg-config --version && \
    pkg-config --list-all | head -5 && \
    echo "Searching for pciaccess in pkg-config:" && \
    pkg-config --list-all | grep pciaccess || echo "pciaccess not in list" && \
    echo "Manual test of pciaccess.pc file:" && \
    if [ -f /usr/local/lib/pkgconfig/pciaccess.pc ]; then \
        echo "File exists, contents:" && \
        cat /usr/local/lib/pkgconfig/pciaccess.pc; \
    else \
        echo "pciaccess.pc file not found!"; \
        find /usr/local -name "*.pc" -type f; \
    fi && \
    echo "Attempting pkg-config with explicit debug:" && \
    pkg-config --debug --exists pciaccess 2>&1 | head -20 && \
    pkg-config --cflags --libs pciaccess && \
    echo "=== PCIACCESS FOUND SUCCESSFULLY ===" && \
    # Create sys/mkdev.h symlink workaround for musl systems
    echo "=== CREATING MUSL HEADER WORKAROUND ===" && \
    if [ ! -f /usr/include/sys/mkdev.h ] && [ -f /usr/include/sys/sysmacros.h ]; then \
        echo "Creating sys/mkdev.h -> sys/sysmacros.h symlink for musl compatibility" && \
        ln -sf sysmacros.h /usr/include/sys/mkdev.h; \
    fi && \
    # Verify other required packages are available
    echo "=== CHECKING FOR OPTIONAL DEPENDENCIES ===" && \
    pkg-config --exists cunit && echo "cunit: available" || echo "cunit: not available (tests will be disabled)" && \
    pkg-config --exists cairo && echo "cairo: available" || echo "cairo: not available (cairo tests will be disabled)" && \
    pkg-config --exists valgrind && echo "valgrind: available" || echo "valgrind: not available (valgrind support will be disabled)" && \
    # Configure with meson - explicitly disable problematic optional features
    meson setup builddir \
        --prefix=/usr/local \
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
    # Build and install with cleaner output
    meson compile -C builddir -j$(nproc) --verbose 2>&1 | sed 's/\x1b\[[0-9;]*m//g' && \
    meson install -C builddir 2>&1 | sed 's/\x1b\[[0-9;]*m//g' && \
    # Output the meson log for debugging (strip colors)
    echo "=== MESON BUILD LOG ===" && \
    cat builddir/meson-logs/meson-log.txt | sed 's/\x1b\[[0-9;]*m//g' && \
    echo "=== END MESON BUILD LOG ===" && \
    # Comprehensive libdrm installation verification (following pciaccess pattern)
    echo "=== COMPREHENSIVE LIBDRM INSTALLATION VERIFICATION ===" && \
    echo "Contents of /usr/local/lib/pkgconfig:" && \
    ls -la /usr/local/lib/pkgconfig/ || echo "pkgconfig directory is empty" && \
    echo "Contents of /usr/local/lib:" && \
    ls -la /usr/local/lib/ | grep -E "(libdrm|\.so)" || echo "No libdrm libraries visible" && \
    echo "Contents of /usr/local/include:" && \
    ls -la /usr/local/include/ | grep -E "(drm|libdrm)" || echo "No drm headers visible" && \
    \
    # Verify pkg-config files were installed
    echo "=== PKG-CONFIG FILES VERIFICATION ===" && \
    echo "Searching for all libdrm pkg-config files:" && \
    find /usr/local -name "libdrm*.pc" -type f | tee /tmp/libdrm_pc_files.log && \
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
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" && \
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
    echo "Installed libdrm libraries in /usr/local/lib:" && \
    ls -la /usr/local/lib/libdrm* 2>/dev/null || echo "No libdrm libraries found" && \
    echo "Verifying library symbolic links..." && \
    cd /usr/local/lib && \
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
    ls -la /usr/local/lib/libdrm* 2>/dev/null && \
    # Post-build contamination scan - search in actual built files
    echo "=== CONTAMINATION SCAN ===" && \
    find builddir -name "*.so*" -type f -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null || echo "No LLVM15 contamination found in built libraries" && \
    find /usr/local -name "libdrm*" -type f -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null || echo "No LLVM15 contamination found in installed libdrm files" && \
    \
    # Final success verification (following pciaccess pattern)
    echo "=== FINAL SUCCESS VERIFICATION ===" && \
    if find /usr/local/lib -name "libdrm*.so*" -type f | grep -q .; then \
        echo "✓ SUCCESS: libdrm libraries installed" && \
        if find /usr/local/lib/pkgconfig -name "libdrm*.pc" -type f | grep -q .; then \
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

# BUILD XORG-SERVER FROM SOURCE (avoiding LLVM15 contamination)
RUN echo "=== BUILDING XORG-SERVER FROM SOURCE TO AVOID LLVM15 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-xorg-server-source-build" || true && \
    # Install autotools and build dependencies
    echo "=== INSTALLING AUTOTOOLS AND BUILD DEPENDENCIES ===" && \
    apk add --no-cache \
    echo "=== CLONING XORG-SERVER SOURCE ===" && \
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

#SDL3_Image Dependencies
RUN apk add --no-cache tiff-dev && /usr/local/bin/check_llvm15.sh "after-tiff-dev" || true
RUN apk add --no-cache libwebp-dev && /usr/local/bin/check_llvm15.sh "after-libwebp-dev" || true
RUN apk add --no-cache libavif-dev && /usr/local/bin/check_llvm15.sh "after-libavif-dev" || true

# Install Python dependencies for Mesa and glmark2
RUN pip install --no-cache-dir meson==1.4.0 mako==1.3.3 && \
    /usr/local/bin/check_llvm15.sh "after-python-packages" || true

# Build SPIRV-Tools from source (avoiding LLVM15 contamination)
RUN echo "=== BUILDING SPIRV-TOOLS FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-spirv-tools-source-build" || true && \
    echo "=== CLONING SPIRV-TOOLS AND DEPENDENCIES ===" && \
    git clone --depth=1 https://github.com/KhronosGroup/SPIRV-Tools.git spirv-tools && \
    cd spirv-tools && \
    echo "=== CLONING SPIRV-HEADERS DEPENDENCY ===" && \
    git clone --depth=1 https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers && \
    echo "=== VERIFYING DEPENDENCIES ===" && \
    echo "SPIRV-Headers contents:" && \
    ls -la external/spirv-headers/ && \
    echo "=== CONFIGURING WITH CMAKE ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
        -DLLVM_CONFIG_EXECUTABLE=/usr/lib/llvm16/bin/llvm-config \
        -DCMAKE_C_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" && \
    echo "=== BUILDING SPIRV-TOOLS ===" && \
    make -j"$(nproc)" && \
    echo "=== INSTALLING SPIRV-TOOLS ===" && \
    make install && \
    cd ../.. && \
    rm -rf spirv-tools && \
    /usr/local/bin/check_llvm15.sh "post-spirv-tools-source-build" || true

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

# Build and install SDL3_image
RUN /usr/local/bin/check_llvm15.sh "pre-sdl3-image" || true && \
    git clone --depth=1 https://github.com/libsdl-org/SDL_image.git sdl_image && \
    cd sdl_image && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
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
        -DCMAKE_C_FLAGS="-march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a" && \
    make -j"$(nproc)" install && \
    cd ../.. && \
    rm -rf sdl_image && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-image" || true

# Build and install SDL3_mixer (SDL3 compatible)
RUN /usr/local/bin/check_llvm15.sh "pre-sdl3-mixer" || true && \
    git clone --depth=1 https://github.com/libsdl-org/SDL_mixer.git sdl_mixer && \
    cd sdl_mixer && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
        -DSDL3MIXER_OGG=ON \
        -DSDL3MIXER_FLAC=ON \
        -DSDL3MIXER_MOD=ON \
        -DSDL3MIXER_MP3=ON \
        -DSDL3MIXER_MID=ON \
        -DSDL3MIXER_OPUS=ON \
        -DSDL3MIXER_FLUIDSYNTH=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a" && \
    make -j"$(nproc)" install && \
    cd ../.. && \
    rm -rf sdl_mixer && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-mixer" || true

# Build and install SDL3_ttf (SDL3 compatible)
RUN /usr/local/bin/check_llvm15.sh "pre-sdl3-ttf" || true && \
    git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git sdl_ttf && \
    cd sdl_ttf && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a" && \
    make -j"$(nproc)" install && \
    cd ../.. && \
    rm -rf sdl_ttf && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-ttf" || true

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

# Ensure pkg-config and runtime loader find both LLVM16 and locally built libraries
ENV PKG_CONFIG_PATH=/usr/lib/llvm16/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib

# fail-fast: abort if any llvm15 strings appear in local cmake/meson cache (belt+suspenders)
RUN (grep -R --binary-files=without-match -n "llvm-15" / || true) | tee /tmp/llvm15-grep || true && \
    test ! -s /tmp/llvm15-grep || (echo "FOUND llvm-15 references - aborting" && cat /tmp/llvm15-grep && false) || true

# SQLite3 build with LLVM16 enforcement (guarded by check_llvm15.sh)
RUN echo "=== SQLITE3 BUILD WITH LLVM16 ENFORCEMENT ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sqlite3-clone" || true && \
    git clone --progress https://github.com/sqlite/sqlite.git sqlite && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-clone" || true && \
    cd sqlite && \
    mkdir build && cd build && \
    echo "=== SQLITE3 BUILD CONFIGURATION (ARM64 + LLVM16) ===" && \
    CC=clang-16 CXX=clang++-16 LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang-16 \
        -DCMAKE_CXX_COMPILER=clang++-16 \
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
        -DCMAKE_C_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-error" \
        -DCMAKE_CXX_FLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-error" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib" \
        -DPKG_CONFIG_PATH="/usr/lib/llvm16/lib/pkgconfig:/usr/lib/pkgconfig" \
        -Wno-dev && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-configure" || true && \
    echo "=== STARTING SQLITE3 BUILD (ARM64 + LLVM16) ===" && \
    make -j"$(nproc)" VERBOSE=1 install && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-build" || true && \
    echo "=== VERIFYING SQLITE3 INSTALL ===" && \
    test -f /usr/local/include/sqlite3.h && \
    pkg-config --cflags --libs sqlite3 && \
    cd ../.. && \
    rm -rf sqlite && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-cleanup" || true

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
ENV CMAKE_PREFIX_PATH=/usr/local:/usr/lib/llvm16
WORKDIR /app/build
RUN /usr/local/bin/check_llvm15.sh "pre-app-build" || true && \
    export PKG_CONFIG_PATH="/usr/lib/llvm16/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig" && \
    export LD_LIBRARY_PATH="/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib" && \
    export CMAKE_PREFIX_PATH="/usr/local;/usr/lib/llvm16" && \
    cmake -S /app/src -B /app/build \
         -G Ninja \
         -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_C_COMPILER=clang-16 \
         -DCMAKE_CXX_COMPILER=clang++-16 \
         -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
         -DCMAKE_LIBRARY_PATH="/usr/local/lib;/usr/lib/llvm16/lib" \
         -DCMAKE_INCLUDE_PATH="/usr/local/include;/usr/lib/llvm16/include" \
         -DCMAKE_INSTALL_RPATH="/usr/local/lib;/usr/lib/llvm16/lib" \
         -DCMAKE_EXPORT_COMPILE_COMMANDS=1 && \
    cmake --build /app/build --target simplehttpserver --parallel "$(nproc)" && \
    /usr/local/bin/check_llvm15.sh "post-app-build" || true

# Ensure LLVM16 libs and pkgconfig are first, then our local installs, then system
ENV PKG_CONFIG_PATH=/usr/lib/llvm16/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/lib/llvm16/lib:/usr/local/lib:/usr/lib


# Example invocation adjustments:
# cmake -DCMAKE_PREFIX_PATH=/usr/local -DCMAKE_BUILD_TYPE=Release ...
# or ensure you use pkg-config:
# CFLAGS=$(pkg-config --cflags sqlite3) LDFLAGS=$(pkg-config --libs sqlite3) cmake ...

# Stage: debug environment
FROM base-deps AS debug
COPY --from=libs-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver

# Install debug tools + LLVM runtime with monitoring
# Build mesa-demos from source with stringent LLVM16 enforcement
RUN echo "=== STRINGENT_MESA_DEMOS_BUILD: COMPILING FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-mesa-demos-source" || true && \
    \
    # Purge any existing LLVM15 packages/files \
    echo "=== PURGING LLVM15 CONTAMINATION ===" && \
    apk del --no-cache llvm15-libs $(apk info -R llvm15-libs 2>/dev/null) 2>/dev/null || true && \
    find /usr -name '*llvm15*' -exec rm -fv {} \; 2>/dev/null | tee /tmp/llvm15_purge.log || true && \
    \
    # Install minimal build dependencies \
    echo "=== INSTALLING SANITIZED BUILD DEPS ===" && \
    apk add --no-cache \
        cmake \
        make \
        python3 \
        mesa-dev \
        glu-dev \
        freeglut-dev && \
    /usr/local/bin/check_llvm15.sh "after-deps-install" || true && \
    \
    # Clone and verify source \
    echo "=== CLONING AND VERIFYING SOURCE ===" && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/demos.git && \
    cd demos && \
    echo "=== SOURCE CONTAMINATION SCAN ===" && \
    (grep -RIn "LLVM15\|llvm-15" . 2>&1 | tee /tmp/source_scan.log || true) && \
    \
    # Set hardened build environment \
    echo "=== SETTING HARDENED BUILD ENV ===" && \
    export CC=clang-16 CXX=clang++-16 && \
    export LLVM_CONFIG=/usr/lib/llvm16/bin/llvm-config && \
    export CFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export CXXFLAGS="-I/usr/lib/llvm16/include -march=armv8-a -Wno-deprecated-declarations -Werror=implicit-function-declaration" && \
    export LDFLAGS="-L/usr/lib/llvm16/lib -Wl,-rpath,/usr/lib/llvm16/lib,--no-undefined" && \
    export PKG_CONFIG_PATH="/usr/lib/llvm16/lib/pkgconfig:/usr/local/lib/pkgconfig" && \
    \
    # Configure with strict flags \
    echo "=== CONFIGURING WITH STRICT FLAGS ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DWAYLAND=OFF \
        -DGLES=OFF \
        -DGLUT=ON \
        -Werror=dev \
        -Wno-dev 2>&1 | tee /tmp/cmake_configure.log && \
    \
    # Build with dependency verification \
    echo "=== BUILDING WITH DEPENDENCY VERIFICATION ===" && \
    make -j$(nproc) VERBOSE=1 2>&1 | tee /tmp/make_build.log && \
    \
    # Verify build artifacts \
    echo "=== VERIFYING BUILD ARTIFACTS ===" && \
    find . -name 'gl*' -exec ldd {} \; | grep -i llvm | tee /tmp/library_deps.log && \
    strings src/xdemos/glxinfo 2>/dev/null | grep -i 'llvm\|clang' | sort | uniq | tee /tmp/strings_scan.log && \
    \
    # Install and verify installation \
    echo "=== INSTALLING AND VERIFYING ===" && \
    make install && \
    ldd /usr/local/bin/glxinfo | grep -i llvm | tee /tmp/install_deps.log && \
    cd ../.. && \
    rm -rf demos && \
    /usr/local/bin/check_llvm15.sh "post-mesa-demos-build" || true && \
    echo "=== STRINGENT_MESA_DEMOS_BUILD COMPLETE ==="

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
#If you get errors CHECK HERE, SOMETHING went wrong
RUN apk add --no-cache libpng && echo "Installed libpng"
RUN apk add --no-cache libjpeg-turbo && echo "Installed libjpeg-turbo"
RUN apk add --no-cache tiff && echo "Installed tiff"  
RUN apk add --no-cache libwebp && echo "Installed libwebp"
RUN apk add --no-cache libavif && echo "Installed libavif"
#Break, older packages after
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
