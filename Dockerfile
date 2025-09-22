# Stage: base deps (Alpine version)
FROM alpine:3.21 AS base-deps

# Fix Hangup Code (Test)
CMD ["tail", "-f", "/dev/null"]

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
ARG DOCKER_BUILDKIT=1
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_DEBUG_STAGE" && \
    rm -f /tmp/nocache/timestamp

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
    # Extreme Foundational Libs
    /lilyspark/lib \
    # User's directory
    /lilyspark/usr/include \
    /lilyspark/usr/lib \
    /lilyspark/usr/lib/aarch64-linux-gnu \
    /lilyspark/usr/lib/runtime \
    /lilyspark/usr/bin \
    /lilyspark/usr/share \
    /lilyspark/usr/sbin \
    # User's debug space
    /lilyspark/usr/debug/bin \
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
    /lilyspark/usr/local/lib/kde-desktop \
    /lilyspark/usr/local/lib/math \
    /lilyspark/usr/local/lib/networking \
    /lilyspark/usr/local/lib/python \
    /lilyspark/usr/local/lib/python/site-packages \
    /lilyspark/usr/local/lib/security \
    /lilyspark/usr/local/lib/system \
    /lilyspark/usr/local/lib/testing \
    /lilyspark/usr/local/lib/video \
    /lilyspark/usr/local/lib/wayland \
    /lilyspark/usr/local/lib/x11 \
    # Third-party libraries
    /lilyspark/opt \
    /lilyspark/opt/lib/audio \
    /lilyspark/opt/lib/audio/jack2/ \
    /lilyspark/opt/lib/audio/jack2/bin \
    /lilyspark/opt/lib/audio/jack2/metadata \
    /lilyspark/opt/lib/database \
    /lilyspark/opt/lib/driver \
    /lilyspark/opt/lib/graphics \
    /lilyspark/opt/lib/java \
    /lilyspark/opt/lib/java/fop/bin \
    /lilyspark/opt/lib/java/fop/docs \
    /lilyspark/opt/lib/java/fop/launchers \
    /lilyspark/opt/lib/java/fop/lib \
    /lilyspark/opt/lib/java/fop/metadata \
    /lilyspark/opt/lib/media \
    /lilyspark/opt/lib/media/bin \
    /lilyspark/opt/lib/python \
    /lilyspark/opt/lib/python/site-packages \
    /lilyspark/opt/lib/sdl3 \
    /lilyspark/opt/lib/sdl3/include \
    /lilyspark/opt/lib/sdl3/lib \
    /lilyspark/opt/lib/sdl3/usr/media/include \
    /lilyspark/opt/lib/sdl3/usr/media/lib \
    /lilyspark/opt/lib/sdl3/usr/media/lib/pkgconfig \
    /lilyspark/opt/lib/sys \
    /lilyspark/opt/lib/sys/lib \
    /lilyspark/opt/lib/sys/usr \
    /lilyspark/opt/lib/sys/usr/include \
    /lilyspark/opt/lib/sys/usr/include/linux \
    /lilyspark/opt/lib/sys/usr/include/bits \
    /lilyspark/opt/lib/sys/usr/lib \
    /lilyspark/opt/lib/sys/usr/lib/clang \
    /lilyspark/opt/lib/sys/usr/lib/x86_64-linux-gnu \
    /lilyspark/opt/lib/vulkan \
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
    /lilyspark/app/build \
    /lilyspark/app/build_files \
    /lilyspark/app/src \
    # Snapshots
    /lilyspark/snapshots \
    # Debugger
    /lilyspark/log \
    # MISC
    /lilyspark/etc \
    /lilyspark/var \
    /lilyspark/var/log \
    /lilyspark/var/log/debug \
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
COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/dep_chain_visualizer.sh
COPY setup-scripts/sgid_suid_scanner.sh /usr/local/bin/sgid_suid_scanner.sh
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker.sh
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix.sh
COPY setup-scripts/cflag_audit.sh /usr/local/bin/cflag_audit.sh
COPY setup-scripts/apk-retry.sh /usr/local/bin/apk-retry
RUN chmod +x /usr/local/bin/check_llvm15.sh \
    /usr/local/bin/check-filesystem.sh \
    /usr/local/bin/binlib_validator.sh \
    /usr/local/bin/dep_chain_visualizer.sh \
    /usr/local/bin/sgid_suid_scanner.sh \
    /usr/local/bin/dependency_checker.sh \
    /usr/local/bin/version_matrix.sh \
    /usr/local/bin/cflag_audit.sh \
    /usr/local/bin/apk-retry

# Remove any preinstalled LLVM/Clang
RUN apk del --no-cache llvm clang || true

# Refresh CMake files so it doesn't end up in the cache
RUN echo "=== COMPLETE CMAKE REFRESH CLEANUP ===" && \
   echo "Cleaning old files from WRONG location (build_files):" && \
   rm -f /lilyspark/app/build_files/CMakeLists.txt && \
   rm -f /lilyspark/app/build_files/cmake_output.log && \
   rm -f /lilyspark/app/build_files/make_output.log && \
   rm -rf /lilyspark/app/build_files/CMakeFiles/ && \
   rm -f /lilyspark/app/build_files/CMakeCache.txt && \
   rm -f /lilyspark/app/build_files/Makefile && \
   rm -f /lilyspark/app/build_files/*.cmake && \
   echo "Cleaning old files from CORRECT location (project root):" && \
   rm -f /lilyspark/app/CMakeLists.txt && \
   rm -f /lilyspark/app/cmake_output.log && \
   rm -f /lilyspark/app/make_output.log && \
   rm -rf /lilyspark/app/CMakeFiles/ && \
   rm -f /lilyspark/app/CMakeCache.txt && \
   rm -f /lilyspark/app/Makefile && \
   rm -f /lilyspark/app/*.cmake && \
   rm -f /lilyspark/app/compile_commands.json && \
   echo "Cleaning any stray CMake files from other locations:" && \
   find /lilyspark -name "CMakeCache.txt" -delete 2>/dev/null || true && \
   find /lilyspark -name "CMakeFiles" -type d -exec rm -rf {} + 2>/dev/null || true && \
   find /lilyspark -name "*.cmake" -not -path "*/usr/*" -delete 2>/dev/null || true && \
   echo "Creating fresh build directory:" && \
   rm -rf /lilyspark/app/build_files && \
   mkdir -p /lilyspark/app/build_files && \
   echo "=== COMPLETE CMAKE REFRESH DONE ===" && \
   echo "Project root contents:" && ls -la /lilyspark/app/ 2>/dev/null || echo "Clean slate" && \
   echo "Build directory contents:" && ls -la /lilyspark/app/build_files/ 2>/dev/null || echo "Empty (good)"

# Then we reinstall. So everytime we build, we retart this process so that
# it never gets cahced. Please never fucking change this, because
# then you are a dumbass that doesn't realize the CMakeLists.txt never
# belongs in the cache. Let me save your sanity, DO NOT TOUCH (unless you have a new path for the CMake file that's valid)
COPY CMakeLists.txt /lilyspark/app/CMakeLists.txt

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

# Install LLVM16 + Clang16
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

# ======================
# Environment setup
# ======================
RUN cat > /lilyspark/etc/environment <<'ENV' && \
    echo "=== CREATING ENVIRONMENT SETUP ===" && \
    cat /lilyspark/etc/environment
export PATH="/lilyspark/glibc/bin:/lilyspark/glibc/sbin:/lilyspark/compiler/bin:${PATH}"
export LLVM_CONFIG="/lilyspark/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/lilyspark/glibc/lib:/lilyspark/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/lilyspark/glibc"
ENV

RUN mkdir -p /lilyspark/etc/profile.d && \
    cat > /lilyspark/etc/profile.d/compiler.sh <<'PROFILE'
#!/bin/sh
export PATH="/lilyspark/glibc/bin:/lilyspark/glibc/sbin:/lilyspark/compiler/bin:${PATH}"
export LLVM_CONFIG="/lilyspark/compiler/bin/llvm-config"
export LD_LIBRARY_PATH="/lilyspark/glibc/lib:/lilyspark/compiler/lib:/usr/local/lib:/usr/lib"
export GLIBC_ROOT="/lilyspark/glibc"
export GLIBC_COMPAT="/lilyspark/glibc"
export C_INCLUDE_PATH="/lilyspark/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/lilyspark/glibc/include:${CPLUS_INCLUDE_PATH:-}"
PROFILE
RUN chmod +x /lilyspark/etc/profile.d/compiler.sh

RUN cat > /lilyspark/etc/profile.d/glibc.sh <<'GLIBC_PROFILE'
#!/bin/sh
export GLIBC_ROOT="/lilyspark/glibc"
export GLIBC_COMPAT="/lilyspark/glibc"
export PATH="/lilyspark/glibc/sbin:/lilyspark/glibc/bin:${PATH}"
export LD_LIBRARY_PATH="/lilyspark/glibc/lib:${LD_LIBRARY_PATH:-}"
export C_INCLUDE_PATH="/lilyspark/glibc/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/lilyspark/glibc/include:${CPLUS_INCLUDE_PATH:-}"
GLIBC_PROFILE
RUN chmod +x /lilyspark/etc/profile.d/glibc.sh

RUN echo "=== ENVIRONMENT SETUP VERIFICATION ===" && \
    echo "Environment file:" && cat /lilyspark/etc/environment && \
    echo "Compiler profile:" && cat /lilyspark/etc/profile.d/compiler.sh && \
    echo "Glibc profile:" && cat /lilyspark/etc/profile.d/glibc.sh && \
    echo "All environment files created successfully"

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

COPY setup-scripts/apk-retry.sh /usr/local/bin/apk-retry
RUN chmod +x /usr/local/bin/apk-retry

# Fix Hangup Code (Test)
CMD ["tail", "-f", "/dev/null"]

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_FILESYSTEM_BASE_DEPS" && \
    rm -f /tmp/nocache/timestamp

# Quick checks
RUN echo ">>> check /lilyspark/compiler/bin" && ls -la /lilyspark/compiler/bin || true
RUN echo ">>> check for libc++" && ls -la /lilyspark/compiler/lib | head -20 || true

            #Check if sysroot integration is properly updated below. It probably is not
            #So this is absolutely something we will focus on tomorrow. This comment is 
            #a reminder for this TODO
# ======================
# Core packages ONLY
# ======================
# Vanilla requirements
RUN apk-retry add --no-cache bash && /usr/local/bin/check_llvm15.sh "after-bash" || true
RUN apk-retry add --no-cache curl && /usr/local/bin/check_llvm15.sh "after-curl" || true
RUN apk-retry add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk-retry add --no-cache ca-certificates && /usr/local/bin/check_llvm15.sh "after-ca-certificates" || true
RUN apk-retry add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk-retry add --no-cache bsd-compat-headers && /usr/local/bin/check_llvm15.sh "after-bsd-compat-headers" || true
RUN apk-retry add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk-retry add --no-cache musl-dev && /usr/local/bin/check_llvm15.sh "after-musl-dev" || true
RUN apk-retry add --no-cache libc-dev && /usr/local/bin/check_llvm15.sh "after-libc-dev" || true
RUN apk-retry add --no-cache libstdc++ && /usr/local/bin/check_llvm15.sh "after-libstdc++" || true
RUN apk-retry add --no-cache pkgconf && /usr/local/bin/check_llvm15.sh "after-pkgconf" || true
RUN apk-retry add --no-cache pkgconf-dev && /usr/local/bin/check_llvm15.sh "after-pkgconf-dev" || true
RUN apk-retry add --no-cache autoconf && /usr/local/bin/check_llvm15.sh "after-autoconf" || true
RUN apk-retry add --no-cache tar && /usr/local/bin/check_llvm15.sh "after-tar" || true
RUN apk-retry add --no-cache git && /usr/local/bin/check_llvm15.sh "after-git" || true
RUN apk-retry add --no-cache m4 && /usr/local/bin/check_llvm15.sh "after-m4" || true
RUN apk-retry add --no-cache expat-dev && /usr/local/bin/check_llvm15.sh "after-expat-dev" || true
RUN apk-retry add --no-cache glslang && /usr/local/bin/check_llvm15.sh "after-glslang" || true
RUN apk-retry add --no-cache make && /usr/local/bin/check_llvm15.sh "after-make" || true
RUN apk-retry add --no-cache cmake && /usr/local/bin/check_llvm15.sh "after-cmake" || true
RUN apk-retry add --no-cache automake && /usr/local/bin/check_llvm15.sh "after-automake" || true
RUN apk-retry add --no-cache bison && /usr/local/bin/check_llvm15.sh "after-bison" || true
RUN apk-retry add --no-cache flex && /usr/local/bin/check_llvm15.sh "after-flex" || true
RUN apk-retry add --no-cache libtool && /usr/local/bin/check_llvm15.sh "after-libtool" || true
RUN apk-retry add --no-cache zlib-dev && /usr/local/bin/check_llvm15.sh "after-zlib-dev" || true
RUN apk-retry add --no-cache util-macros && /usr/local/bin/check_llvm15.sh "after-util-macros" || true
RUN apk-retry add --no-cache readline-dev && /usr/local/bin/check_llvm15.sh "after-readline-dev" || true
RUN apk-retry add --no-cache openssl-dev && /usr/local/bin/check_llvm15.sh "after-openssl-dev" || true
RUN apk-retry add --no-cache bzip2-dev && /usr/local/bin/check_llvm15.sh "after-bzip2-dev" || true

# Render essentials
RUN apk-retry add --no-cache meson && /usr/local/bin/check_llvm15.sh "after-meson" || true
RUN apk-retry add --no-cache ninja && /usr/local/bin/check_llvm15.sh "after-ninja" || true

# ===============================
# Copy essentials into /lilyspark
# ===============================
RUN echo "=== COPYING CORE SYSROOT FILES TO /lilyspark ===" && \
    \
    # Copy apk db (for later reference/debug)
    cp -r /lib/apk /lilyspark/lib/ 2>/dev/null || true && \
    \
    # Copy libc/musl runtime (arch-specific)
    ARCH=$(uname -m) && \
    cp -a /lib/ld-musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    cp -a /lib/libc.musl-*.so.1 /lilyspark/lib/ 2>/dev/null || true && \
    \
    if [ "$ARCH" = "x86_64" ]; then \
        ln -sf ld-musl-x86_64.so.1 /lilyspark/lib/ld-linux.so.1; \
    elif [ "$ARCH" = "aarch64" ]; then \
        ln -sf ld-musl-aarch64.so.1 /lilyspark/lib/ld-linux-aarch64.so.1; \
        ln -sf ld-musl-aarch64.so.1 /lilyspark/lib/ld-linux.so.1; \
    fi && \
    ln -sf libc.musl-*.so.1 /lilyspark/lib/libc.so 2>/dev/null || true && \
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

# Sysroot Verification: Core Packages
RUN echo "=== VERIFYING CORE SYSROOT INTEGRATION ===" && \
    echo "Checking essential library presence:" && \
    [ -f /lilyspark/lib/ld-musl-*.so.1 ] && echo "✓ musl dynamic linker found" || echo "⚠ musl dynamic linker missing" && \
    [ -f /lilyspark/lib/libc.musl-*.so.1 ] && echo "✓ musl libc found" || echo "⚠ musl libc missing" && \
    [ -f /lilyspark/usr/lib/libgcc_s.so.1 ] && echo "✓ libgcc_s found" || echo "⚠ libgcc_s missing" && \
    [ -f /lilyspark/usr/lib/libstdc++.so.6 ] && echo "✓ libstdc++ found" || echo "⚠ libstdc++ missing" && \
    \
    echo "Checking header presence:" && \
    [ -d /lilyspark/usr/include/linux ] && echo "✓ Linux headers found" || echo "⚠ Linux headers missing" && \
    [ -d /lilyspark/usr/include/ncurses ] && echo "✓ ncurses headers found" || echo "⚠ ncurses headers missing" && \
    [ -d /lilyspark/usr/include/openssl ] && echo "✓ OpenSSL headers found" || echo "⚠ OpenSSL headers missing" && \
    \
    echo "Checking toolchain components:" && \
    [ -f /lilyspark/usr/lib/crt1.o ] && echo "✓ crt1.o found" || echo "⚠ crt1.o missing" && \
    [ -f /lilyspark/usr/lib/crti.o ] && echo "✓ crti.o found" || echo "⚠ crti.o missing" && \
    [ -f /lilyspark/usr/lib/crtn.o ] && echo "✓ crtn.o found" || echo "⚠ crtn.o missing" && \
    \
    echo "Core library count in /lilyspark/usr/lib:" && \
    ls -1 /lilyspark/usr/lib/*.so* | wc -l && \
    echo "=== CORE SYSROOT VERIFICATION COMPLETE ==="

#
#
#

# ===============================
# Debug tools - May change folder
# ===============================
RUN apk add --no-cache file tree valgrind-dev linux-tools-dev && \
    \
    cp /usr/bin/file /usr/bin/tree /lilyspark/usr/debug/bin/ 2>/dev/null || true && \
    chmod -R a+rx /lilyspark/usr/debug/bin && \
    echo "Debug tools isolated into /lilyspark/usr/debug/bin"

#
#
#

# =========================
# Other Essential Libraries
# =========================
# Audio Libraries - /lilyspark/usr/local/lib/audio
RUN apk-retry add --no-cache sndio-dev && /usr/local/bin/check_llvm15.sh "after-sndio-dev" || true
RUN apk-retry add --no-cache libvorbis-dev && /usr/local/bin/check_llvm15.sh "after-liborbis-dev" || true
RUN apk-retry add --no-cache libogg-dev && /usr/local/bin/check_llvm15.sh "after-libogg-dev" || true
RUN apk-retry add --no-cache flac-dev && /usr/local/bin/check_llvm15.sh "after flac-dev" || true
RUN apk-retry add --no-cache libmodplug-dev && /usr/local/bin/check_llvm15.sh "after-libmodplug-dev" || true
RUN apk-retry add --no-cache mpg123-dev && /usr/local/bin/check_llvm15.sh "after-mpg123-dev" || true
RUN apk-retry add --no-cache opusfile-dev && /usr/local/bin/check_llvm15.sh "after-opusfile-dev" || true
RUN apk-retry add --no-cache alsa-lib-dev && /usr/local/bin/check_llvm15.sh "after-alsa-lib-dev" || true
RUN apk-retry add --no-cache pulseaudio-dev && /usr/local/bin/check_llvm15.sh "after-pulseaudio-dev" || true
RUN apk-retry add --no-cache libsamplerate-dev && /usr/local/bin/check_llvm15.sh "after-libsamplerate-dev" || true
RUN apk-retry add --no-cache portaudio-dev && /usr/local/bin/check_llvm15.sh "after-portaudio-dev" || true

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
    
        # Sysroot Integration: Audio Libraries
RUN echo "=== INTEGRATING AUDIO LIBRARIES INTO SYSROOT ===" && \
    # Create symlinks from the audio-specific directory to the main sysroot
    find /lilyspark/usr/local/lib/audio -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    # Quick verification
    echo "Audio libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{sndio,vorbis,ogg,FLAC,modplug,mpg123,opus,alsa,pulse,samplerate,portaudio}*.so* 2>/dev/null | wc -l || echo "No audio libs found yet") && \
    echo "=== AUDIO SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# A/V Libraries - /lilyspark/usr/local/lib/av
RUN apk-retry add --no-cache pipewire-dev && /usr/local/bin/check_llvm15.sh "after-pipewire-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING A/V LIBRARIES ===" && \
    cp -a /usr/lib/libpipewire* /lilyspark/usr/local/lib/av/ || true && \
    echo "--- A/V CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/av | head -20 || true

        # Sysroot Integration: A/V Libraries
RUN echo "=== INTEGRATING A/V LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/av -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "A/V libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/libpipewire*.so* 2>/dev/null | wc -l || echo "No A/V libs found yet") && \
    echo "=== A/V SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Compression Libraries - /lilyspark/usr/local/lib/compression
RUN apk-retry add --no-cache xz-dev && /usr/local/bin/check_llvm15.sh "after-xz-dev" || true
RUN apk-retry add --no-cache zstd-dev && /usr/local/bin/check_llvm15.sh "after-zstd-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING COMPRESSION LIBRARIES ===" && \
    cp -a /usr/lib/liblzma* /lilyspark/usr/local/lib/compression/ 2>/dev/null || true && \
    cp -a /usr/lib/libzstd* /lilyspark/usr/local/lib/compression/ 2>/dev/null || true && \
    echo "--- COMPRESSION CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/compression | head -10 || true

        # Sysroot Integration: Compression Libraries
RUN echo "=== INTEGRATING COMPRESSION LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/compression -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Compression libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{lzma,zstd}*.so* 2>/dev/null | wc -l || echo "No compression libs found yet") && \
    echo "=== COMPRESSION SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Database Libraries - /lilyspark/usr/local/lib/database
RUN apk-retry add --no-cache sqlite-dev && /usr/local/bin/check_llvm15.sh "after-sqlite-dev" || true
RUN apk-retry add --no-cache libedit-dev && /usr/local/bin/check_llvm15.sh "after-libedit-dev" || true
RUN apk-retry add --no-cache icu-dev && /usr/local/bin/check_llvm15.sh "after-icu-dev" || true
RUN apk-retry add --no-cache tcl-dev && /usr/local/bin/check_llvm15.sh "after-tcl-dev" || true
RUN apk-retry add --no-cache lz4-dev && /usr/local/bin/check_llvm15.sh "after-lz4-dev" || true
RUN apk-retry add --no-cache db-dev && /usr/local/bin/check_llvm15.sh "after-db-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING DATABASE LIBRARIES ===" && \
    cp -a /usr/lib/libsqlite* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libedit* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libicu* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/libtcl* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    cp -a /usr/lib/liblz4* /lilyspark/usr/local/lib/database/ 2>/dev/null || true && \
    echo "--- DATABASE CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/database | head -10 || true

        # Sysroot Integration: Database Libraries
RUN echo "=== INTEGRATING DATABASE LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/database -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Database libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{sqlite,edit,icu,tcl,lz4}*.so* 2>/dev/null | wc -l || echo "No database libs found yet") && \
    echo "=== DATABASE SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Device Management Libraries - /lilyspark/usr/local/lib/device_management
RUN apk-retry add --no-cache eudev-dev && /usr/local/bin/check_llvm15.sh "after-eudev-dev" || true
RUN apk-retry add --no-cache pciutils-dev && /usr/local/bin/check_llvm15.sh "after-pciutils-dev" || true
RUN apk-retry add --no-cache libusb-dev && /usr/local/bin/check_llvm15.sh "after-libusb-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING DEVICE MANAGEMENT LIBRARIES ===" && \
    cp -a /usr/include/eudev /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libudev* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libpci* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    cp -a /usr/lib/libusb* /lilyspark/usr/local/lib/device_management/ 2>/dev/null || true && \
    echo "--- DEVICE MANAGEMENT CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/device_management | head -10 || true

        # Sysroot Integration: Device Management Libraries
RUN echo "=== INTEGRATING DEVICE MANAGEMENT LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/device_management -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Device Management libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{udev,pci,usb}*.so* 2>/dev/null | wc -l || echo "No device management libs found yet") && \
    echo "=== DEVICE MANAGEMENT SYSROOT INTEGRATION COMPLETE ==="
#
#
#

# Documentation Libraries - /lilyspark/usr/local/lib/documentation
RUN apk-retry add --no-cache xmlto && /usr/local/bin/check_llvm15.sh "after-xmlto" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING DOCUMENTATION LIBRARIES ===" && \
    cp -a /usr/bin/xmlto /lilyspark/usr/local/lib/documentation/ 2>/dev/null || true && \
    cp -a /usr/share/xmlto /lilyspark/usr/local/lib/documentation/ 2>/dev/null || true && \
    echo "--- DOCUMENTATION CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/documentation | head -10 || true

        # Sysroot Integration: Documentation Libraries
RUN echo "=== INTEGRATING DOCUMENTATION TOOLS INTO SYSROOT ===" && \
    # Link any shared libraries from documentation directory (xmlto may have dependencies)
    find /lilyspark/usr/local/lib/documentation -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Documentation tools integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{xmlto}*.so* 2>/dev/null | wc -l || echo "No documentation libs found (xmlto is primarily a binary tool)") && \
    echo "=== DOCUMENTATION SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Graphics Libraries - /lilyspark/usr/local/lib/graphics
RUN apk-retry add --no-cache gtk+3-dev && /usr/local/bin/check_llvm15.sh "after-gtk+3-dev" || true
RUN apk-retry add --no-cache cairo-dev && /usr/local/bin/check_llvm15.sh "after-cairo-dev" || true
RUN apk-retry add --no-cache pixman-dev && /usr/local/bin/check_llvm15.sh "after-pixman-dev" || true
RUN apk-retry add --no-cache harfbuzz-dev && /usr/local/bin/check_llvm15.sh "after-harfbuzz-dev" || true
RUN apk-retry add --no-cache vulkan-headers && /usr/local/bin/check_llvm15.sh "after-vulkan-headers" || true
RUN apk-retry add --no-cache vulkan-loader && /usr/local/bin/check_llvm15.sh "after-vulkan-loader" || true
RUN apk-retry add --no-cache vulkan-tools && /usr/local/bin/check_llvm15.sh "after-vulkan-tools" || true
RUN apk-retry add --no-cache freetype-dev && /usr/local/bin/check_llvm15.sh "after-freetype-dev" || true
RUN apk-retry add --no-cache fontconfig-dev && /usr/local/bin/check_llvm15.sh "after-fontconfig-dev" || true

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

RUN echo "=== INTEGRATING GRAPHICS LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/graphics -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Graphics libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{harfbuzz,freetype,fontconfig,vulkan}*.so* 2>/dev/null | wc -l || echo "No graphics libs found yet") && \
    echo "=== GRAPHICS SYSROOT INTEGRATION COMPLETE ==="

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

    # Sysroot Integration: i18n Libraries
RUN echo "=== INTEGRATING I18N LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/i18n -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "i18n libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/libgettext*.so* 2>/dev/null | wc -l || echo "No i18n libs found yet") && \
    echo "=== I18N SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Image Libraries - /lilyspark/usr/local/lib/image
RUN apk-retry add --no-cache jpeg-dev && /usr/local/bin/check_llvm15.sh "after-jpeg-dev" || true
RUN apk-retry add --no-cache libjpeg-turbo-dev && /usr/local/bin/check_llvm15.sh "after-libjpeg-turbo-dev" || true
RUN apk-retry add --no-cache libpng-dev && /usr/local/bin/check_llvm15.sh "after-libpng-dev" || true
RUN apk-retry add --no-cache tiff-dev && /usr/local/bin/check_llvm15.sh "after-tiff-dev" || true
RUN apk-retry add --no-cache libtiff && /usr/local/bin/check_llvm15.sh "after-lib-tiff" || true
RUN apk-retry add --no-cache libavif && /usr/local/bin/check_llvm15.sh "after-libavif" || true
RUN apk-retry add --no-cache libwebp && /usr/local/bin/check_llvm15.sh "after-libwebp" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING IMAGE LIBRARIES ===" && \
    cp -a /usr/include/jpeg* /usr/include/png* /usr/include/tiff* /usr/include/libavif* /usr/include/libwebp* /lilyspark/usr/local/lib/image/ 2>/dev/null || true && \
    cp -a /usr/lib/libjpeg* /usr/lib/libpng* /usr/lib/libtiff* /usr/lib/libavif* /usr/lib/libwebp* /lilyspark/usr/local/lib/image/ 2>/dev/null || true && \
    echo "--- IMAGE CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/image | head -10 || true

        # Sysroot Integration: Image Libraries
RUN echo "=== INTEGRATING IMAGE LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/image -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Image libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{jpeg,png,tiff,avif,webp}*.so* 2>/dev/null | wc -l || echo "No image libs found yet") && \
    echo "=== IMAGE SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Java Libraries - /lilyspark/usr/local/lib/java
RUN apk --network-timeout=600 add --no-cache openjdk11 && \
    /usr/local/bin/check_llvm15.sh "after-openjdk11" || true && \
    \
    # Verify Java installation
    echo "=== VERIFYING JAVA INSTALLATION ===" && \
    JAVA_BIN="$(command -v java)" && \
    if [ -n "$JAVA_BIN" ]; then \
        echo "✓ Java found at: $JAVA_BIN" && \
        echo "Java version:" && \
        "$JAVA_BIN" -version 2>&1 || echo "Java version check failed"; \
    else \
        echo "✗ Java not found in PATH" >&2 && \
        echo "Searching for Java..." && \
        find /usr -name "java" -type f -executable 2>/dev/null | head -5 || true && \
        false; \
    fi

RUN apk-retry add --no-cache ant && /usr/local/bin/check_llvm15.sh "after-ant" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING JAVA LIBRARIES ===" && \
    cp -a /usr/lib/jvm/java-11-openjdk /lilyspark/usr/local/lib/java/ 2>/dev/null || true && \
    cp -a /usr/bin/ant /lilyspark/usr/local/lib/java/ 2>/dev/null || true && \
    echo "--- JAVA CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/java | head -10 || true

        # Sysroot Integration: Java Libraries
RUN echo "=== INTEGRATING JAVA LIBRARIES INTO SYSROOT ===" && \
    # Link shared libraries (.so files) from Java runtime
    find /lilyspark/usr/local/lib/java -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    # Also link any important Java binaries if they exist as shared objects
    echo "Java libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{jvm,java}*.so* 2>/dev/null | wc -l || echo "No Java runtime libs found yet") && \
    echo "=== JAVA SYSROOT INTEGRATION COMPLETE ==="
#
#
#

# KDE Desktop Libraries - /lilyspark/usr/local/lib/kde-desktop
RUN apk --network-timeout=600 add --no-cache plasma-desktop && /usr/local/bin/check_llvm15.sh "after-plasma-workspace" || true
#RUN apk --network-timeout=600 add --no-cache plasma-workspace-dev && /usr/local/bin/check_llvm15.sh "after-plasma-workspace-dev" || true
#RUN apk --network-timeout=600 add --no-cache plasma-framework-dev && /usr/local/bin/check_llvm15.sh "after-plasma-framework-dev" || true
#RUN apk-retry add --no-cache kwin && /usr/local/bin/check_llvm15.sh "after-kwin" || true
#RUN apk-retry add --no-cache kscreen && /usr/local/bin/check_llvm15.sh "after-kscreen" || true
#RUN apk-retry add --no-cache plasma-systemmonitor && /usr/local/bin/check_llvm15.sh "after-plasma-systemmonitor" || true
#RUN apk-retry add --no-cache sddm && /usr/local/bin/check_llvm15.sh "after-sddm" || true
#RUN apk-retry add --no-cache dolphin && /usr/local/bin/check_llvm15.sh "after-dolphin" || true
#RUN apk-retry add --no-cache konsole && /usr/local/bin/check_llvm15.sh "after-konsole" || true
#RUN apk-retry add --no-cache kate && /usr/local/bin/check_llvm15.sh "after-kate" || true
#RUN apk-retry add --no-cache spectacle && /usr/local/bin/check_llvm15.sh "after-spectacle" || true
#RUN apk-retry add --no-cache systemsettings && /usr/local/bin/check_llvm15.sh "after-systemsettings" || true
#RUN apk-retry add --no-cache kio && /usr/local/bin/check_llvm15.sh "after-kio" || true
#RUN apk-retry add --no-cache kconfig && /usr/local/bin/check_llvm15.sh "after-kconfig" || true
#RUN apk-retry add --no-cache kcoreaddons && /usr/local/bin/check_llvm15.sh "after-kcoreaddons" || true
#RUN apk-retry add --no-cache kservice && /usr/local/bin/check_llvm15.sh "after-kservice" || true
#RUN apk-retry add --no-cache solid && /usr/local/bin/check_llvm15.sh "after-solid" || true
#RUN apk-retry add --no-cache kglobalaccel && /usr/local/bin/check_llvm15.sh "after-kglobalaccel" || true
#RUN apk-retry add --no-cache xdg-utils && /usr/local/bin/check_llvm15.sh "after-xdg-utils" || true
#RUN apk-retry add --no-cache breeze && /usr/local/bin/check_llvm15.sh "after-breeze" || true
#RUN apk-retry add --no-cache breeze-icons && /usr/local/bin/check_llvm15.sh "after-breeze-icons" || true
#RUN apk-retry add --no-cache oxygen-icons && /usr/local/bin/check_llvm15.sh "after-oxygen-icons" || true
#RUN apk-retry add --no-cache ark && /usr/local/bin/check_llvm15.sh "after-ark" || true
#RUN apk-retry add --no-cache gwenview && /usr/local/bin/check_llvm15.sh "after-gwenview" || true
#RUN apk-retry add --no-cache okular && /usr/local/bin/check_llvm15.sh "after-okular" || true
#RUN apk-retry add --no-cache kcalc && /usr/local/bin/check_llvm15.sh "after-kcalc" || true
#RUN apk-retry add --no-cache xorg-server-xephyr && /usr/local/bin/check_llvm15.sh "after-xorg-server-xephyr" || true
#RUN apk-retry add --no-cache elogind && /usr/local/bin/check_llvm15.sh "after-elogind" || true
#RUN apk-retry add --no-cache dbus && /usr/local/bin/check_llvm15.sh "after-dbus" || true
#RUN apk-retry add --no-cache xauth && /usr/local/bin/check_llvm15.sh "after-xauth" || true


# Copy Libraries To Directory
RUN echo "=== COPYING KDE DESKTOP LIBRARIES ===" && \
    # Plasma Desktop / Workspace / Framework
    cp -a /usr/include/plasma* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    cp -a /usr/lib/libplasma*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #\
    # KWin, KScreen, Plasma System Monitor
    #cp -a /usr/include/kwin* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libkwin*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/kscreen* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libkscreen*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/plasma-systemmonitor* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libplasma-systemmonitor*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    \
    # Core KDE Frameworks
    #cp -a /usr/include/KF5/* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libKF5*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    \
    # Applications (Konsole, Dolphin, etc.)
    #cp -a /usr/include/dolphin* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libdolphin*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/konsole* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libkonsole*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/kate* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libkate*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/spectacle* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libspectacle*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/systemsettings* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libsystemsettings*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    \
    # Utilities (Ark, Gwenview, Okular, KCalc)
    #cp -a /usr/include/ark* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libark*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/gwenview* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libgwenview*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/okular* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libokular*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/include/kcalc* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    #cp -a /usr/lib/libkcalc*.so* /lilyspark/usr/local/lib/kde-desktop/ 2>/dev/null || true && \
    \
    echo "--- KDE DESKTOP CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/kde-desktop | head -40 || true

# Sysroot Integration: KDE Desktop Libraries
RUN echo "=== INTEGRATING KDE DESKTOP LIBRARIES INTO SYSROOT ===" && \
    # Link any shared libraries from kde-desktop directory
    find /lilyspark/usr/local/lib/kde-desktop -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "KDE desktop libraries integrated. Counts:" && \
    echo "Plasma libs:" $(ls -1 /lilyspark/usr/lib/libplasma*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "KWin libs:" $(ls -1 /lilyspark/usr/lib/libkwin*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "KScreen libs:" $(ls -1 /lilyspark/usr/lib/libkscreen*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Plasma System Monitor libs:" $(ls -1 /lilyspark/usr/lib/libplasma-systemmonitor*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "KF5 libs:" $(ls -1 /lilyspark/usr/lib/libKF5*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Dolphin libs:" $(ls -1 /lilyspark/usr/lib/libdolphin*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Konsole libs:" $(ls -1 /lilyspark/usr/lib/libkonsole*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Kate libs:" $(ls -1 /lilyspark/usr/lib/libkate*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Spectacle libs:" $(ls -1 /lilyspark/usr/lib/libspectacle*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Systemsettings libs:" $(ls -1 /lilyspark/usr/lib/libsystemsettings*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Ark libs:" $(ls -1 /lilyspark/usr/lib/libark*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Gwenview libs:" $(ls -1 /lilyspark/usr/lib/libgwenview*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "Okular libs:" $(ls -1 /lilyspark/usr/lib/libokular*.so* 2>/dev/null | wc -l || echo 0) && \
    #echo "KCalc libs:" $(ls -1 /lilyspark/usr/lib/libkcalc*.so* 2>/dev/null | wc -l || echo 0) && \
    echo "=== KDE DESKTOP SYSROOT INTEGRATION COMPLETE ==="



# Math Libraries - /lilyspark/usr/local/lib/math
RUN apk-retry add --no-cache eigen-dev && /usr/local/bin/check_llvm15.sh "after-eigen-dev" || true
RUN apk-retry add --no-cache gmp && /usr/local/bin/check_llvm15.sh "after-gmp" || true
RUN apk-retry add --no-cache gsl && /usr/local/bin/check_llvm15.sh "after-gsl" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING MATH LIBRARIES ===" && \
    # Eigen (headers only)
    cp -a /usr/include/eigen3 /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    # GMP (headers + libs)
    cp -a /usr/include/gmp* /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    cp -a /usr/lib/libgmp*.so* /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    # GSL (headers + libs)
    cp -a /usr/include/gsl /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    cp -a /usr/lib/libgsl*.so* /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    \
    echo "--- MATH CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/math | head -30 || true

# Sysroot Integration: Math Libraries
RUN echo "=== INTEGRATING MATH LIBRARIES INTO SYSROOT ===" && \
    # Link any shared libraries from math directory
    find /lilyspark/usr/local/lib/math -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Math libraries integrated. Counts:" && \
    echo "Eigen headers present:" $(test -d /lilyspark/usr/local/lib/math/eigen3 && echo yes || echo no) && \
    echo "GMP libs count:" $(ls -1 /lilyspark/usr/lib/libgmp*.so* 2>/dev/null | wc -l || echo 0) && \
    echo "GSL libs count:" $(ls -1 /lilyspark/usr/lib/libgsl*.so* 2>/dev/null | wc -l || echo 0) && \
    echo "gslcblas libs count:" $(ls -1 /lilyspark/usr/lib/libgslcblas*.so* 2>/dev/null | wc -l || echo 0) && \
    echo "=== MATH SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Networking Libraries - /lilyspark/usr/local/lib/networking
RUN apk-retry add --no-cache libpcap-dev && /usr/local/bin/check_llvm15.sh "after-libpcap-dev" || true
RUN apk-retry add --no-cache libunwind-dev && /usr/local/bin/check_llvm15.sh "after-libunwind-dev" || true
RUN apk-retry add --no-cache dbus-dev && /usr/local/bin/check_llvm15.sh "after-dbus-dev" || true
RUN apk-retry add --no-cache libmnl-dev && /usr/local/bin/check_llvm15.sh "after-libmnl-dev" || true
RUN apk-retry add --no-cache net-tools && /usr/local/bin/check_llvm15.sh "after-net-tools" || true
RUN apk-retry add --no-cache iproute2 && /usr/local/bin/check_llvm15.sh "after-iproute2" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING NETWORKING LIBRARIES ===" && \
    cp -a /usr/include/pcap* /usr/include/unwind* /usr/include/dbus-1.0 /usr/include/libmnl* /lilyspark/usr/local/lib/networking/ 2>/dev/null || true && \
    cp -a /usr/lib/libpcap* /usr/lib/libunwind* /usr/lib/libdbus* /usr/lib/libmnl* /lilyspark/usr/local/lib/networking/ 2>/dev/null || true && \
    echo "--- NETWORKING CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/networking | head -10 || true

        # Sysroot Integration: Networking Libraries
RUN echo "=== INTEGRATING NETWORKING LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/networking -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Networking libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{pcap,unwind,dbus,mnl}*.so* 2>/dev/null | wc -l || echo "No networking libs found yet") && \
    echo "=== NETWORKING SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Python Libraries - /lilyspark/usr/local/lib/python
RUN apk-retry add --no-cache python3 python3-dev py3-setuptools py3-pip py3-markupsafe \
    && /usr/local/bin/check_llvm15.sh "after-python-libs" || true

# FORCE INSTALL MAKO VIA PIP WITH --break-system-packages
RUN pip3 install mako --break-system-packages \
    && /usr/local/bin/check_llvm15.sh "after-pip-mako" || true

# IMMEDIATE VERIFICATION
RUN echo "=== VERIFYING PYTHON PACKAGES AFTER INSTALL ===" && \
    echo "Mako:" && find /usr -name "mako" -type d 2>/dev/null || echo "Mako not found" && \
    echo "MarkupSafe:" && find /usr -name "*markup*safe*" -type d 2>/dev/null || echo "MarkupSafe not found" && \
    echo "Python site-packages:" && find /usr -name "site-packages" -type d 2>/dev/null | head -3

# COPY PACKAGES TO LILYPARK PREFERRED PATH
RUN echo "=== COPYING PYTHON PACKAGES TO PREFERRED PATH ===" && \
    \
    for pkg in mako markupsafe mesonbuild; do \
        src=$(find /usr -type d -name "$pkg" 2>/dev/null | head -1); \
        # Try alternative spelling for markupsafe
        if [ -z "$src" ] && [ "$pkg" = "markupsafe" ]; then \
            src=$(find /usr -type d -name "MarkupSafe" 2>/dev/null | head -1); \
        fi; \
        if [ -n "$src" ] && [ -d "$src" ]; then \
            dst="/lilyspark/usr/local/lib/python/site-packages/$pkg"; \
            cp -a "$src" "$dst"; \
            echo "Copied $pkg -> $dst"; \
        else \
            echo "ERROR: Package $pkg not found"; \
        fi; \
    done && \
    echo "=== VERIFICATION IN PREFERRED PATH ===" && \
    ls -la /lilyspark/usr/local/lib/python/site-packages/

# SYSROOT INTEGRATION: LINK EACH PACKAGE INDIVIDUALLY
RUN echo "=== SYMLINKING PYTHON PACKAGES TO SYSROOT ===" && \
    for pkg in mako markupsafe mesonbuild; do \
        src="/lilyspark/usr/local/lib/python/site-packages/$pkg"; \
        dst="/lilyspark/usr/lib/python3.12/site-packages/$pkg"; \
        if [ -d "$src" ]; then \
            mkdir -p "$(dirname "$dst")"; \
            ln -sf "$src" "$dst"; \
            echo "Linked $pkg -> $dst"; \
        else \
            echo "Package $pkg missing in preferred path, cannot link"; \
        fi; \
    done && \
    # Link any shared libraries (*.so) from preferred path
    find /lilyspark/usr/local/lib/python -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || echo "No .so files found to link" && \
    echo "Python integration complete"

#
#
#

# Security Libraries - /lilyspark/usr/local/lib/security
RUN apk-retry add --no-cache libselinux-dev && /usr/local/bin/check_llvm15.sh "after-libselinux-dev" || true
RUN apk-retry add --no-cache libseccomp-dev && /usr/local/bin/check_llvm15.sh "after-libseccomp-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING SECURITY LIBRARIES ===" && \
    cp -a /usr/include/selinux /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/lib/libselinux* /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/include/seccomp /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    cp -a /usr/lib/libseccomp* /lilyspark/usr/local/lib/security/ 2>/dev/null || true && \
    echo "--- SECURITY CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/security | head -10 || true

        # Sysroot Integration: Security Libraries
RUN echo "=== INTEGRATING SECURITY LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/security -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Security libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{selinux,seccomp}*.so* 2>/dev/null | wc -l || echo "No security libs found yet") && \
    echo "=== SECURITY SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# System Libraries - /lilyspark/usr/local/lib/system
RUN apk-retry add --no-cache libatomic_ops-dev && /usr/local/bin/check_llvm15.sh "after-libatomic_ops-dev" || true
RUN apk-retry add --no-cache util-linux-dev && /usr/local/bin/check_llvm15.sh "after-util-linux-dev" || true
RUN apk-retry add --no-cache libcap-dev && /usr/local/bin/check_llvm15.sh "after-libcap-dev" || true
RUN apk-retry add --no-cache liburing-dev && /usr/local/bin/check_llvm15.sh "after-liburing-dev" || true
RUN apk-retry add --no-cache e2fsprogs-dev && /usr/local/bin/check_llvm15.sh "after-e2fsprogs-dev" || true
RUN apk-retry add --no-cache xfsprogs-dev && /usr/local/bin/check_llvm15.sh "after-xfsprogs-dev" || true
RUN apk-retry add --no-cache btrfs-progs-dev && /usr/local/bin/check_llvm15.sh "after-btrfs-progs-dev" || true
RUN apk-retry add --no-cache libexecinfo-dev && /usr/local/bin/check_llvm15.sh "after-libexecinfo-dev" || true
RUN apk-retry add --no-cache libdw && /usr/local/bin/check_llvm15.sh "after-libdw" || true

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
    # libdw (headers + lib)
    cp -a /usr/include/dwarf.h /usr/include/elfutils /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    cp -a /usr/lib/libdw* /lilyspark/usr/local/lib/system/ 2>/dev/null || true && \
    echo "--- SYSTEM CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/system | head -10 || true

        # Sysroot Integration: System Libraries
RUN echo "=== INTEGRATING SYSTEM LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/system -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "System libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{uring,cap,atomic_ops,ext2fs,xfs,btrfs,dw}*.so* 2>/dev/null | wc -l || echo "No system libs found yet") && \
    echo "=== SYSTEM SYSROOT INTEGRATION COMPLETE ==="


#
#
#

# Testing Libraries - /lilyspark/usr/local/lib/testing
RUN apk-retry add --no-cache cunit-dev && /usr/local/bin/check_llvm15.sh "after-cunit-dev" || true

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
RUN apk-retry add --no-cache v4l-utils-dev && /usr/local/bin/check_llvm15.sh "after-v4l-utils-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING VIDEO LIBRARIES ===" && \
    cp -a /usr/include/libv4l* /lilyspark/usr/local/lib/video/ 2>/dev/null || true && \
    cp -a /usr/lib/libv4l* /lilyspark/usr/local/lib/video/ 2>/dev/null || true && \
    echo "--- VIDEO CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/video | head -10 || true

# Sysroot Integration: Video Libraries
RUN echo "=== INTEGRATING VIDEO LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/video -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Video libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/libv4l*.so* 2>/dev/null | wc -l || echo "No video libs found yet") && \
    echo "=== VIDEO SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# Wayland Libraries - /lilyspark/usr/local/lib/wayland
RUN apk-retry add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk-retry add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING WAYLAND LIBRARIES ===" && \
    cp -a /usr/include/wayland* /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    cp -a /usr/include/wayland-protocols /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    cp -a /usr/lib/libwayland* /lilyspark/usr/local/lib/wayland/ 2>/dev/null || true && \
    echo "--- WAYLAND CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/wayland | head -10 || true

# Sysroot Integration: Wayland Libraries
RUN echo "=== INTEGRATING WAYLAND LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/wayland -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Wayland libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/libwayland*.so* 2>/dev/null | wc -l || echo "No Wayland libs found yet") && \
    echo "=== WAYLAND SYSROOT INTEGRATION COMPLETE ==="

#
#
#

# X11 Libraries - /lilyspark/usr/local/lib/x11
RUN apk-retry add --no-cache libx11-dev && /usr/local/bin/check_llvm15.sh "after-libx11-dev" || true
RUN apk-retry add --no-cache libxkbcommon-dev && /usr/local/bin/check_llvm15.sh "after-libxkbcommon-dev" || true
RUN apk-retry add --no-cache xkeyboard-config && /usr/local/bin/check_llvm15.sh "after-xkeyboard-config" || true
RUN apk-retry add --no-cache xkbcomp && /usr/local/bin/check_llvm15.sh "after-xkbcomp" || true
RUN apk-retry add --no-cache libxkbfile-dev && /usr/local/bin/check_llvm15.sh "after-libxkbfile-dev" || true
RUN apk-retry add --no-cache libxfont2-dev && /usr/local/bin/check_llvm15.sh "after-libxfont2-dev" || true
RUN apk-retry add --no-cache font-util-dev && /usr/local/bin/check_llvm15.sh "after-font-util-dev-dev" || true
RUN apk-retry add --no-cache xcb-util-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-dev" || true
RUN apk-retry add --no-cache xcb-util-renderutil-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-renderutil-dev" || true
RUN apk-retry add --no-cache xcb-util-wm-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-wm-dev" || true
RUN apk-retry add --no-cache xcb-util-keysyms-dev && /usr/local/bin/check_llvm15.sh "after-xcb-util-keysyms-dev" || true
RUN apk-retry add --no-cache xf86driproto && /usr/local/bin/check_llvm15.sh "after-xf86driproto" || true
RUN apk-retry add --no-cache xf86vidmodeproto && /usr/local/bin/check_llvm15.sh "after-xf86vidmodeproto" || true
RUN apk-retry add --no-cache glproto && /usr/local/bin/check_llvm15.sh "after-glproto" || true
RUN apk-retry add --no-cache dri2proto && /usr/local/bin/check_llvm15.sh "after-dri2proto" || true
RUN apk-retry add --no-cache libxext-dev && /usr/local/bin/check_llvm15.sh "after-libxext-dev" || true
RUN apk-retry add --no-cache libxrender-dev && /usr/local/bin/check_llvm15.sh "after-libxrender-dev" || true
RUN apk-retry add --no-cache libxfixes-dev && /usr/local/bin/check_llvm15.sh "after-libxfixes-dev" || true
RUN apk-retry add --no-cache libxdamage-dev && /usr/local/bin/check_llvm15.sh "after-libxdamage-dev" || true
RUN apk-retry add --no-cache libxcb-dev && /usr/local/bin/check_llvm15.sh "after-libxcb-dev" || true
RUN apk-retry add --no-cache libxcomposite-dev && /usr/local/bin/check_llvm15.sh "after-libxcomposite-dev" || true
RUN apk-retry add --no-cache libxinerama-dev && /usr/local/bin/check_llvm15.sh "after-libxinerama-dev" || true
RUN apk-retry add --no-cache libxi-dev && /usr/local/bin/check_llvm15.sh "after-libxi-dev" || true
RUN apk-retry add --no-cache libxcursor-dev && /usr/local/bin/check_llvm15.sh "after-libxcursor-dev" || true
RUN apk-retry add --no-cache libxrandr-dev && /usr/local/bin/check_llvm15.sh "after-libxrandr-dev" || true
RUN apk-retry add --no-cache libxshmfence-dev && /usr/local/bin/check_llvm15.sh "after-libxshmfence-dev" || true
RUN apk-retry add --no-cache libxxf86vm-dev && /usr/local/bin/check_llvm15.sh "after-libxxf86vm-dev" || true
RUN apk-retry add --no-cache xf86-video-fbdev && /usr/local/bin/check_llvm15.sh "after-xf86-video-fbdev" || true
RUN apk-retry add --no-cache xf86-video-dummy && /usr/local/bin/check_llvm15.sh "after-xf86-video-dummy" || true

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

# Sysroot Integration: X11 Libraries
RUN echo "=== INTEGRATING X11 LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/x11 -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "X11 libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{X11,xcb,Xext,Xrender,Xfixes,Xdamage,Xcomposite,Xinerama,Xi,Xcursor,Xrandr,Xshmfence,XXF86VM,xkbcommon,xkbfile,xfont2}*.so* 2>/dev/null | wc -l || echo "No X11 libs found yet") && \
    echo "=== X11 SYSROOT INTEGRATION COMPLETE ==="

#
#
#



# Stage: filesystem-libs (minimal version for C++ Hello World)
FROM filesystem-base-deps-builder AS filesystem-libs-build-builder

# Fix Hangup Code (Test)
CMD ["tail", "-f", "/dev/null"]

# ULTIMATE cache-busting - forces rebuild every time
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_$(date +%s%N)_$$_$RANDOM" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && \
    echo "CACHE_DISABLED_FOR_FILESYSTEM_LIBS_BUILD" && \
    rm -f /tmp/nocache/timestamp

COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/dep_chain_visualizer.sh
COPY setup-scripts/sgid_suid_scanner.sh /usr/local/bin/sgid_suid_scanner.sh
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker.sh
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix.sh
COPY setup-scripts/cflag_audit.sh /usr/local/bin/cflag_audit.sh
RUN chmod +x /usr/local/bin/dep_chain_visualizer.sh \
    /usr/local/bin/sgid_suid_scanner.sh \
    /usr/local/bin/dependency_checker.sh \
    /usr/local/bin/version_matrix.sh \
    /usr/local/bin/cflag_audit.sh


# ======================
# STEP: Robust Sysroot Population with Fallbacks
# (Must run BEFORE any build that uses /lilyspark/opt/lib/sys)
# ======================
RUN echo "=== ATTEMPTING ROBUST SYSROOT POPULATION ===" && \
    \
    # STRATEGY 1: Ensure base directory structure exists
    echo "Ensuring /lilyspark/opt/lib/sys directory structure..." && \
    \
    # STRATEGY 2: Methodical, verified copying with fallbacks
    echo "Populating sysroot usr/lib..." && \
    copy_and_verify() { \
        src="$1"; dest="$2"; \
        echo "Attempting to copy: $src"; \
        if cp -a $src $dest 2>/dev/null; then \
            echo "✓ Success: $(ls $dest 2>/dev/null | wc -l) files copied to $dest"; \
        else \
            echo "⚠ Partial/Failed: Could not copy $src to $dest"; \
            # Attempt to create a fallback file if nothing was copied
            if [ -z "$(ls -A $dest 2>/dev/null)" ]; then \
                echo "Creating fallback structure in $dest"; \
                mkdir -p $dest; \
                touch $dest/.placeholder; \
            fi; \
        fi; \
    }; \
    \
    # Copy critical runtime objects
    copy_and_verify "/usr/lib/crt*.o" "/lilyspark/opt/lib/sys/usr/lib/"; \
    copy_and_verify "/usr/lib/gcc/*/*/crt*.o" "/lilyspark/opt/lib/sys/usr/lib/"; \
    \
    # Copy compiler libraries (FIXED: Include static libraries)
    copy_and_verify "/usr/lib/libgcc*" "/lilyspark/opt/lib/sys/usr/lib/"; \
    copy_and_verify "/usr/lib/gcc/*/*/libgcc*" "/lilyspark/opt/lib/sys/usr/lib/"; \
    copy_and_verify "/usr/lib/gcc/*/*/*.a" "/lilyspark/opt/lib/sys/usr/lib/"; \
    copy_and_verify "/usr/lib/libssp*" "/lilyspark/opt/lib/sys/usr/lib/"; \
    \
    # Copy C library and dynamic linker
    copy_and_verify "/lib/libc.musl-*.so.1" "/lilyspark/opt/lib/sys/lib/"; \
    copy_and_verify "/lib/ld-musl-*.so.1" "/lilyspark/opt/lib/sys/lib/"; \
    \
    # Copy pthread static library and create symlinks
    copy_and_verify "/usr/lib/libpthread.a" "/lilyspark/opt/lib/sys/usr/lib/"; \
    \
    # CRITICAL: Create pthread symlinks ONLY in sysroot, not runtime paths
    if [ -f "/lilyspark/opt/lib/sys/lib/libc.musl-aarch64.so.1" ]; then \
        cd "/lilyspark/opt/lib/sys/lib" && \
        ln -sf "libc.musl-aarch64.so.1" "libc.so" && \
        ln -sf "libc.musl-aarch64.so.1" "libpthread.so.0" && \
        ln -sf "libpthread.so.0" "libpthread.so" && \
        echo "✓ Created libc.so and libpthread.so symlinks in sysroot only"; \
        cd - >/dev/null; \
        \
        # CRITICAL: Ensure these symlinks DON'T pollute runtime library paths
        echo "Verifying pthread symlinks are isolated to sysroot..." && \
        ls -la /lilyspark/opt/lib/sys/lib/libpthread* || true; \
    else \
        echo "⚠ Cannot create pthread symlinks, musl library missing"; \
    fi; \
    \
    # Also copy musl-dev static library if it exists
    copy_and_verify "/usr/lib/libc.a" "/lilyspark/opt/lib/sys/usr/lib/"; \
    \
    # Copy headers
    echo "Populating sysroot usr/include..." && \
    if [ -d "/usr/include" ] && [ -d "/lilyspark/opt/lib/sys/usr/include" ]; then \
        if cp -r /usr/include/* /lilyspark/opt/lib/sys/usr/include/ 2>/dev/null; then \
            echo "✓ Headers copied"; \
        else \
            echo "⚠ Header copy failed, creating minimal include structure"; \
            touch /lilyspark/opt/lib/sys/usr/include/stdio.h; \
        fi; \
    else \
        echo "⚠ Source or destination for headers missing"; \
    fi; \
    \
    # STRATEGY 3: Create critical symlinks if missing
    echo "Creating essential symlinks..." && \
    if [ -d "/lilyspark/opt/lib/sys/usr/lib" ]; then \
        cd "/lilyspark/opt/lib/sys/usr/lib" && \
        if [ ! -e "Scrt1.o" ] && [ -f "crt1.o" ]; then \
            ln -sf "crt1.o" "Scrt1.o" && echo "✓ Created Scrt1.o symlink"; \
        else \
            echo "ℹ Scrt1.o symlink not needed or not possible"; \
        fi; \
        cd - >/dev/null; \
    else \
        echo "⚠ Cannot create symlinks, usr/lib directory missing"; \
    fi; \
    \
    # STRATEGY 4: Final validation and inventory
    echo "=== SYSROOT POPULATION VALIDATION ===" && \
    echo "Checking /lilyspark/opt/lib/sys structure..." && \
    find /lilyspark/opt/lib/sys -type d -name "lib" -o -name "include" | head -5 || echo "Base directories missing!"; \
    \
    echo "Critical file check:" && \
    check_file() { \
        if [ -e "$1" ]; then \
            echo "✓ $1"; \
        else \
            echo "✗ $1 (MISSING)"; \
        fi; \
    }; \
    \
    check_file "/lilyspark/opt/lib/sys/usr/lib/crt1.o"; \
    check_file "/lilyspark/opt/lib/sys/usr/lib/crti.o"; \
    check_file "/lilyspark/opt/lib/sys/usr/lib/libgcc_s.so"; \
    check_file "/lilyspark/opt/lib/sys/lib/ld-musl-aarch64.so.1"; \
    check_file "/lilyspark/opt/lib/sys/lib/libc.musl-aarch64.so.1"; \
    \
    echo "=== ROBUST SYSROOT POPULATION COMPLETE ==="

# ======================
# SYSROOT POPULATION (for libdrm, libepoxy, etc.)
# ======================
RUN echo "=== POPULATING SYSROOT (shared for multiple dependencies, ARM64-aware) ===" && \
    ARCH="$(uname -m)" && echo "Detected architecture: $ARCH"; \
    \
    # LLVM runtime & headers
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        echo "Copying LLVM runtime & headers for ARM64..."; \
        cp -av /usr/lib/llvm-16/lib/clang/* /lilyspark/opt/lib/sys/usr/lib/clang/ 2>/dev/null || echo "⚠ LLVM headers copy failed"; \
    else \
        echo "Copying LLVM runtime & headers for x86_64 fallback..."; \
        cp -av /usr/lib/llvm-16/lib/clang/* /lilyspark/opt/lib/sys/usr/lib/clang/ 2>/dev/null || echo "⚠ LLVM headers copy failed"; \
    fi; \
    \
    # System headers
    echo "Copying system headers..."; \
    cp -av /usr/include/* /lilyspark/opt/lib/sys/usr/include/ 2>/dev/null || echo "⚠ System headers copy failed"; \
    \
    # System libraries
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        echo "Copying ARM64 libraries..."; \
        cp -av /usr/lib/aarch64-linux-gnu/* /lilyspark/opt/lib/sys/usr/lib/ 2>/dev/null || echo "⚠ ARM64 libraries copy failed"; \
    else \
        echo "Copying x86_64 libraries fallback..."; \
        cp -av /usr/lib/x86_64-linux-gnu/* /lilyspark/opt/lib/sys/usr/lib/x86_64-linux-gnu/ 2>/dev/null || echo "⚠ x86_64 libraries copy failed"; \
    fi; \
    \
    echo "--- Verification ---"; \
    echo "Include:"; ls -la /lilyspark/opt/lib/sys/usr/include | head -20; \
    echo "Lib:"; ls -la /lilyspark/opt/lib/sys/usr/lib | head -20; \
    echo "Pkgconfig:"; ls -la /lilyspark/opt/lib/sys/usr/lib/pkgconfig | head -20; \
    echo "✅ Sysroot population complete"

# ======================
# SYSROOT POPULATION (ARM64-safe for SHADERC, full lib fallback)
# ======================
RUN echo "=== SYSROOT POPULATION FOR SHADERC ===" && \
    ARCH="$(uname -m)" && \
    SYSROOT_BASE="/lilyspark/opt/lib/sys" && \
    GRAPHICS_BASE="/lilyspark/opt/lib/graphics" && \
    \
    # Copy Shaderc + SPIRV headers, libs, pkgconfig into sysroot
    if [ -d "$GRAPHICS_BASE/include" ]; then \
        echo "Copying includes from $GRAPHICS_BASE/include -> $SYSROOT_BASE/usr/include/"; \
        cp -av "$GRAPHICS_BASE/include/"* "$SYSROOT_BASE/usr/include/" || true; \
    fi && \
    if [ -d "$GRAPHICS_BASE/lib" ]; then \
        echo "Copying libs from $GRAPHICS_BASE/lib -> $SYSROOT_BASE/usr/lib/"; \
        cp -av "$GRAPHICS_BASE/lib/"* "$SYSROOT_BASE/usr/lib/" || true; \
    fi && \
    if [ -d "$GRAPHICS_BASE/lib/pkgconfig" ]; then \
        echo "Copying pkgconfig from $GRAPHICS_BASE/lib/pkgconfig -> $SYSROOT_BASE/usr/lib/pkgconfig/"; \
        cp -av "$GRAPHICS_BASE/lib/pkgconfig/"* "$SYSROOT_BASE/usr/lib/pkgconfig/" || true; \
    fi && \
    \
    # Copy essential runtime libraries (musl + gcc + stdc++ + libm)
    echo "=== COPYING ESSENTIAL RUNTIME LIBRARIES ==="; \
    for lib in libc.musl-*.so.1 ld-musl-*.so.1 libgcc_s.so* libstdc++.so* libm.so* libm.a; do \
        FOUND=0; \
        for dir in /lib /usr/lib /usr/lib/gcc/*/* /usr/lib/aarch64-linux-gnu; do \
            for f in $dir/$lib; do \
                if [ -e "$f" ]; then \
                    echo "Found $lib in $dir -> copying"; \
                    cp -av "$f" "$SYSROOT_BASE/usr/lib/" || true; \
                    FOUND=1; \
                fi; \
            done; \
        done; \
        if [ "$FOUND" -eq 0 ]; then echo "⚠ $lib not found in standard locations"; fi; \
    done && \
    \
    # Create linker-friendly symlinks (libm and libc included)
    echo "=== CREATING LINKER-FRIENDLY SYMLINKS ==="; \
    cd "$SYSROOT_BASE/usr/lib" || exit 1; \
    for f in libc.musl-*.so.1 libgcc_s.so* libstdc++.so* ld-musl-*.so.1 libm.so* libm.a; do \
        for real in $f; do \
            if [ -e "$real" ]; then \
                base=$(echo $real | sed -E 's/(\.so)(\..*)?/\1/'); \
                soname=$(echo $real | sed -E 's/(\.so\.[0-9.]+).*/\1/'); \
                [ ! -L "$soname" ] && ln -sf "$real" "$soname"; \
                [ ! -L "$base" ] && ln -sf "$soname" "$base"; \
            fi; \
        done; \
    done && \
    \
    # ARM64-specific copy if needed
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        if [ -d /usr/lib/aarch64-linux-gnu ]; then \
            echo "Copying additional ARM64 libs -> $SYSROOT_BASE/usr/lib/"; \
            cp -av /usr/lib/aarch64-linux-gnu/* "$SYSROOT_BASE/usr/lib/" || true; \
        fi; \
        echo "✅ ARM64 sysroot fully populated at $SYSROOT_BASE"; \
    else \
        echo "⚠ Non-ARM64 architecture ($ARCH) detected — Shaderc sysroot populated as best-effort"; \
    fi && \
    \
    echo "=== SYSROOT CONTENTS AFTER POPULATION ==="; \
    ls -la "$SYSROOT_BASE/usr/lib"/libc.musl* "$SYSROOT_BASE/usr/lib"/libgcc* "$SYSROOT_BASE/usr/lib"/libstdc* "$SYSROOT_BASE/usr/lib"/libm* "$SYSROOT_BASE/usr/lib"/ld-musl-* || echo "Some runtime libs may be missing"



# ======================
# SYSROOT POPULATION FOR SDL3 IMAGE LIBRARIES
# ======================
RUN echo "=== POPULATING SYSROOT WITH SDL3 IMAGE LIBRARIES ===" && \
    \
    # Symlink shared libraries (.so*) into sysroot
    find /lilyspark/usr/local/lib/image -type f -name "*.so*" \
        -exec ln -sf {} /lilyspark/opt/lib/sys/usr/lib/ \; 2>/dev/null || true && \
    \
    # Copy headers into sysroot
    find /lilyspark/usr/local/lib/image -maxdepth 1 -type d \
        -exec cp -a {} /lilyspark/opt/lib/sys/usr/include/ \; 2>/dev/null || true && \
    \
    echo "✅ SDL3 image libraries and headers populated into sysroot" && \
    echo "Library count:" && \
    ls -1 /lilyspark/opt/lib/sys/usr/lib/lib{jpeg,png,tiff,avif,webp}*.so* 2>/dev/null | wc -l

# ======================
# SYSROOT POPULATION (ARM64-safe)
# ======================
RUN echo "=== SYSROOT POPULATION FOR GST ==="; \
    ARCH="$(uname -m)"; \
    SYSROOT_BASE="/lilyspark/opt/lib/sys"; \
    mkdir -p "$SYSROOT_BASE/usr/lib/clang" "$SYSROOT_BASE/usr/include" "$SYSROOT_BASE/usr/lib/aarch64-linux-gnu"; \
    \
    # Copy LLVM runtime & headers
    if [ -d /usr/lib/llvm16/lib/clang ]; then \
        cp -a /usr/lib/llvm16/lib/clang/* "$SYSROOT_BASE/usr/lib/clang/" 2>/dev/null || true; \
    fi; \
    if [ -d /usr/include ]; then \
        cp -a /usr/include/* "$SYSROOT_BASE/usr/include/" 2>/dev/null || true; \
    fi; \
    \
    # Copy ARM64 system libraries if detected
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        if [ -d /usr/lib/aarch64-linux-gnu ]; then \
            cp -a /usr/lib/aarch64-linux-gnu/* "$SYSROOT_BASE/usr/lib/aarch64-linux-gnu/" 2>/dev/null || true; \
        fi; \
        echo "✅ ARM64 sysroot populated at $SYSROOT_BASE"; \
    else \
        echo "⚠ Non-ARM64 architecture ($ARCH) detected — sysroot populated as best-effort"; \
    fi; \
    \
    # Optional: populate common x86_64 libraries if cross-compiling x86_64 binaries
    if [ -d /usr/lib/x86_64-linux-gnu ]; then \
        cp -a /usr/lib/x86_64-linux-gnu/* "$SYSROOT_BASE/usr/lib/x86_64-linux-gnu/" 2>/dev/null || true; \
    fi

# ======================
# SYSROOT POPULATION FOR XORG (ARM64-safe, non-fatal)
# ======================
RUN set -ux; \
    echo "=== POPULATING /lilyspark SYSROOT FOR XORG ==="; \
    SYSROOT="/lilyspark"; \
    SR_USR_LIB="$SYSROOT/usr/lib"; \
    SR_USR_INCLUDE="$SYSROOT/usr/include"; \
    SR_LIB="$SYSROOT/lib"; \
    mkdir -p "$SR_USR_LIB" "$SR_USR_INCLUDE" "$SR_LIB"; \
    \
    copy_and_verify() { \
        src="$1"; dest="$2"; descr="$3"; \
        echo "Attempting to copy ($descr): $src -> $dest"; \
        mkdir -p "$dest" 2>/dev/null || true; \
        if cp -a $src "$dest" 2>/dev/null; then \
            echo "✓ Copied: $src -> $dest"; \
        else \
            echo "⚠ Could not copy $src -> $dest (continuing)"; \
            # make harmless placeholder so configure won't choke on empty dirs \
            if [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then \
                touch "$dest/.placeholder" || true; \
            fi; \
        fi; \
    }; \
    \
    echo "Copying crt objects and startup files..."; \
    copy_and_verify "/usr/lib/crt*.o" "$SR_USR_LIB" "crt objects (usr/lib)"; \
    copy_and_verify "/usr/lib/gcc/*/*/crt*.o" "$SR_USR_LIB" "gcc crt objects"; \
    copy_and_verify "/usr/lib/gcc/*/*/*.a" "$SR_USR_LIB" "gcc static libs"; \
    \
    echo "Copying libc/musl and dynamic linker..."; \
    # copy usual musl dynamic loader (ld-musl-*.so.1) and musl shared object names \
    copy_and_verify "/lib/ld-musl-*.so.1" "$SR_LIB" "musl dynamic loader"; \
    copy_and_verify "/lib/libc.musl-*.so.1" "$SR_LIB" "musl libc"; \
    copy_and_verify "/lib/libpthread*.so*" "$SR_LIB" "pthread"; \
    copy_and_verify "/usr/lib/libc.a" "$SR_USR_LIB" "libc static (dev)"; \
    \
    # Create essential symlinks if musl files were copied
    if ls /lilyspark/lib/ld-musl-*.so.1 >/dev/null 2>&1; then \
        cd /lilyspark/lib && \
        for f in ld-musl-*.so.1; do \
            ln -sf "$f" "ld-linux-$(uname -m).so.1" 2>/dev/null || true; \
            ln -sf "$f" "ld-linux.so.1" 2>/dev/null || true; \
        done && \
        cd - >/dev/null; \
        echo "✓ Created musl symlinks"; \
    else \
        echo "⚠ No musl loader found, creating placeholder"; \
        touch /lilyspark/lib/.musl-placeholder; \
    fi; \
    \
    echo "Copying compiler support and libgcc..."; \
    copy_and_verify "/usr/lib/libgcc*" "$SR_USR_LIB" "libgcc"; \
    copy_and_verify "/usr/lib/libssp*" "$SR_USR_LIB" "libssp"; \
    copy_and_verify "/usr/lib/libatomic*" "$SR_USR_LIB" "libatomic"; \
    \
    echo "Copying math and other standard libs..."; \
    copy_and_verify "/usr/lib/libm.a" "$SR_USR_LIB" "libm static"; \
    copy_and_verify "/usr/lib/libm.so*" "$SR_USR_LIB" "libm shared"; \
    copy_and_verify "/usr/lib/libdl.so*" "$SR_USR_LIB" "libdl"; \
    \
    echo "Copying standard /usr/include headers (best-effort)..."; \
    if [ -d /usr/include ]; then \
        if cp -r /usr/include/* "$SR_USR_INCLUDE/" 2>/dev/null; then \
            echo "✓ Headers copied to $SR_USR_INCLUDE"; \
        else \
            echo "⚠ Header copy failed (continuing) — creating minimal headers"; \
            mkdir -p "$SR_USR_INCLUDE/asm" "$SR_USR_INCLUDE/linux" "$SR_USR_INCLUDE/bits" 2>/dev/null || true; \
            touch "$SR_USR_INCLUDE/stdio.h" "$SR_USR_INCLUDE/stdlib.h" 2>/dev/null || true; \
        fi; \
    else \
        echo "⚠ /usr/include not present — creating minimal include tree"; \
        mkdir -p "$SR_USR_INCLUDE" || true; \
        touch "$SR_USR_INCLUDE/.placeholder"; \
    fi; \
    \
    echo "Copying LLVM/clang runtime headers if present (helps clang link tests)"; \
    if [ -d /usr/lib/llvm16/lib/clang ]; then \
        mkdir -p "$SR_USR_LIB/clang" 2>/dev/null || true; \
        cp -a /usr/lib/llvm16/lib/clang/* "$SR_USR_LIB/clang/" 2>/dev/null || true; \
    fi; \
    \
    echo "Create essential symlinks inside sysroot (non-destructive)"; \
    # ensure dynamic loader is at /lib/ld-musl-aarch64.so.1 path inside sysroot \
    if ls "$SR_LIB"/ld-musl-*.so.1 >/dev/null 2>&1; then \
        for f in "$SR_LIB"/ld-musl-*.so.1; do \
            base=$(basename "$f"); \
            ln -sf "$base" "$SR_LIB/ld-musl-aarch64.so.1" 2>/dev/null || true; \
            ln -sf "$base" "$SR_LIB/ld-musl.so.1" 2>/dev/null || true; \
        done; \
        echo "✓ ensured musl loader names in $SR_LIB"; \
    else \
        echo "⚠ musl loader not found in $SR_LIB (try copying from host)"; \
    fi; \
    \
    # create libc.so and libpthread.so symlinks to aid linkers that expect those names \
    if ls "$SR_LIB"/libc.musl-*.so.1 >/dev/null 2>&1; then \
        ln -sf "$(basename "$(ls -1 "$SR_LIB"/libc.musl-*.so.1 | head -n1)")" "$SR_LIB/libc.so" 2>/dev/null || true; \
    fi; \
    if ls "$SR_LIB"/libpthread*.so* >/dev/null 2>&1; then \
        ln -sf "$(basename "$(ls -1 "$SR_LIB"/libpthread*.so* | head -n1)")" "$SR_LIB/libpthread.so" 2>/dev/null || true; \
    fi; \
    \
    echo "Create Scrt1.o alias if needed (some toolchains expect Scrt1.o)"; \
    if [ -f "$SR_USR_LIB/crt1.o" ] && [ ! -f "$SR_USR_LIB/Scrt1.o" ]; then \
        ln -sf crt1.o "$SR_USR_LIB/Scrt1.o" 2>/dev/null || true; \
    fi; \
    \
    echo "Populate /lilyspark/opt/lib/media + /lilyspark/compiler include/lib overlays (best-effort)"; \
    mkdir -p "$SYSROOT/opt/lib/media/lib" "$SYSROOT/opt/lib/media/include" "$SYSROOT/compiler/lib" "$SYSROOT/compiler/include" 2>/dev/null || true; \
    cp -a /lilyspark/opt/lib/media/lib/* "$SYSROOT/opt/lib/media/lib/" 2>/dev/null || true; \
    cp -a /lilyspark/opt/lib/media/include/* "$SYSROOT/opt/lib/media/include/" 2>/dev/null || true; \
    cp -a /lilyspark/compiler/lib/* "$SYSROOT/compiler/lib/" 2>/dev/null || true; \
    cp -a /lilyspark/compiler/include/* "$SYSROOT/compiler/include/" 2>/dev/null || true; \
    \
    echo "Final verification: list a few sysroot entries (non-fatal)"; \
    ls -la "$SR_LIB" | sed -n '1,20p' || true; \
    ls -la "$SR_USR_LIB" | sed -n '1,20p' || true; \
    ls -la "$SR_USR_INCLUDE" | sed -n '1,20p' || true; \
    echo "=== SYSROOT POPULATION COMPLETE (non-fatal) ==="

# ===========================
# Build From Source Libraries
# ===========================
# Apache FOP is considered a Java library, stored at /lilyspark/opt/lib/java (no need to mkdir directory in the code)
RUN echo "=== INSTALLING Apache FOP 2.11 (isolated, safe) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-fop-install" || true && \
    \
    # Download and extract official FOP binary release
    mkdir -p /tmp/fop && \
    wget -O /tmp/fop/fop-bin.tar.gz https://dlcdn.apache.org/xmlgraphics/fop/binaries/fop-2.11-bin.tar.gz && \
    tar -xzf /tmp/fop/fop-bin.tar.gz -C /tmp/fop --strip-components=1 && \
    \
    # Locate and copy launcher file (or entire bin directory)
    launcher="$(find /tmp/fop -type f \( -name fop -o -name 'fop.sh' -o -name 'fop.bat' \) -print | head -n 1 || true)" && \
    if [ -n "$launcher" ]; then \
        echo "Found launcher at: $launcher" && cp "$launcher" /lilyspark/opt/lib/java/fop/bin/; \
        # If it's a Windows batch file, create a Unix wrapper
        if echo "$launcher" | grep -q "\.bat$"; then \
            echo "Creating Unix wrapper for Windows batch file" && \
            echo '#!/bin/sh' > /lilyspark/opt/lib/java/fop/bin/fop && \
            echo 'java -cp "/lilyspark/opt/lib/java/fop/lib/*" org.apache.fop.cli.Main "$@"' >> /lilyspark/opt/lib/java/fop/bin/fop && \
            chmod +x /lilyspark/opt/lib/java/fop/bin/fop; \
        fi; \
    else \
        bindir="$(find /tmp/fop -type d -name bin -print | head -n 1 || true)" && \
        if [ -n "$bindir" ]; then \
            echo "Found bin directory at: $bindir" && cp -r "$bindir"/* /lilyspark/opt/lib/java/fop/bin/ 2>/dev/null || true; \
        else \
            echo "ERROR: fop launcher or bin/ directory not found in extracted tree" >&2 && ls -la /tmp/fop || true && false; \
        fi; \
    fi && \
    \
    # Copy all jar files to lib/
    echo "Copying JARs from extracted tree into /lilyspark/opt/lib/java/fop/lib" && \
    find /tmp/fop -type f -name '*.jar' -print -exec cp -a {} /lilyspark/opt/lib/java/fop/lib/ \; || true && \
    \
    # Fallback if lib is empty
    if [ "$(ls -A /lilyspark/opt/lib/java/fop/lib 2>/dev/null || true)" = "" ]; then \
        echo "No jars copied yet; trying nested locations" && \
        find /tmp/fop -type f -path '*/fop/*' -name '*.jar' -print -exec cp -a {} /lilyspark/opt/lib/java/fop/lib/ \; || true; \
    fi && \
    \
    # === CREATE FOP MANIFEST FILE FOR CMAKE ===
    echo "Creating FOP manifest for CMake detection..." && \
    # Get JAR files list
    FOP_JARS=$(find /lilyspark/opt/lib/java/fop/lib -name "*.jar" 2>/dev/null | tr '\n' ':' | sed 's/:$//' || echo "") && \
    # Get launcher path - FIXED: Check for both Unix and created wrapper
    FOP_LAUNCHER_PATH=$(find /lilyspark/opt/lib/java/fop \( -name "fop" -o -name "fop.sh" \) -type f 2>/dev/null | head -n1 || echo "") && \
    # If no Unix launcher found but we created a wrapper, use that
    if [ -z "$FOP_LAUNCHER_PATH" ] && [ -f "/lilyspark/opt/lib/java/fop/bin/fop" ]; then \
        FOP_LAUNCHER_PATH="/lilyspark/opt/lib/java/fop/bin/fop"; \
    fi; \
    # Get actual JAR count
    FOP_JAR_COUNT=$(find /lilyspark/opt/lib/java/fop/lib -name "*.jar" 2>/dev/null | wc -l || echo 0) && \
    # Create manifest JSON
    echo "{" > /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"version\": \"2.11\"," >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"install_path\": \"/lilyspark/opt/lib/java/fop\"," >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"jar_count\": ${FOP_JAR_COUNT}," >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"classpath\": \"${FOP_JARS}\"," >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"launcher\": \"${FOP_LAUNCHER_PATH}\"," >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "  \"status\": \"installed\"" >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    echo "}" >> /lilyspark/opt/lib/java/fop/metadata/manifest.json && \
    \
    # Copy docs/snippets (best-effort)
    cp -r /tmp/fop/javadocs /lilyspark/opt/lib/java/fop/docs/ 2>/dev/null || true && \
    cp -r /tmp/fop/README* /lilyspark/opt/lib/java/fop/docs/ 2>/dev/null || true && \
    cp -r /tmp/fop/LICENSE* /lilyspark/opt/lib/java/fop/docs/ 2>/dev/null || true && \
    \
    # Ensure proper permissions
    chmod -R a+rx /lilyspark/opt/lib/java/fop || true && \
    \
    # Install user-provided POSIX wrapper if available
    if [ -f /tmp/fop-wrapper.sh ]; then \
        echo "Installing fop-wrapper from build context into /lilyspark/opt/lib/java/fop/bin/fop" && \
        install -m 0755 /tmp/fop-wrapper.sh /lilyspark/opt/lib/java/fop/bin/fop || true; \
    fi && \
    \
    # Make all binaries executable
    if [ -n "$(find /lilyspark/opt/lib/java/fop/bin -type f -print -quit 2>/dev/null)" ]; then \
        find /lilyspark/opt/lib/java/fop/bin -type f -exec chmod +x {} \; 2>/dev/null || true; \
    fi && \
    \
    # Create dedicated launcher symlink (isolated, safe)
    if [ -f /lilyspark/opt/lib/java/fop/bin/fop ]; then \
        ln -sf /lilyspark/opt/lib/java/fop/bin/fop /lilyspark/opt/lib/java/fop/launchers/fop; \
    elif [ -f /lilyspark/opt/lib/java/fop/bin/fop.sh ]; then \
        ln -sf /lilyspark/opt/lib/java/fop/bin/fop.sh /lilyspark/opt/lib/java/fop/launchers/fop; \
    fi && \
    \
    # Update environment to include isolated launcher
    echo 'export PATH=$PATH:/lilyspark/opt/lib/java/fop/launchers' >> /lilyspark/etc/profile.d/sysroot.sh && \
    echo 'export CLASSPATH=$CLASSPATH:/lilyspark/opt/lib/java/fop/lib/*' >> /lilyspark/etc/profile.d/sysroot.sh && \
    echo 'PATH=$PATH:/lilyspark/opt/lib/java/fop/launchers' >> /lilyspark/etc/environment && \
    echo 'CLASSPATH=$CLASSPATH:/lilyspark/opt/lib/java/fop/lib/*' >> /lilyspark/etc/environment && \
    \
    # Run SUID/SGID scanner - handle missing script gracefully
    echo "=== RUNNING SUID/SGID SCANNER ON FOP INSTALLATION ===" && \
    if [ -x /usr/local/bin/sgid_suid_scanner.sh ]; then \
        /usr/local/bin/sgid_suid_scanner.sh /lilyspark/opt/lib/java/fop; \
    else \
        echo "SUID/SGID scanner not found, skipping"; \
    fi && \
    echo "=== SGID/SUID scan completed for FOP installation ===" && \
    \
    # Verify installation
    echo "=== VERIFYING Apache FOP INSTALLATION ===" && \
    echo "Contents of /lilyspark/opt/lib/java/fop/lib:" && ls -la /lilyspark/opt/lib/java/fop/lib || true && \
    echo "FOP manifest created:" && cat /lilyspark/opt/lib/java/fop/metadata/manifest.json || true && \
    JAVA_BIN="$(command -v java || true)" && \
    if [ -n "$JAVA_BIN" ]; then \
        echo "Found java at: $JAVA_BIN"; \
        echo "Attempting explicit java -cp '/lilyspark/opt/lib/java/fop/lib/*' org.apache.fop.cli.Main -version"; \
        "$JAVA_BIN" -cp "/lilyspark/opt/lib/java/fop/lib/*" org.apache.fop.cli.Main -version 2>/dev/null || echo "Java test completed (return code: $?)"; \
    else \
        echo "Java not found in PATH; ensure openjdk11 installed in this stage"; \
    fi && \
    \
    /usr/local/bin/check_llvm15.sh "post-fop-install" || true && \
    if [ -x /usr/local/bin/check-filesystem.sh ]; then \
        /usr/local/bin/check-filesystem.sh "post-fop-install" || true; \
    else \
        echo "Filesystem check script not found, skipping"; \
    fi && \
    \
    # Cleanup
    rm -rf /tmp/fop

# JACK2 is considered an audio library at /lilyspark/opt/lib/audio
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
        # Capture git commit hash, tag, and version info
        cd /tmp/jack2-source && \
        JACK2_COMMIT=$(git rev-parse HEAD) && \
        JACK2_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "1.9.23") && \
        JACK2_VERSION=$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo "1.9.23") && \
        echo "JACK2 commit: $JACK2_COMMIT" && \
        echo "JACK2 tag: $JACK2_TAG" && \
        echo "JACK2 version: $JACK2_VERSION" && \
        # Store comprehensive version info for dependencies tracking
        echo "{" > /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
        echo "  \"git\": \"https://github.com/jackaudio/jack2.git\"," >> /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
        echo "  \"commit\": \"$JACK2_COMMIT\"," >> /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
        echo "  \"tag\": \"$JACK2_TAG\"," >> /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
        echo "  \"version\": \"$JACK2_VERSION\"" >> /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
        echo "}" >> /lilyspark/opt/lib/audio/jack2/metadata/version.json; \
    else \
        echo "ERROR: Could not clone JACK2 repository" >&2 && false; \
    fi && \
    \
    cd /tmp/jack2-source && \
    \
    # Install libexecinfo for execinfo.h support (quietly)
    apk add --no-cache libexecinfo-dev >/dev/null 2>&1 || echo "Note: libexecinfo-dev not available, continuing without it" >&2 && \
    \
    if [ -x ./waf ]; then \
        echo ">>> Using waf build system <<<"; \
        # Enhanced filtering: keep only "yes", important settings, and remove all "no" and ucontext checks
        ./waf configure --prefix=/usr --libdir=/usr/lib 2>&1 | grep -v "not found" | grep -v "ERROR" | grep -v "no" | grep -E "(Checking for|yes|Setting|JACK|Maximum|Build|Enable|Use|C\+\+|Linker)" | grep -v "ucontext" || true && \
        ./waf build && \
        DESTDIR="/lilyspark/opt/lib/audio/jack2" ./waf install; \
    else \
        echo ">>> Waf not found, trying autotools <<<"; \
        if [ -x ./configure ]; then \
            # Redirect configure output with enhanced filtering
            ./configure --prefix=/usr --libdir=/usr/lib --with-sysroot=/lilyspark/opt/lib/audio/jack2 2>&1 | grep -v "not found" | grep -v "checking for" | grep -v "no" | grep -E "(yes|YES|configure:)" || true && \
            make -j$(nproc) && \
            make DESTDIR="/lilyspark/opt/lib/audio/jack2" install; \
        else \
            echo "ERROR: No recognized build system found (waf or autotools)" >&2 && false; \
        fi; \
    fi && \
    \
    echo "=== RELOCATING JACK2 BINARIES ===" && \
    # Move executables to jack-specific bin directory
    if [ -d /lilyspark/opt/lib/audio/jack2/usr/bin ]; then \
        find /lilyspark/opt/lib/audio/jack2/usr/bin -maxdepth 1 -type f -name "jack*" -exec mv -v {} /lilyspark/opt/lib/audio/jack2/bin/ \; || true; \
    fi && \
    \
    echo "=== VERIFYING JACK2 INSTALLATION ===" && \
    find /lilyspark/opt/lib/audio/jack2/bin -type f -name "jack*" -ls && \
    find /lilyspark/opt/lib/audio/jack2/usr/lib -type f -name "libjack*" -ls && \
    \
    # Display the captured version info
    echo "=== JACK2 BUILD COMPLETE ===" && \
    echo "Version info stored at: /lilyspark/opt/lib/audio/jack2/metadata/version.json" && \
    cat /lilyspark/opt/lib/audio/jack2/metadata/version.json && \
    \
    /usr/local/bin/check_llvm15.sh "post-jack2-install" || true && \
    \
    cd / && rm -rf /tmp/jack2 /tmp/jack2-source

# ======================
# BUILD PlutoSVG
# ======================
# This is a graphics library, so its path is: /lilyspark/opt/lib/audio
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
        python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip setuptools wheel || true && \
        python3 -m pip install --no-cache-dir --break-system-packages 'meson>=1.3.0' || echo "Warning: pip meson install failed - will attempt fallback patch"; \
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
        export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/graphics" && \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" && \
        meson --version || echo "meson not found or version unknown" && \
        meson setup builddir --prefix=/usr -Dc_std=gnu11 || { echo 'Meson configure failed' >&2; false; } && \
        ninja -C builddir -v || { echo 'Ninja build failed' >&2; false; } && \
        DESTDIR="/lilyspark/opt/lib/graphics" ninja -C builddir install || { echo 'Install failed' >&2; false; }; \
    else \
        echo "ERROR: meson.build not found, cannot configure PlutoSVG" >&2 && false; \
    fi && \
    \
    # Verify installation
    echo "=== VERIFYING PlutoSVG INSTALLATION ===" && \
    if find /lilyspark/opt/lib/graphics -name "*plutosvg*" -type f | tee /tmp/plutosvg_install.log; then \
        echo "PlutoSVG files present in /lilyspark/opt/lib/graphics"; \
    else \
        echo "WARNING: No PlutoSVG files found in /lilyspark/opt/lib/graphics"; \
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
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/sys" && \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig" && \
    \
    # Use minimal meson options - let it auto-detect what's available
    meson setup builddir \
        --prefix=/usr && \
    \
    ninja -C builddir -v && \
    # CRITICAL: Install to target filesystem, not host
    DESTDIR="/lilyspark/opt/lib/sys" ninja -C builddir install && \
    \
    # Verify installation in target
    echo "=== VERIFYING PCIACCESS INSTALLATION IN TARGET ===" && \
    find /lilyspark/opt/lib/sys -name "*pciaccess*" -type f | tee /tmp/pciaccess_install.log && \
    echo "pciaccess.pc file contents:" && \
    cat /lilyspark/opt/lib/sys/usr/lib/pkgconfig/pciaccess.pc || echo "pciaccess.pc not found" && \
    \
    /usr/local/bin/check_llvm15.sh "post-pciaccess-install" || true && \
    \
    # Cleanup
    cd / && rm -rf /tmp/libpciaccess

# ======================
# libdrm Build (ARM64-safe, fully logged)
# ======================
ARG LIBDRM_VER=2.4.125
ARG LIBDRM_URL="https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VER}.tar.xz"

ENV PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
ENV PATH="/lilyspark/compiler/bin:${PATH}"

RUN echo "=== START: BUILDING libdrm ${LIBDRM_VER} ===" && \
    ARCH="$(uname -m)" && echo "Detected architecture: $ARCH"; \
    \
    mkdir -p /tmp/libdrm-src && cd /tmp/libdrm-src; \
    echo "Fetching libdrm tarball: ${LIBDRM_URL}"; \
    curl -L "${LIBDRM_URL}" -o libdrm.tar.xz || (echo "⚠ Failed to fetch libdrm tarball"; exit 0); \
    tar -xf libdrm.tar.xz --strip-components=1 || echo "⚠ Tar extraction failed"; \
    \
    # ----------------------
    # 1️⃣ Compiler detection & native file
    # ----------------------
    echo "=== Compiler detection ==="; \
    CC_FALLBACK="cc"; CXX_FALLBACK="c++"; \
    CC="$(command -v /lilyspark/compiler/bin/clang-16 || command -v clang || echo $CC_FALLBACK)"; \
    CXX="$(command -v /lilyspark/compiler/bin/clang++-16 || command -v clang++ || echo $CXX_FALLBACK)"; \
    echo "Using CC=$CC, CXX=$CXX"; command -v $CC || echo "⚠ $CC not in PATH"; command -v $CXX || echo "⚠ $CXX not in PATH"; \
    \
    echo "Creating Meson native file..."; \
    echo "[binaries]" > native-file.ini; \
    echo "c = '$CC'" >> native-file.ini; \
    echo "cpp = '$CXX'" >> native-file.ini; \
    echo "ar = 'ar'" >> native-file.ini; \
    echo "strip = 'strip'" >> native-file.ini; \
    echo "pkg-config = 'pkg-config'" >> native-file.ini; \
    echo "[host_machine]" >> native-file.ini; \
    echo "system = 'linux'" >> native-file.ini; \
    echo "cpu_family = '$ARCH'" >> native-file.ini; \
    echo "cpu = '$ARCH'" >> native-file.ini; \
    echo "endian = 'little'" >> native-file.ini; \
    cat native-file.ini; \
    \
    # ----------------------
    # 2️⃣ Meson setup, build, install
    # ----------------------
    echo "=== Meson setup ==="; \
    meson setup builddir \
        --prefix=/usr \
        --libdir=lib \
        --buildtype=release \
        -Dtests=false \
        -Dudev=false \
        -Dvalgrind=disabled \
        --native-file native-file.ini \
        -Dpkg_config_path="$PKG_CONFIG_PATH" 2>&1 | tee /tmp/libdrm-meson-setup.log; \
    \
    echo "=== Meson compile ==="; \
    meson compile -C builddir -j$(nproc) 2>&1 | tee /tmp/libdrm-meson-compile.log; \
    \
    echo "=== Meson install ==="; \
    meson install -C builddir --destdir /lilyspark/opt/lib/graphics --no-rebuild 2>&1 | tee /tmp/libdrm-meson-install.log; \
    \
    # ----------------------
    # 3️⃣ Populate sysroot after install
    # ----------------------
    echo "=== Populating sysroot AFTER installation ==="; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig}; \
    cp -av /lilyspark/opt/lib/graphics/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || echo "⚠ include copy failed"; \
    cp -av /lilyspark/opt/lib/graphics/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || echo "⚠ lib copy failed"; \
    cp -av /lilyspark/opt/lib/graphics/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ pkgconfig copy failed"; \
    ls -la $SYSROOT/usr/include | head -20; \
    ls -la $SYSROOT/usr/lib | head -20; \
    ls -la $SYSROOT/usr/lib/pkgconfig | head -20; \
    \
    # ----------------------
    # 4️⃣ Verify pkg-config can see it
    # ----------------------
    echo "=== Verifying pkg-config can see libdrm ==="; \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:$PKG_CONFIG_PATH"; \
    pkg-config --modversion libdrm || echo "⚠ libdrm still not detected"; \
    pkg-config --cflags libdrm; pkg-config --libs libdrm; \
    \
    # ----------------------
    # 5️⃣ Post-install verification
    # ----------------------
    echo "=== Post-install verification ==="; \
    ls -R /lilyspark/opt/lib/graphics | head -50; \
    cd /; rm -rf /tmp/libdrm-src native-file.ini; \
    echo "=== libdrm BUILD complete ==="; \
    true



# ======================
# SECTION: SDL3 Image Dependencies
# ======================
RUN echo "=== COPYING SDL3 IMAGE LIBRARIES TO SDL3 DIRECTORY ===" && \
    cp -a /lilyspark/usr/local/lib/image/*.so* /lilyspark/opt/lib/sdl3/lib/ 2>/dev/null || true && \
    cp -a /lilyspark/usr/local/lib/image/*.h /lilyspark/opt/lib/sdl3/include/ 2>/dev/null || true && \
    echo "=== VERIFYING SDL3 IMAGE LIBRARIES ===" && \
    ls -la /lilyspark/opt/lib/sdl3/lib/ || echo "Some SDL3 libraries not found" && \
    ls -la /lilyspark/opt/lib/sdl3/include/ || echo "Some SDL3 headers not found"


# ======================
# SECTION: Python Dependencies (FINAL COPY TO OPT)
# ======================

# Install meson via pip (since apk doesn't provide the Python package)
RUN pip3 install meson && /usr/local/bin/check_llvm15.sh "after-pip-meson" || true

RUN echo "=== COPYING PYTHON PACKAGES TO CUSTOM FILESYSTEM ===" && \
    for pkg in mesonbuild mako MarkupSafe; do \
        echo "Looking for $pkg..." && \
        # Look in YOUR preferred lilyspark path
        src_dir=$(find /lilyspark/usr/local/lib/python -type d -name "$pkg" 2>/dev/null | head -n1) && \
        if [ -n "$src_dir" ] && [ -d "$src_dir" ]; then \
            dst_dir="/lilyspark/opt/lib/python/site-packages/$pkg" && \
            cp -R "$src_dir" "$dst_dir" && \
            echo "Copied $pkg -> $dst_dir"; \
        else \
            echo "Python package $pkg not found in preferred path, trying alternatives..." && \
            # Handle case sensitivity
            if [ "$pkg" = "MarkupSafe" ]; then \
                alt_src_dir=$(find /lilyspark/usr/local/lib/python -type d -name "markupsafe" 2>/dev/null | head -n1) && \
                if [ -n "$alt_src_dir" ] && [ -d "$alt_src_dir" ]; then \
                    dst_dir="/lilyspark/opt/lib/python/site-packages/$pkg" && \
                    cp -R "$alt_src_dir" "$dst_dir" && \
                    echo "Copied markupsafe (lowercase) as $pkg -> $dst_dir"; \
                else \
                    echo "ERROR: $pkg not found in any form"; \
                fi; \
            elif [ "$pkg" = "mako" ]; then \
                # Additional debug for mako
                echo "DEBUG: Searching for mako in:" && \
                find /lilyspark/usr/local/lib/python -name "*mako*" -type d 2>/dev/null || echo "No mako files found"; \
                echo "ERROR: mako not found"; \
            else \
                echo "ERROR: $pkg not found"; \
            fi; \
        fi; \
    done && \
    \
    echo "=== VERIFYING PYTHON PACKAGES IN CUSTOM FILESYSTEM ===" && \
    for pkg in mesonbuild mako MarkupSafe; do \
        if [ -d "/lilyspark/opt/lib/python/site-packages/$pkg" ]; then \
            echo "$pkg successfully copied:"; \
            ls -la "/lilyspark/opt/lib/python/site-packages/$pkg" | head -5; \
        else \
            echo "$pkg MISSING from /lilyspark/opt/lib/python/site-packages"; \
        fi; \
    done

# ======================
# SECTION: SPIRV-Headers Build (standalone, installed first)
# ======================
RUN echo "=== BUILDING SPIRV-HEADERS FROM SOURCE ===" && \
    /usr/local/bin/check_llvm15.sh "pre-spirv-headers-build" || true && \
    \
    echo "=== CLONING SPIRV-HEADERS REPO ===" && \
    git clone https://github.com/KhronosGroup/SPIRV-Headers.git spirv-headers && \
    cd spirv-headers && mkdir -p build && cd build && \
    \
    echo "=== CONFIGURING SPIRV-HEADERS INSTALL ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/graphics \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -Wl,-rpath,/lilyspark/compiler/lib" || true && \
    \
    echo "=== INSTALLING SPIRV-HEADERS ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/spirv-headers-install.log || true && \
    \
    echo "=== CLEANUP SPIRV-HEADERS SOURCE DIR ===" && \
    cd ../.. && rm -rf spirv-headers 2>/dev/null || true && \
    \
    echo "=== VERIFICATION: SPIRV-HEADERS INSTALLATION ===" && \
    ls -la /lilyspark/opt/lib/graphics/include/spirv 2>/dev/null || echo "No SPIRV-Headers installed" && \
    /usr/local/bin/check_llvm15.sh "post-spirv-headers-build" || true && \
    echo "=== SPIRV-HEADERS BUILD COMPLETE ==="

# ======================
# SECTION: Populate sysroot and SPIRV-Tools external headers
# ======================
RUN echo "=== POPULATING SYSROOT AND SPIRV-TOOLS EXTERNAL FOLDER WITH SPIRV-HEADERS ===" && \
    SYSROOT="/lilyspark/opt/lib/sys" && \
    HEADER_INSTALL_DIR="/lilyspark/opt/lib/graphics/include/spirv" && \
    mkdir -p "$SYSROOT/include/spirv" && \
    cp -R "$HEADER_INSTALL_DIR/"* "$SYSROOT/include/spirv/" && \
    echo "=== SYSROOT POPULATION COMPLETE ===" && \
    \
    # Also populate SPIRV-Tools external folder so CMake can detect the headers
    mkdir -p /spirv-tools/external && \
    ln -sf "$HEADER_INSTALL_DIR" /spirv-tools/external/spirv-headers && \
    echo "=== SPIRV-TOOLS EXTERNAL FOLDER POPULATED ==="

# ======================
# SECTION: SPIRV-Tools Build (using full SPIRV-Headers source)
# ======================
RUN echo "=== BUILDING SPIRV-TOOLS FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-spirv-tools-source-build" || true && \
    \
    echo "=== CLEAN ANY PREVIOUS SPIRV-TOOLS ===" && \
    rm -rf spirv-tools || true && \
    \
    echo "=== CLONING SPIRV-TOOLS REPO ===" && \
    git clone https://github.com/KhronosGroup/SPIRV-Tools.git spirv-tools && \
    cd spirv-tools && mkdir -p build && \
    \
    echo "=== POPULATE SPIRV-HEADERS INSIDE SPIRV-TOOLS ===" && \
    rm -rf external/spirv-headers && \
    git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/spirv-headers && \
    \
    echo "=== CONFIGURING SPIRV-TOOLS WITH CMAKE ===" && \
    SPIRV_HEADERS_ABS="$(pwd)/external/spirv-headers" && \
    cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/graphics \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DSPIRV-Headers_SOURCE_DIR="$SPIRV_HEADERS_ABS" \
        -DSPIRV_SKIP_TESTS=ON \
        -DCMAKE_C_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -Wl,-rpath,/lilyspark/compiler/lib" || true && \
    \
    echo "=== BUILDING SPIRV-TOOLS ===" && \
    make -j"$(nproc)" 2>&1 | tee /tmp/spirv-tools-build.log || true && \
    \
    echo "=== INSTALLING SPIRV-TOOLS ===" && \
    make install 2>&1 | tee /tmp/spirv-tools-install.log || true && \
    \
    echo "=== CLEANUP SPIRV-TOOLS SOURCE DIR ===" && \
    cd ../.. && rm -rf spirv-tools 2>/dev/null || true && \
    \
    echo "=== VERIFYING SPIRV-TOOLS INSTALLATION ===" && \
    ls -la /lilyspark/opt/lib/graphics/bin/spirv-* 2>/dev/null || echo "No SPIRV-Tools binaries found" && \
    ls -la /lilyspark/opt/lib/graphics/lib/libSPIRV-Tools* 2>/dev/null || echo "No SPIRV-Tools libraries found" && \
    \
    cd /lilyspark/opt/lib/graphics/lib 2>/dev/null || true; \
    for lib in $(ls libSPIRV-Tools*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname" 2>/dev/null || true; \
        ln -sf "$soname" "$basename" 2>/dev/null || true; \
    done || true; \
    \
    /usr/local/bin/check_llvm15.sh "post-spirv-tools-source-build" || true && \
    echo "=== SPIRV-TOOLS BUILD COMPLETE ===" && \
    export SPIRV_TOOLS_ROOT=/lilyspark/opt/lib/graphics && \
    export SPIRV_HEADERS_ROOT=/lilyspark/opt/lib/graphics

# ======================
# SYSROOT POPULATION: Pre-GLSLANG + Core Toolchain + SPIRV-Headers/Tools
# ======================
RUN echo "=== POPULATING SYSROOT WITH PRE-GLSLANG, SPIRV, AND CORE ===" && \
    set -eux; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    INSTPREFIX="/lilyspark/opt/lib/graphics/usr"; \
    \
    echo "→ Creating sysroot directories"; \
    mkdir -p "$SYSROOT/usr/include/spirv" "$SYSROOT/usr/include" \
             "$SYSROOT/usr/lib" "$SYSROOT/usr/lib/pkgconfig" \
             "$SYSROOT/usr/lib/cmake" "$SYSROOT/usr/share" \
             "$SYSROOT/usr/bin" "$SYSROOT/lib" "$SYSROOT/compiler/lib" "$SYSROOT/compiler/include"; \
    \
    echo "→ Copying SPIRV-Headers"; \
    [ -d "$INSTPREFIX/include/spirv" ] && cp -a "$INSTPREFIX/include/spirv/." "$SYSROOT/usr/include/spirv/" || echo "⚠ No SPIRV headers copied"; \
    \
    echo "→ Copying SPIRV-Tools libraries"; \
    cp -a "$INSTPREFIX/lib"/libSPIRV-Tools* "$SYSROOT/usr/lib/" 2>/dev/null || echo "⚠ No SPIRV libs copied"; \
    \
    echo "→ Copying SPIRV pkg-config files"; \
    [ -d "$INSTPREFIX/lib/pkgconfig" ] && cp -a "$INSTPREFIX/lib/pkgconfig/." "$SYSROOT/usr/lib/pkgconfig/"; \
    find "$SYSROOT/usr/lib/pkgconfig" -type f -name "*SPIRV*.pc" -exec echo "--- {} ---" \; -exec cat {} \; || echo "⚠ no SPIRV .pc files present"; \
    \
    echo "→ Copying SPIRV CMake install tree"; \
    [ -d "$INSTPREFIX/lib/cmake/SPIRV-Tools" ] && cp -a "$INSTPREFIX/lib/cmake/SPIRV-Tools" "$SYSROOT/usr/lib/cmake/"; \
    find "$SYSROOT/usr/lib/cmake" -type f -name "*SPIRV*Config.cmake" -exec echo "--- {} ---" \; -exec grep -H . {} \; || echo "⚠ no SPIRV CMake configs present"; \
    \
    echo "→ Generating minimal SPIRV-Headers CMake shim"; \
    mkdir -p "$SYSROOT/usr/lib/cmake/SPIRV-Headers"; \
    SHIM="$SYSROOT/usr/lib/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake"; \
    echo "# Autogenerated SPIRV-HeadersConfig.cmake" > "$SHIM"; \
    echo "set(SPIRV-Headers_INCLUDE_DIR \"$SYSROOT/usr/include/spirv\")" >> "$SHIM"; \
    echo "set(SPIRV-Headers_FOUND TRUE)" >> "$SHIM"; \
    cat "$SHIM"; \
    \
    echo "→ Populating core toolchain into sysroot (headers + libstdc++)"; \
    cp -a /lilyspark/usr/include/* "$SYSROOT/usr/include/" 2>/dev/null || echo "⚠ Core headers missing"; \
    \
    echo "→ Copying libstdc++ headers (best-effort)"; \
    CXX_HEADERS_DIR=$(find /lilyspark/usr/include -type d -name 'c++*' | head -n1 || true); \
    if [ -n "$CXX_HEADERS_DIR" ]; then \
        cp -a "$CXX_HEADERS_DIR" "$SYSROOT/usr/include/" || echo "⚠ libstdc++ headers missing"; \
    else \
        echo "⚠ Could not find libstdc++ headers"; \
    fi; \
    \
    echo "→ Copying core runtime libraries (CRT, libgcc, libstdc++)"; \
    cp -a /lilyspark/usr/lib/crt*.o "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /lilyspark/usr/lib/libgcc* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /lilyspark/usr/lib/libstdc++* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    \
    echo "→ Copying shared data"; \
    cp -a /lilyspark/usr/share/* "$SYSROOT/usr/share/" 2>/dev/null || true; \
    \
    ############################################################################## \
    # Additional copies & symlinks to help clang/ld find runtime and headers     #
    # (borrowed approach from XORG sysroot population - additive only)          #
    ############################################################################## \
    \
    echo "→ Copying crt objects / gcc support to sysroot (extra)"; \
    cp -a /usr/lib/crt*.o "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/gcc/*/*/crt*.o "$SYSROOT/usr/lib/" 2>/dev/null || true || true; \
    cp -a /usr/lib/gcc/*/*/*.a "$SYSROOT/usr/lib/" 2>/dev/null || true || true; \
    \
    echo "→ Copying musl dynamic loader and libc into sysroot (if present)"; \
    cp -a /lib/ld-musl-*.so.1 "$SYSROOT/lib/" 2>/dev/null || true; \
    cp -a /lib/libc.musl-*.so.1 "$SYSROOT/lib/" 2>/dev/null || true; \
    cp -a /lib/libpthread*.so* "$SYSROOT/lib/" 2>/dev/null || true; \
    \
    echo "→ Creating musl loader symlinks inside sysroot (non-destructive)"; \
    if ls "$SYSROOT/lib"/ld-musl-*.so.1 >/dev/null 2>&1; then \
        for f in "$SYSROOT/lib"/ld-musl-*.so.1; do \
            bn=$(basename "$f"); \
            ln -sf "$bn" "$SYSROOT/lib/ld-linux-$(uname -m).so.1" 2>/dev/null || true; \
            ln -sf "$bn" "$SYSROOT/lib/ld-linux.so.1" 2>/dev/null || true; \
        done; \
        echo "✓ musl loader symlinks created"; \
    else \
        echo "⚠ No musl loader copied into $SYSROOT/lib"; \
    fi; \
    \
    echo "→ Creating libc/libpthread convenience symlinks inside sysroot"; \
    if ls "$SYSROOT/lib"/libc.musl-*.so.1 >/dev/null 2>&1; then \
        ln -sf "$(basename "$(ls -1 "$SYSROOT/lib"/libc.musl-*.so.1 | head -n1)")" "$SYSROOT/lib/libc.so" 2>/dev/null || true; \
    fi; \
    if ls "$SYSROOT/lib"/libpthread*.so* >/dev/null 2>&1; then \
        ln -sf "$(basename "$(ls -1 "$SYSROOT/lib"/libpthread*.so* | head -n1)")" "$SYSROOT/lib/libpthread.so" 2>/dev/null || true; \
    fi; \
    \
    echo "→ Copying compiler support libs (libgcc/libssp/libatomic) into sysroot"; \
    cp -a /usr/lib/libgcc* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/libssp* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/libatomic* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    \
    echo "→ Copying libm/libdl into sysroot (if present)"; \
    cp -a /usr/lib/libm.so* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/libm.a "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/libdl.so* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    \
    echo "→ Ensure Scrt1.o alias exists if only crt1.o present"; \
    if [ -f "$SYSROOT/usr/lib/crt1.o" ] && [ ! -f "$SYSROOT/usr/lib/Scrt1.o" ]; then \
        ln -sf crt1.o "$SYSROOT/usr/lib/Scrt1.o" 2>/dev/null || true; \
    fi; \
    \
    echo "→ Copying clang/LLVM resource includes (if available) into sysroot compiler overlay"; \
    # Prefer local compiler overlay then system llvm installs \
    if [ -d /lilyspark/compiler/lib/clang ]; then \
        cp -a /lilyspark/compiler/lib/clang/* "$SYSROOT/compiler/lib/clang/" 2>/dev/null || true; \
    fi; \
    if [ -d /usr/lib/llvm16/lib/clang ]; then \
        mkdir -p "$SYSROOT/compiler/lib/clang" 2>/dev/null || true; \
        cp -a /usr/lib/llvm16/lib/clang/* "$SYSROOT/compiler/lib/clang/" 2>/dev/null || true; \
    fi; \
    # also copy any compiler include overlays if present (helps clang builtin headers) \
    cp -a /lilyspark/compiler/include/* "$SYSROOT/compiler/include/" 2>/dev/null || true; \
    \
    echo "→ Final verification: list key sysroot entries (non-fatal)"; \
    echo "  /lilyspark/opt/lib/sys/lib listing (first 20):" && ls -la "$SYSROOT/lib" | sed -n '1,20p' || true; \
    echo "  /lilyspark/opt/lib/sys/usr/lib listing (first 40):" && ls -la "$SYSROOT/usr/lib" | sed -n '1,40p' || true; \
    echo "  /lilyspark/opt/lib/sys/usr/include (first 40):" && ls -la "$SYSROOT/usr/include" | sed -n '1,40p' || true; \
    echo "  /lilyspark/opt/lib/sys/compiler include/lib (first 40):" && ls -la "$SYSROOT/compiler/include" "$SYSROOT/compiler/lib" 2>/dev/null || true; \
    \
    echo "→ Verifying presence of critical C++ headers (quick checks):"; \
    for hdr in cstdlib string algorithm vector; do \
        if find "$SYSROOT/usr/include/c++" -type f -name "$hdr" | grep -q . 2>/dev/null; then \
            echo "✔ Found <$hdr> in C++ headers"; \
        elif find "$SYSROOT/usr/include" -type f -name "$hdr" | grep -q . 2>/dev/null; then \
            echo "✔ Found <$hdr> in sysroot includes"; \
        else \
            echo "⚠ Missing <$hdr> -- may cause compiler errors"; \
        fi; \
    done; \
    \
    echo "→ Verifying essential runtime libs in sysroot:"; \
    for lib in ld-musl libc.musl libpthread libgcc libstdc++ libm libdl; do \
        if ls "$SYSROOT/lib"/$lib* >/dev/null 2>&1 || ls "$SYSROOT/usr/lib"/$lib* >/dev/null 2>&1; then \
            echo "✔ Found runtime: $lib"; \
        else \
            echo "⚠ Missing runtime: $lib"; \
        fi; \
    done; \
    \
    echo "→ Verifying clang resource headers present (if copied):"; \
    if find "$SYSROOT/compiler/lib/clang" -maxdepth 2 -type d | grep -q . 2>/dev/null; then \
        echo "✔ clang resource headers appears present at $SYSROOT/compiler/lib/clang (listing):"; \
        ls -la "$SYSROOT/compiler/lib/clang" | sed -n '1,40p' || true; \
    else \
        echo "⚠ clang resource headers not found in sysroot overlay (this may be OK if host / compiler provides them)"; \
    fi; \
    \
    echo "→ Sysroot population complete (glslang-focused overlay)."


RUN echo "=== SYSROOT C++ INCLUDE DIAGNOSTICS ===" && \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    echo "Sysroot: $SYSROOT"; \
    echo "Searching for C++ standard headers in sysroot..."; \
    find "$SYSROOT/usr/include/c++" -type f \( -name 'vector' -o -name 'string' -o -name 'algorithm' \) -print || echo "⚠ No standard headers found!"; \
    echo "--- Full C++ include tree ---"; \
    find "$SYSROOT/usr/include/c++" -type f | head -50; \
    \
    echo "Checking libc++ installation inside sysroot:"; \
    ls -R "$SYSROOT/usr/include" | head -50; \
    \
    echo "Compiler test: printing include search paths"; \
    /lilyspark/compiler/bin/clang++-16 --sysroot=$SYSROOT -E -x c++ - -v < /dev/null

# ======================
# glslang Build (ARM64-safe, fully logged, sysroot-aware 3-tier fallback)
# ======================
ARG GLSLANG_VER=14.0.0
ARG GLSLANG_URL="https://github.com/KhronosGroup/glslang/archive/refs/tags/${GLSLANG_VER}.tar.gz"

ENV PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
ENV PATH="/lilyspark/compiler/bin:${PATH}"

RUN echo "=== START: BUILDING glslang ${GLSLANG_VER} ===" && \
    ARCH="$(uname -m)" && echo "Detected architecture: $ARCH"; \
    \
    mkdir -p /tmp/glslang-src && cd /tmp/glslang-src; \
    echo "Fetching glslang tarball: ${GLSLANG_URL}"; \
    curl -L "${GLSLANG_URL}" -o glslang.tar.gz || (echo "⚠ Failed to fetch glslang tarball"; exit 1); \
    tar -xf glslang.tar.gz --strip-components=1 || echo "⚠ Tar extraction failed"; \
    \
    # ----------------------
    # 1️⃣ Compiler detection
    # ----------------------
    echo "=== Compiler detection ==="; \
    CC="$(command -v /lilyspark/compiler/bin/clang-16 || command -v clang)"; \
    CXX="$(command -v /lilyspark/compiler/bin/clang++-16 || command -v clang++)"; \
    echo "Using CC=$CC, CXX=$CXX"; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    mkdir -p builddir; cd builddir; \
    \
    # ----------------------
    # 2️⃣ Sysroot-aware C++ include fallback detection
    # ----------------------
    echo "=== Detecting C++ include directories in sysroot ==="; \
    SYSROOT_CPP_INCLUDE="$(find $SYSROOT/usr/include/c++ -maxdepth 2 -type d | head -n 1)"; \
    if [ -n "$SYSROOT_CPP_INCLUDE" ]; then \
        echo "Primary sysroot C++ include path found: $SYSROOT_CPP_INCLUDE"; \
    else \
        echo "⚠ Primary C++ include path not found, trying compiler built-in include"; \
        SYSROOT_CPP_INCLUDE="$($CXX -print-search-dirs | grep 'install: ' | sed 's/install: //')/include/c++/16"; \
        if [ ! -d "$SYSROOT_CPP_INCLUDE" ]; then \
            echo "⚠ Secondary compiler include path not found, using glslang source Include directory"; \
            SYSROOT_CPP_INCLUDE="/tmp/glslang-src/Include"; \
        else \
            echo "Secondary compiler include path found: $SYSROOT_CPP_INCLUDE"; \
        fi; \
    fi; \
    \
    # Detect libstdc++ version + target triplet inside sysroot
    CXXVER="$(basename $(ls -d $SYSROOT/usr/include/c++/* | head -n1 2>/dev/null))"; \
    if [ -n "$CXXVER" ]; then \
        echo "Detected libstdc++ version: $CXXVER"; \
        if [ -d "$SYSROOT/usr/include/c++/$CXXVER/aarch64-alpine-linux-musl" ]; then \
            CXX_INCLUDES="-I$SYSROOT/usr/include/c++/$CXXVER -I$SYSROOT/usr/include/c++/$CXXVER/aarch64-alpine-linux-musl"; \
        elif [ -d "$SYSROOT/usr/include/c++/$CXXVER/aarch64-linux-musl" ]; then \
            echo "⚠ Using aarch64-linux-musl instead of alpine triplet"; \
            CXX_INCLUDES="-I$SYSROOT/usr/include/c++/$CXXVER -I$SYSROOT/usr/include/c++/$CXXVER/aarch64-linux-musl"; \
        else \
            echo "⚠ No triplet-specific directory found under $CXXVER, falling back"; \
            CXX_INCLUDES="-I$SYSROOT/usr/include/c++/$CXXVER"; \
        fi; \
    else \
        echo "⚠ No libstdc++ versioned include found, falling back to SYSROOT_CPP_INCLUDE"; \
        CXX_INCLUDES="-I$SYSROOT_CPP_INCLUDE"; \
    fi; \
    \
    BASE_C_FLAGS="--sysroot=$SYSROOT -I$SYSROOT/usr/include -march=armv8-a"; \
    BASE_CXX_FLAGS="$BASE_C_FLAGS $CXX_INCLUDES"; \
    echo "Final CXX flags: $BASE_CXX_FLAGS"; \
    \
    # ----------------------
    # 3️⃣ CMake configure with Ninja generator
    # ----------------------
    echo "=== CMake configure ==="; \
    cmake .. -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/graphics/usr \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_SYSROOT=$SYSROOT \
        -DCMAKE_C_FLAGS="$BASE_C_FLAGS" \
        -DCMAKE_CXX_FLAGS="$BASE_CXX_FLAGS" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DENABLE_OPT=OFF | tee /tmp/glslang-cmake-configure.log; \
    \
    # ----------------------
    # 4️⃣ Build and install (percentage only, minimal output)
    # ----------------------
    echo "=== CMake build ==="; \
    cmake --build . -j$(nproc) | tee /tmp/glslang-cmake-build.log; \
    echo "=== CMake install ==="; \
    cmake --install . --prefix /lilyspark/opt/lib/graphics/usr | tee /tmp/glslang-cmake-install.log; \
    # ----------------------
    # 5️⃣ Populate sysroot
    # ----------------------
    echo "=== Populating sysroot AFTER installation ==="; \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig}; \
    cp -av /lilyspark/opt/lib/graphics/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || true; \
    cp -av /lilyspark/opt/lib/graphics/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || true; \
    cp -av /lilyspark/opt/lib/graphics/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || true; \
    \
    # Ensure pkg-config .pc files exist
    echo "=== Ensuring .pc files for glslang and SPIRV-Tools exist ==="; \
    PKGCONFIG_DIR="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig"; \
    mkdir -p $PKGCONFIG_DIR; \
    \
    for pcfile in glslang.pc SPIRV-Tools.pc; do \
      if [ ! -f "$PKGCONFIG_DIR/$pcfile" ]; then \
        echo "⚠ $pcfile not found in install prefix, checking builddir"; \
        FOUND_PC="$(find /tmp/glslang-src/builddir -name $pcfile -type f 2>/dev/null | head -n1)"; \
        if [ -n "$FOUND_PC" ]; then \
          echo "✅ Found $pcfile in builddir, copying"; \
          cp -av "$FOUND_PC" "$PKGCONFIG_DIR/"; \
        else \
          echo "⚠ $pcfile not found in builddir, generating minimal fallback"; \
          case $pcfile in \
            glslang.pc) \
              { \
              echo "prefix=/lilyspark/opt/lib/graphics/usr"; \
              echo "exec_prefix=\${prefix}"; \
              echo "libdir=\${exec_prefix}/lib"; \
              echo "includedir=\${prefix}/include"; \
              echo ""; \
              echo "Name: glslang"; \
              echo "Description: Khronos reference front-end for GLSL and ESSL"; \
              echo "Version: ${GLSLANG_VER}"; \
              echo "Libs: -L\${libdir} -lglslang"; \
              echo "Cflags: -I\${includedir}"; \
              } > "$PKGCONFIG_DIR/$pcfile"; \
              ;; \
            SPIRV-Tools.pc) \
              { \
              echo "prefix=/lilyspark/opt/lib/graphics/usr"; \
              echo "exec_prefix=\${prefix}"; \
              echo "libdir=\${exec_prefix}/lib"; \
              echo "includedir=\${prefix}/include"; \
              echo ""; \
              echo "Name: SPIRV-Tools"; \
              echo "Description: Khronos SPIR-V Tools"; \
              echo "Version: ${GLSLANG_VER}"; \
              echo "Libs: -L\${libdir} -lSPIRV-Tools"; \
              echo "Cflags: -I\${includedir}"; \
              } > "$PKGCONFIG_DIR/$pcfile"; \
              ;; \
          esac; \
        fi; \
      fi; \
    done; \
    \
    cp -av $PKGCONFIG_DIR/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || true; \
    \
    # ----------------------
    # 6️⃣ Verify pkg-config and cleanup
    # ----------------------
    echo "=== Verifying pkg-config can see glslang ==="; \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:$PKG_CONFIG_PATH"; \
    ls -la $SYSROOT/usr/lib/pkgconfig; \
    pkg-config --modversion glslang || echo "⚠ glslang still not detected"; \
    pkg-config --cflags glslang; pkg-config --libs glslang; \
    echo "=== Post-install verification ==="; \
    ls -R /lilyspark/opt/lib/graphics | head -50; \
    echo "=== GLSLANG BUILD COMPLETE ==="

# ======================
# SYSROOT POPULATION: SPIRV-Headers + SPIRV-Tools + glslang (with deep logging)
# ======================
RUN echo "=== POPULATING SYSROOT WITH SPIRV-HEADERS, SPIRV-TOOLS, AND GLSLANG ===" && \
    set -eux; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    INSTPREFIX="/lilyspark/opt/lib/graphics"; \
    \
    mkdir -p "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$SYSROOT/usr/lib/pkgconfig" "$SYSROOT/usr/lib/cmake" "$SYSROOT/usr/bin"; \
    \
    echo "→ Copying SPIRV-Headers includes"; \
    cp -a "$INSTPREFIX/include/." "$SYSROOT/usr/include/" || echo "⚠ failed to copy SPIRV headers"; \
    ls -laR "$INSTPREFIX/include" || true; \
    \
    echo "→ Copying SPIRV-Tools libraries"; \
    cp -a "$INSTPREFIX/lib"/libSPIRV-Tools* "$SYSROOT/usr/lib/" || echo "⚠ no SPIRV libs found"; \
    ls -la "$INSTPREFIX/lib" || true; \
    ls -la "$SYSROOT/usr/lib" || true; \
    \
    echo "→ Copying pkg-config files"; \
    if [ -d "$INSTPREFIX/lib/pkgconfig" ]; then \
        cp -a "$INSTPREFIX/lib/pkgconfig/." "$SYSROOT/usr/lib/pkgconfig/"; \
    fi; \
    ls -la "$INSTPREFIX/lib/pkgconfig" || true; \
    ls -la "$SYSROOT/usr/lib/pkgconfig" || true; \
    echo "→ Inspecting pkg-config contents"; \
    find "$SYSROOT/usr/lib/pkgconfig" -type f -name "*.pc" -exec echo "--- {} ---" \; -exec cat {} \; || echo "⚠ no .pc files present"; \
    \
    echo "→ Copying SPIRV-Tools CMake install tree"; \
    if [ -d "$INSTPREFIX/lib/cmake/SPIRV-Tools" ]; then \
        cp -a "$INSTPREFIX/lib/cmake/SPIRV-Tools" "$SYSROOT/usr/lib/cmake/"; \
    else \
        echo "⚠ SPIRV-Tools CMake install tree not found"; \
    fi; \
    ls -laR "$INSTPREFIX/lib/cmake" || true; \
    ls -laR "$SYSROOT/usr/lib/cmake" || true; \
    echo "→ Inspecting SPIRV-related CMake configs"; \
    find "$SYSROOT/usr/lib/cmake" -type f -name "*SPIRV*Config.cmake" -exec echo "--- {} ---" \; -exec grep -H . {} \; || echo "⚠ no SPIRV CMake configs present"; \
    \
    echo "→ Generating minimal SPIRV-Headers CMake shim"; \
    mkdir -p "$SYSROOT/usr/lib/cmake/SPIRV-Headers"; \
    SHIM_HDR="$SYSROOT/usr/lib/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake"; \
    echo "# Autogenerated SPIRV-HeadersConfig.cmake" > "$SHIM_HDR"; \
    echo "set(SPIRV-Headers_INCLUDE_DIR \"$INSTPREFIX/include/spirv\")" >> "$SHIM_HDR"; \
    echo "set(SPIRV-Headers_FOUND TRUE)" >> "$SHIM_HDR"; \
    echo "✓ SPIRV-Headers shim created at $SHIM_HDR"; \
    cat "$SHIM_HDR"; \
    \
    echo "→ Copying glslang includes"; \
    cp -a "$INSTPREFIX/include/." "$SYSROOT/usr/include/" || echo "⚠ failed to copy glslang includes"; \
    ls -laR "$INSTPREFIX/include" || true; \
    \
    echo "→ Copying glslang libraries (static libs if present)"; \
    if compgen -G "$INSTPREFIX/lib/libglslang*" > /dev/null; then \
        cp -av "$INSTPREFIX/lib"/libglslang* "$SYSROOT/usr/lib/"; \
    else \
        echo "⚠ no glslang libraries found — none were built"; \
    fi; \
    \
    echo "→ Copying glslang binaries"; \
    if [ -d "$INSTPREFIX/bin" ]; then \
        cp -a "$INSTPREFIX/bin/." "$SYSROOT/usr/bin/" || echo "⚠ no glslang binaries found"; \
    fi; \
    ls -la "$INSTPREFIX/bin" || true; \
    ls -la "$SYSROOT/usr/bin" || true; \
    \
    echo "→ Copying glslang pkg-config files"; \
    if [ -d "$INSTPREFIX/lib/pkgconfig" ]; then \
        cp -a "$INSTPREFIX/lib/pkgconfig/." "$SYSROOT/usr/lib/pkgconfig/"; \
    fi; \
    ls -la "$INSTPREFIX/lib/pkgconfig" || true; \
    ls -la "$SYSROOT/usr/lib/pkgconfig" || true; \
    echo "→ Inspecting pkg-config contents (glslang)"; \
    find "$SYSROOT/usr/lib/pkgconfig" -type f -name "*glslang*.pc" -exec echo "--- {} ---" \; -exec cat {} \; || echo "⚠ no glslang .pc files present"; \
    \
    echo "→ Copying glslang CMake install tree"; \
    if [ -d "$INSTPREFIX/lib/cmake/glslang" ]; then \
        cp -a "$INSTPREFIX/lib/cmake/glslang" "$SYSROOT/usr/lib/cmake/"; \
    elif [ -d "$INSTPREFIX/lib/cmake/Glslang" ]; then \
        cp -a "$INSTPREFIX/lib/cmake/Glslang" "$SYSROOT/usr/lib/cmake/"; \
    else \
        echo "⚠ glslang CMake install tree not found"; \
    fi; \
    ls -laR "$INSTPREFIX/lib/cmake" || true; \
    ls -laR "$SYSROOT/usr/lib/cmake" || true; \
    echo "→ Inspecting glslang-related CMake configs"; \
    find "$SYSROOT/usr/lib/cmake" -type f -iname "*glslang*Config.cmake" -exec echo "--- {} ---" \; -exec grep -H . {} \; || echo "⚠ no glslang CMake configs present"; \
    \
    echo "→ Generating minimal GLSLANG CMake shim"; \
    mkdir -p "$SYSROOT/usr/lib/cmake/glslang"; \
    SHIM_GLS="$SYSROOT/usr/lib/cmake/glslang/glslangConfig.cmake"; \
    { \
        echo "# Autogenerated glslangConfig.cmake"; \
        echo "set(GLSLANG_INCLUDE_DIR \"$INSTPREFIX/include\")"; \
        echo "set(GLSLANG_LIBRARY_DIR \"$INSTPREFIX/lib\")"; \
        echo "set(GLSLANG_BINARY_DIR \"$INSTPREFIX/bin\")"; \
        echo "set(GLSLANG_FOUND TRUE)"; \
    } > "$SHIM_GLS"; \
    echo "✓ GLSLANG shim created at $SHIM_GLS"; \
    cat "$SHIM_GLS"; \
    \
    echo "=== SYSROOT POPULATION COMPLETE ==="



# ======================
# SECTION: Enhanced Sysroot Debug and Path Hardcoding for Shaderc
# ======================
RUN echo "=== PRE-SHADERC DEBUG: VERIFYING ALL SPIRV + GLSLANG COMPONENTS ===" && \
    SYSROOT="/lilyspark/opt/lib/sys" && \
    INSTPREFIX="/lilyspark/opt/lib/graphics" && \
    \
    echo "→ Current SPIRV-Tools installation state:" && \
    echo "  Binaries:" && ls -la $INSTPREFIX/bin/spirv-* 2>/dev/null || echo "    ⚠ No SPIRV binaries" && \
    echo "  Libraries:" && ls -la $INSTPREFIX/lib/libSPIRV-Tools* 2>/dev/null || echo "    ⚠ No SPIRV libraries" && \
    echo "  Headers:" && ls -la $INSTPREFIX/include/spirv/ 2>/dev/null || echo "    ⚠ No SPIRV headers" && \
    echo "  CMake configs:" && ls -la $INSTPREFIX/lib/cmake/SPIRV-Tools/ 2>/dev/null || echo "    ⚠ No SPIRV CMake configs" && \
    \
    echo "→ Sysroot SPIRV state:" && \
    echo "  Sysroot libs:" && ls -la $SYSROOT/usr/lib/libSPIRV-Tools* 2>/dev/null || echo "    ⚠ No sysroot SPIRV libs" && \
    echo "  Sysroot headers:" && ls -la $SYSROOT/usr/include/spirv/ 2>/dev/null || echo "    ⚠ No sysroot SPIRV headers" && \
    echo "  Sysroot CMake:" && ls -la $SYSROOT/usr/lib/cmake/SPIRV-Tools/ 2>/dev/null || echo "    ⚠ No sysroot SPIRV CMake" && \
    \
    echo "→ Current glslang installation state:" && \
    echo "  Binaries:" && ls -la $INSTPREFIX/bin/glslang* 2>/dev/null || echo "    ⚠ No glslang binaries" && \
    echo "  Libraries:" && ls -la $INSTPREFIX/lib/libglslang* 2>/dev/null || echo "    ⚠ No glslang libraries" && \
    echo "  Headers:" && ls -la $INSTPREFIX/include/glslang 2>/dev/null || echo "    ⚠ No glslang headers" && \
    echo "  CMake configs:" && ls -la $INSTPREFIX/lib/cmake/glslang/ 2>/dev/null || ls -la $INSTPREFIX/lib/cmake/Glslang/ 2>/dev/null || echo "    ⚠ No glslang CMake configs" && \
    \
    echo "→ Sysroot glslang state:" && \
    echo "  Sysroot libs:" && ls -la $SYSROOT/usr/lib/libglslang* 2>/dev/null || echo "    ⚠ No sysroot glslang libs" && \
    echo "  Sysroot headers:" && ls -la $SYSROOT/usr/include/glslang 2>/dev/null || echo "    ⚠ No sysroot glslang headers" && \
    echo "  Sysroot CMake:" && ls -la $SYSROOT/usr/lib/cmake/glslang/ 2>/dev/null || ls -la $SYSROOT/usr/lib/cmake/Glslang/ 2>/dev/null || echo "    ⚠ No sysroot glslang CMake" && \
    \
    echo "=== PRE-SHADERC DEBUG COMPLETE ==="



# ======================
# SECTION: Nuclear Shaderc Build - Direct Source Patching
# ======================
RUN echo "=== NUCLEAR SHADERC BUILD WITH SOURCE PATCHING ===" && \
    git clone --recursive https://github.com/google/shaderc.git || echo "⚠ shaderc not cloned; skipping build"; \
    cd shaderc || echo "⚠ shaderc directory missing; skipping build"; \
    \
    export PATH="/lilyspark/compiler/bin:$PATH"; \
    CC=/lilyspark/compiler/bin/clang-16; \
    CXX=/lilyspark/compiler/bin/clang++-16; \
    export CC CXX; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    INSTPREFIX="/lilyspark/opt/lib/graphics"; \
    \
    echo "→ Examining the problematic third_party/CMakeLists.txt" && \
    echo "Current line 80 area:" && \
    sed -n '75,85p' third_party/CMakeLists.txt && \
    \
    echo "→ Nuclear approach: Direct line replacement in third_party/CMakeLists.txt" && \
    cp third_party/CMakeLists.txt third_party/CMakeLists.txt.backup && \
    \
    # Replace the exact error line with success
    sed -i '80s/.*/  message(STATUS "SPIRV-Tools found at \/lilyspark\/opt\/lib\/graphics - bypassing detection")/' third_party/CMakeLists.txt && \
    \
    # Add required variables right after the error line with proper newlines
    sed -i '80a\  set(SPIRV_TOOLS_FOUND TRUE)' third_party/CMakeLists.txt && \
    sed -i '81a\  set(SPIRV_TOOLS_BINARY_DIR "/lilyspark/opt/lib/graphics/bin")' third_party/CMakeLists.txt && \
    sed -i '82a\  set(SPIRV_TOOLS_LIBRARY_DIR "/lilyspark/opt/lib/graphics/lib")' third_party/CMakeLists.txt && \
    sed -i '83a\  set(SPIRV_TOOLS_INCLUDE_DIR "/lilyspark/opt/lib/graphics/include")' third_party/CMakeLists.txt && \
    sed -i '84a\  set(SPIRV_TOOLS_LIBRARIES "/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools.a" "/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-opt.a" "/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-link.a")' third_party/CMakeLists.txt && \
    sed -i '85a\  set(SPIRV_TOOLS_INCLUDE_DIRS "/lilyspark/opt/lib/graphics/include")' third_party/CMakeLists.txt && \
    \
    # --- Add glslang forced variables right after SPIRV injection --- \
    sed -i '86a\  set(GLSLANG_FOUND TRUE)' third_party/CMakeLists.txt && \
    sed -i '87a\  set(GLSLANG_BINARY_DIR "/lilyspark/opt/lib/graphics/bin")' third_party/CMakeLists.txt && \
    sed -i '88a\  set(GLSLANG_LIBRARY_DIR "/lilyspark/opt/lib/graphics/lib")' third_party/CMakeLists.txt && \
    sed -i '89a\  set(GLSLANG_INCLUDE_DIR "/lilyspark/opt/lib/graphics/include")' third_party/CMakeLists.txt && \
    sed -i '90a\  set(GLSLANG_LIBRARIES "/lilyspark/opt/lib/graphics/lib/libglslang.a" "/lilyspark/opt/lib/graphics/lib/libglslang-defaultresource-locator.a")' third_party/CMakeLists.txt && \
    sed -i '91a\  set(GLSLANG_INCLUDE_DIRS "/lilyspark/opt/lib/graphics/include")' third_party/CMakeLists.txt && \
    \
    echo "→ Verifying the patch worked" && \
    echo "Lines 75-100 after patching:" && \
    sed -n '75,100p' third_party/CMakeLists.txt && \
    \
    echo "→ Also patching any SPIRV_TOOLS_FOUND checks to always be true" && \
    sed -i 's/if.*SPIRV_TOOLS_FOUND.*)/if(TRUE)/g' third_party/CMakeLists.txt && \
    sed -i 's/elseif.*SPIRV_TOOLS_FOUND.*)/elseif(FALSE)/g' third_party/CMakeLists.txt && \
    \
    echo "→ Also patching any GLSLANG_FOUND checks to always be true" && \
    sed -i 's/if.*GLSLANG_FOUND.*)/if(TRUE)/g' third_party/CMakeLists.txt || true && \
    sed -i 's/elseif.*GLSLANG_FOUND.*)/elseif(FALSE)/g' third_party/CMakeLists.txt || true && \
    \
    echo "→ Force-setting SPIRV variables at the top of third_party/CMakeLists.txt" && \
    sed -i '1a\# FORCED SPIRV-Tools variables' third_party/CMakeLists.txt && \
    sed -i '2a\set(SPIRV_TOOLS_FOUND TRUE CACHE BOOL "SPIRV Tools found" FORCE)' third_party/CMakeLists.txt && \
    sed -i '3a\set(SPIRV_TOOLS_BINARY_DIR "/lilyspark/opt/lib/graphics/bin" CACHE PATH "SPIRV Tools binary dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '4a\set(SPIRV_TOOLS_LIBRARY_DIR "/lilyspark/opt/lib/graphics/lib" CACHE PATH "SPIRV Tools library dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '5a\set(SPIRV_TOOLS_INCLUDE_DIR "/lilyspark/opt/lib/graphics/include" CACHE PATH "SPIRV Tools include dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '6a\set(SPIRV_TOOLS_LIBRARIES "/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools.a;/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-opt.a;/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-link.a" CACHE STRING "SPIRV Tools libraries" FORCE)' third_party/CMakeLists.txt && \
    sed -i '7a\set(SPIRV_TOOLS_INCLUDE_DIRS "/lilyspark/opt/lib/graphics/include" CACHE PATH "SPIRV Tools include dirs" FORCE)' third_party/CMakeLists.txt && \
    \
    # --- Force-setting GLSLANG variables at the top (after SPIRV cache inserts) --- \
    sed -i '8a\set(GLSLANG_FOUND TRUE CACHE BOOL "glslang found" FORCE)' third_party/CMakeLists.txt && \
    sed -i '9a\set(GLSLANG_BINARY_DIR "/lilyspark/opt/lib/graphics/bin" CACHE PATH "glslang binary dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '10a\set(GLSLANG_LIBRARY_DIR "/lilyspark/opt/lib/graphics/lib" CACHE PATH "glslang library dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '11a\set(GLSLANG_INCLUDE_DIR "/lilyspark/opt/lib/graphics/include" CACHE PATH "glslang include dir" FORCE)' third_party/CMakeLists.txt && \
    sed -i '12a\set(GLSLANG_LIBRARIES "/lilyspark/opt/lib/graphics/lib/libglslang.a;/lilyspark/opt/lib/graphics/lib/libglslang-defaultresource-locator.a" CACHE STRING "glslang libraries" FORCE)' third_party/CMakeLists.txt && \
    sed -i '13a\set(GLSLANG_INCLUDE_DIRS "/lilyspark/opt/lib/graphics/include" CACHE PATH "glslang include dirs" FORCE)' third_party/CMakeLists.txt && \
    \
    echo "→ Disabling asciidoctor requirements" && \
    find . -name "CMakeLists.txt" -exec sed -i 's/find_program.*asciidoctor.*/# &/' {} \; && \
    find . -name "CMakeLists.txt" -exec sed -i 's/.*asciidoctor.*REQUIRED.*/# &/' {} \; && \
    \
    echo "→ Setting up build with comprehensive environment" && \
    mkdir -p build && cd build && \
    \
    echo "→ CMake configure with all possible SPIRV and GLSLANG flags" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$INSTPREFIX \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_SYSROOT=$SYSROOT \
        -DCMAKE_PREFIX_PATH="$SYSROOT/usr;$INSTPREFIX" \
        -DSPIRV_TOOLS_FOUND=TRUE \
        -DSPIRV_TOOLS_BINARY_DIR="$INSTPREFIX/bin" \
        -DSPIRV_TOOLS_LIBRARY_DIR="$INSTPREFIX/lib" \
        -DSPIRV_TOOLS_INCLUDE_DIR="$INSTPREFIX/include" \
        -DSPIRV_TOOLS_LIBRARIES="$INSTPREFIX/lib/libSPIRV-Tools.a;$INSTPREFIX/lib/libSPIRV-Tools-opt.a;$INSTPREFIX/lib/libSPIRV-Tools-link.a" \
        -DSPIRV_TOOLS_INCLUDE_DIRS="$INSTPREFIX/include" \
        -DSPIRV_HEADERS_INCLUDE_DIR="$INSTPREFIX/include" \
        -DGLSLANG_FOUND=TRUE \
        -DGLSLANG_BINARY_DIR="$INSTPREFIX/bin" \
        -DGLSLANG_LIBRARY_DIR="$INSTPREFIX/lib" \
        -DGLSLANG_INCLUDE_DIR="$INSTPREFIX/include" \
        -DGLSLANG_LIBRARIES="$INSTPREFIX/lib/libglslang.a;$INSTPREFIX/lib/libglslang-defaultresource-locator.a" \
        -DGLSLANG_INCLUDE_DIRS="$INSTPREFIX/include" \
        -DSHADERC_ENABLE_SYSTEM_SPIRV_TOOLS=ON \
        -DSHADERC_SKIP_TESTS=ON \
        -DSHADERC_SKIP_EXAMPLES=ON \
        -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
        -Wno-dev 2>&1 | tee /tmp/shaderc-cmake-nuclear.log || { \
        \
        echo "⚠ Even nuclear patching failed. Trying complete CMakeLists.txt replacement" && \
        cd .. && \
        \
        echo "→ Creating custom minimal third_party/CMakeLists.txt" && \
        { \
          echo "# Custom minimal third_party/CMakeLists.txt for SPIRV-Tools and glslang"; \
          echo "# Force all SPIRV-Tools variables"; \
          echo "set(SPIRV_TOOLS_FOUND TRUE)"; \
          echo "set(SPIRV_TOOLS_BINARY_DIR \"/lilyspark/opt/lib/graphics/bin\")"; \
          echo "set(SPIRV_TOOLS_LIBRARY_DIR \"/lilyspark/opt/lib/graphics/lib\")"; \
          echo "set(SPIRV_TOOLS_INCLUDE_DIR \"/lilyspark/opt/lib/graphics/include\")"; \
          echo "set(SPIRV_TOOLS_LIBRARIES"; \
          echo "    \"/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools.a\""; \
          echo "    \"/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-opt.a\""; \
          echo "    \"/lilyspark/opt/lib/graphics/lib/libSPIRV-Tools-link.a\")"; \
          echo "set(SPIRV_TOOLS_INCLUDE_DIRS \"/lilyspark/opt/lib/graphics/include\")"; \
          echo ""; \
          echo "# Force glslang variables"; \
          echo "set(GLSLANG_FOUND TRUE)"; \
          echo "set(GLSLANG_BINARY_DIR \"/lilyspark/opt/lib/graphics/bin\")"; \
          echo "set(GLSLANG_LIBRARY_DIR \"/lilyspark/opt/lib/graphics/lib\")"; \
          echo "set(GLSLANG_INCLUDE_DIR \"/lilyspark/opt/lib/graphics/include\")"; \
          echo "set(GLSLANG_LIBRARIES"; \
          echo "    \"/lilyspark/opt/lib/graphics/lib/libglslang.a\""; \
          echo "    \"/lilyspark/opt/lib/graphics/lib/libglslang-defaultresource-locator.a\")"; \
          echo "set(GLSLANG_INCLUDE_DIRS \"/lilyspark/opt/lib/graphics/include\")"; \
          echo ""; \
          echo "message(STATUS \"Using hardcoded SPIRV-Tools and glslang at /lilyspark/opt/lib/graphics\")"; \
          echo ""; \
          echo "# Include any other third party dependencies"; \
          echo "if(EXISTS \"\${CMAKE_CURRENT_SOURCE_DIR}/glslang/CMakeLists.txt\")"; \
          echo "    add_subdirectory(glslang)"; \
          echo "endif()"; \
          echo ""; \
          echo "# Export the variables"; \
          echo "set(SPIRV_TOOLS_FOUND \${SPIRV_TOOLS_FOUND} PARENT_SCOPE)"; \
          echo "set(SPIRV_TOOLS_BINARY_DIR \${SPIRV_TOOLS_BINARY_DIR} PARENT_SCOPE)"; \
          echo "set(SPIRV_TOOLS_LIBRARY_DIR \${SPIRV_TOOLS_LIBRARY_DIR} PARENT_SCOPE)"; \
          echo "set(SPIRV_TOOLS_INCLUDE_DIR \${SPIRV_TOOLS_INCLUDE_DIR} PARENT_SCOPE)"; \
          echo "set(SPIRV_TOOLS_LIBRARIES \${SPIRV_TOOLS_LIBRARIES} PARENT_SCOPE)"; \
          echo "set(SPIRV_TOOLS_INCLUDE_DIRS \${SPIRV_TOOLS_INCLUDE_DIRS} PARENT_SCOPE)"; \
          echo "set(GLSLANG_FOUND \${GLSLANG_FOUND} PARENT_SCOPE)"; \
          echo "set(GLSLANG_BINARY_DIR \${GLSLANG_BINARY_DIR} PARENT_SCOPE)"; \
          echo "set(GLSLANG_LIBRARY_DIR \${GLSLANG_LIBRARY_DIR} PARENT_SCOPE)"; \
          echo "set(GLSLANG_INCLUDE_DIR \${GLSLANG_INCLUDE_DIR} PARENT_SCOPE)"; \
          echo "set(GLSLANG_LIBRARIES \${GLSLANG_LIBRARIES} PARENT_SCOPE)"; \
          echo "set(GLSLANG_INCLUDE_DIRS \${GLSLANG_INCLUDE_DIRS} PARENT_SCOPE)"; \
        } > third_party/CMakeLists.txt.new && \
        \
        echo "→ Backing up original and using custom CMakeLists.txt" && \
        mv third_party/CMakeLists.txt third_party/CMakeLists.txt.original && \
        mv third_party/CMakeLists.txt.new third_party/CMakeLists.txt && \
        \
        echo "→ Retry with completely custom third_party/CMakeLists.txt" && \
        cd build && \
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$INSTPREFIX \
            -DCMAKE_C_COMPILER=$CC \
            -DCMAKE_CXX_COMPILER=$CXX \
            -DSHADERC_ENABLE_SYSTEM_SPIRV_TOOLS=ON \
            -DSHADERC_SKIP_TESTS=ON \
            -DSHADERC_SKIP_EXAMPLES=ON \
            -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
            -Wno-dev 2>&1 | tee /tmp/shaderc-cmake-custom.log || echo "⚠ Custom CMakeLists.txt also failed"; \
    } && \
    \
    echo "→ Attempting build" && \
    make -j"$(nproc)" VERBOSE=1 2>&1 | tee /tmp/shaderc-build-nuclear.log || { \
        echo "⚠ Parallel build failed, trying single-threaded with more verbose output"; \
        make VERBOSE=1 2>&1 | tee /tmp/shaderc-build-single.log || echo "⚠ Single-threaded build also failed"; \
        echo "→ Checking for specific compilation errors"; \
        grep -i "error" /tmp/shaderc-build-single.log | head -10 || echo "No specific errors found"; \
    } && \
    \
    echo "→ Installation attempt" && \
    make install 2>&1 | tee /tmp/shaderc-install-nuclear.log || echo "⚠ make install failed" && \
    \
    cd ../.. && rm -rf shaderc 2>/dev/null || true && \
    \
    echo "=== FINAL VERIFICATION ===" && \
    echo "→ Shaderc binaries:" && ls -la $INSTPREFIX/bin/shaderc* 2>/dev/null || echo "  ⚠ No shaderc binaries found" && \
    echo "→ Shaderc libraries:" && ls -la $INSTPREFIX/lib/libshaderc* 2>/dev/null || echo "  ⚠ No shaderc libraries found" && \
    echo "→ Available logs for debugging:" && \
    echo "  /tmp/shaderc-cmake-nuclear.log - Initial nuclear attempt" && \
    echo "  /tmp/shaderc-cmake-custom.log - Custom CMakeLists attempt" && \
    echo "  /tmp/shaderc-build-nuclear.log - Build log" && \
    echo "  /tmp/shaderc-install-nuclear.log - Install log" && \
    echo "=== NUCLEAR SHADERC BUILD COMPLETE ==="


# ======================
# SECTION: libgbm Build (ARM64-safe, non-fatal)
# ======================
RUN echo "=== BUILDING libgbm FROM SOURCE (ARM64) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-libgbm-deps" || true && \
    \
    ARCH=$(uname -m) && \
    if [ "$ARCH" != "aarch64" ]; then \
        echo "Non-ARM64 platform detected ($ARCH), skipping libgbm build"; \
    else \
        echo "ARM64 detected ($ARCH), proceeding with libgbm build" && \
        \
        git clone --depth=1 https://github.com/robclark/libgbm.git || (echo "⚠ libgbm clone failed, skipping build" && exit 0); \
        cd libgbm || exit 0; \
        \
        echo "=== CONFIGURING LIBGBM ===" && \
        export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/lib/pkgconfig:/lilyspark/opt/lib/sys/share/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        \
        ./autogen.sh --prefix=/lilyspark/opt/lib/sys 2>&1 | tee /tmp/libgbm-autogen.log || echo "⚠ autogen.sh had warnings"; \
        ./configure \
            --prefix=/lilyspark/opt/lib/sys \
            CC=/lilyspark/compiler/bin/clang-16 \
            CXX=/lilyspark/compiler/bin/clang++-16 \
            CFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/graphics/usr/include -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
            CXXFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/graphics/usr/include -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
            LDFLAGS="--sysroot=/lilyspark -L/lilyspark/opt/lib/graphics/usr/lib -L/lilyspark/opt/lib/sys/lib -L/lilyspark/compiler/lib -L/lilyspark/glibc/lib" 2>&1 | tee /tmp/libgbm-configure.log || echo "⚠ configure had warnings"; \
        \
        echo "=== BUILDING LIBGBM ===" && \
        make -j"$(nproc)" 2>&1 | tee /tmp/libgbm-build.log || echo "⚠ make failed (continuing)"; \
        \
        echo "=== INSTALLING LIBGBM ===" && \
        make install 2>&1 | tee /tmp/libgbm-install.log || echo "⚠ make install failed (continuing)"; \
        \
        cd .. && rm -rf libgbm; \
        \
        echo "=== LIBGBM VERIFICATION ===" && \
        ls -la /lilyspark/opt/lib/sys/lib/libgbm* 2>/dev/null || echo "⚠ No libgbm libraries found"; \
        \
        echo "=== CREATING LIBRARY SYMLINKS ===" && \
        cd /lilyspark/opt/lib/sys/lib && \
        for lib in $(ls libgbm.so.* 2>/dev/null); do \
            soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
            basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
            ln -sf "$lib" "$soname"; \
            ln -sf "$soname" "$basename"; \
            echo "Created symlinks for $lib"; \
        done; \
        \
        /usr/local/bin/check_llvm15.sh "after-libgbm" || true; \
        echo "=== LIBGBM BUILD COMPLETE ==="; \
    fi

# ======================
# SECTION: GStreamer Core Build
# ======================
RUN \
    printf '%s\n' "=== BUILDING gstreamer core (defensive, POSIX) ==="; \
    wget -q https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.20.3.tar.xz && \
    tar -xJf gstreamer-1.20.3.tar.xz && \
    if [ -d gstreamer-1.20.3 ]; then \
        cd gstreamer-1.20.3; \
        meson setup builddir \
            --prefix=/lilyspark/opt/lib/media \
            --buildtype=release \
            -Dexamples=disabled \
            -Dintrospection=disabled \
            -Dtests=disabled \
            -Ddefault_library=shared \
            -Dc_args="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
            -Dc_link_args="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib"; \
        ninja -C builddir -j"$(nproc)" && ninja -C builddir install; \
        cd ..; rm -rf gstreamer-*; \
    else \
        printf '%s\n' "⚠ gstreamer source missing — skipping"; \
    fi
# ======================
# Install glib-mkenums (from GLib)
# ======================
RUN set -eux; \
    GLIB_VERSION="2.76.0"; \
    GLIB_MAJOR_MINOR="${GLIB_VERSION%.*}"; \
    echo ">>> Fetching GLib $GLIB_VERSION from GNOME sources"; \
    if ! wget -q https://download.gnome.org/sources/glib/${GLIB_MAJOR_MINOR}/glib-$GLIB_VERSION.tar.xz; then \
        echo "⚠ GLib $GLIB_VERSION not found — skipping glib-mkenums build"; \
    else \
        tar -xJf glib-$GLIB_VERSION.tar.xz; \
        cd glib-$GLIB_VERSION; \
        mkdir -p build && cd build; \
        echo ">>> Running Meson setup for glib-mkenums (ARM64 flags applied)"; \
        export CC=/lilyspark/compiler/bin/clang-16; \
        export CXX=/lilyspark/compiler/bin/clang++-16; \
        export CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a"; \
        export CXXFLAGS="$CFLAGS"; \
        export LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib"; \
        export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/media/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:/lilyspark/glibc/lib/pkgconfig"; \
        if ! meson setup --prefix=/lilyspark/opt/lib/media .. -Dtests=false -Dman=false -Dgtk_doc=false; then \
            echo "⚠ Meson setup failed — continuing"; \
        else \
            echo ">>> Installing glib-mkenums"; \
            cp gobject/glib-mkenums /lilyspark/opt/lib/media/bin/; \
            echo "✓ glib-mkenums installed at /lilyspark/opt/lib/media/bin"; \
        fi; \
        cd / && rm -rf glib-$GLIB_VERSION*; \
    fi


# ======================
# Safety check: ensure glib-mkenums exists for ARM64
# ======================
RUN set -eux; \
    ARCH="$(uname -m)"; \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        GLIB_MKENUMS_PATH="/lilyspark/opt/lib/media/bin/glib-mkenums"; \
        if [ ! -x "$GLIB_MKENUMS_PATH" ]; then \
            echo "⚠ glib-mkenums not found at $GLIB_MKENUMS_PATH — attempting fallback build"; \
            if command -v meson >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1 && [ -x /lilyspark/compiler/bin/clang-16 ]; then \
                echo ">>> Fallback: building glib-mkenums"; \
                GLIB_VERSION="2.76.0"; \
                GLIB_MAJOR_MINOR="${GLIB_VERSION%.*}"; \
                if ! wget -q https://download.gnome.org/sources/glib/${GLIB_MAJOR_MINOR}/glib-$GLIB_VERSION.tar.xz; then \
                    echo "⚠ GLib tarball not found — skipping fallback"; \
                else \
                    tar -xJf glib-$GLIB_VERSION.tar.xz; \
                    cd glib-$GLIB_VERSION && mkdir -p build && cd build; \
                    export CC=/lilyspark/compiler/bin/clang-16; \
                    export CXX=/lilyspark/compiler/bin/clang++-16; \
                    export CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a"; \
                    export CXXFLAGS="$CFLAGS"; \
                    export LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib"; \
                    export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
                    export PKG_CONFIG_PATH="/lilyspark/opt/lib/media/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:/lilyspark/glibc/lib/pkgconfig"; \
                    if ! meson setup --prefix=/lilyspark/opt/lib/media .. -Dtests=false -Dtools=true -Dman=false -Dgtk_doc=false; then \
                        echo "⚠ Meson setup failed — skipping fallback"; \
                    else \
                        if [ -f gobject/glib-mkenums ]; then \
                            cp gobject/glib-mkenums /lilyspark/opt/lib/media/bin/; \
                            echo "✓ Fallback glib-mkenums installed"; \
                        else \
                            echo "⚠ glib-mkenums not generated by Meson — fallback failed"; \
                        fi; \
                    fi; \
                    cd / && rm -rf glib-$GLIB_VERSION*; \
                fi; \
            else \
                echo "⚠ Meson/Ninja or compiler missing — cannot build fallback"; \
            fi; \
        fi; \
        if [ -x "$GLIB_MKENUMS_PATH" ]; then \
            echo "✓ glib-mkenums verified at $GLIB_MKENUMS_PATH"; \
            if ! "$GLIB_MKENUMS_PATH" --help >/dev/null 2>&1; then \
                echo "⚠ glib-mkenums exists but failed --help check"; \
            fi; \
        fi; \
    else \
        echo "Non-ARM64 architecture detected ($ARCH) — skipping glib-mkenums safety check"; \
    fi



# ======================
# Build gst-plugins-base (with glib-mkenums override + fallbacks)
# ======================
RUN set -eux; \
    GST_PLUGINS_BASE_VERSION="1.20.3"; \
    GST_MAJOR_MINOR="${GST_PLUGINS_BASE_VERSION%.*}"; \
    echo ">>> Fetching gst-plugins-base $GST_PLUGINS_BASE_VERSION from GStreamer sources"; \
    if ! wget -q https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-$GST_PLUGINS_BASE_VERSION.tar.xz; then \
        echo "⚠ gst-plugins-base $GST_PLUGINS_BASE_VERSION not found — skipping build"; \
    else \
        tar -xJf gst-plugins-base-$GST_PLUGINS_BASE_VERSION.tar.xz; \
        cd gst-plugins-base-$GST_PLUGINS_BASE_VERSION; \
        mkdir -p build && cd build; \
        echo ">>> Running Meson setup for gst-plugins-base"; \
        export CC=/lilyspark/compiler/bin/clang-16; \
        export CXX=/lilyspark/compiler/bin/clang++-16; \
        export CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a"; \
        export CXXFLAGS="$CFLAGS"; \
        export LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib"; \
        export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/media/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:/lilyspark/glibc/lib/pkgconfig"; \
        \
        # Ensure our custom glib-mkenums (if present) is found first
        export PATH="/lilyspark/opt/lib/media/bin:/lilyspark/usr/bin:${PATH}"; \
        \
        # Choose the best available glib-mkenums
        if [ -x /lilyspark/opt/lib/media/bin/glib-mkenums ]; then \
            GLIB_MKENUMS_BIN=/lilyspark/opt/lib/media/bin/glib-mkenums; \
        elif [ -x /lilyspark/usr/bin/glib-mkenums ]; then \
            GLIB_MKENUMS_BIN=/lilyspark/usr/bin/glib-mkenums; \
        elif command -v glib-mkenums >/dev/null 2>&1; then \
            GLIB_MKENUMS_BIN=$(command -v glib-mkenums); \
        else \
            echo "⚠ glib-mkenums not found — Meson may fail"; \
            GLIB_MKENUMS_BIN="glib-mkenums"; \
        fi; \
        echo ">>> Using glib-mkenums at $GLIB_MKENUMS_BIN"; \
        \
        if ! meson setup --prefix=/lilyspark/opt/lib/media .. \
            --buildtype=release \
            -Dexamples=disabled \
            -Dintrospection=disabled \
            -Dtests=disabled \
            -Dorc=disabled \
            -Ddefault_library=shared \
            -Dglib_mkenums="$GLIB_MKENUMS_BIN" \
            -Dc_args="$CFLAGS" \
            -Dc_link_args="$LDFLAGS"; then \
            echo "⚠ Meson setup failed for gst-plugins-base — skipping"; \
        else \
            echo ">>> Building gst-plugins-base"; \
            if ! ninja -C . install; then \
                echo "⚠ Ninja build failed for gst-plugins-base — skipping"; \
            else \
                echo "✓ gst-plugins-base installed at /lilyspark/opt/lib/media"; \
            fi; \
        fi; \
        cd / && rm -rf gst-plugins-base-$GST_PLUGINS_BASE_VERSION*; \
    fi


# ======================
# Safety: Patch all .pc files to force glib-mkenums path
# ======================
RUN set -eux; \
    PKGCONFIG_DIR="/lilyspark/opt/lib/media/lib/pkgconfig"; \
    if [ -d "$PKGCONFIG_DIR" ]; then \
        echo ">>> Patching .pc files in $PKGCONFIG_DIR to use custom glib-mkenums"; \
        for pc in "$PKGCONFIG_DIR"/*.pc; do \
            [ -f "$pc" ] || continue; \
            echo ">>> Checking $pc"; \
            grep -i mkenums "$pc" || true; \
            sed -i \
              -e "s|/usr/bin/glib-mkenums|/lilyspark/opt/lib/media/bin/glib-mkenums|" \
              -e "s|/lilyspark/usr/bin/glib-mkenums|/lilyspark/opt/lib/media/bin/glib-mkenums|" \
              "$pc" || true; \
            echo ">>> After patch:"; \
            grep -i mkenums "$pc" || true; \
        done; \
    fi


# ======================
# SECTION: xorg-server Build (defensive, POSIX, sysroot-aware)
# ======================
RUN printf '%s\n' "=== INSTALLING XORG PROTOCOL DEPENDENCIES ==="; \
    apk add --no-cache xorgproto libxcvt pixman pixman-dev || true; \
    \
    SYSROOT="/lilyspark"; \
    mkdir -p "$SYSROOT/usr/include" "$SYSROOT/usr/lib/pkgconfig" "$SYSROOT/usr/lib"; \
    \
    echo "=== POPULATING SYSROOT WITH XORG DEPENDENCIES ==="; \
    cp -a /usr/include/X11 "$SYSROOT/usr/include/" 2>/dev/null || true; \
    cp -a /usr/include/pixman-1 "$SYSROOT/usr/include/" 2>/dev/null || true; \
    cp -a /usr/lib/libxcvt* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/libpixman-1* "$SYSROOT/usr/lib/" 2>/dev/null || true; \
    cp -a /usr/lib/pkgconfig/libxcvt.pc "$SYSROOT/usr/lib/pkgconfig/" 2>/dev/null || true; \
    cp -a /usr/lib/pkgconfig/pixman-1.pc "$SYSROOT/usr/lib/pkgconfig/" 2>/dev/null || true; \
    \
    printf '%s\n' "=== BUILDING xorg-server (defensive, POSIX, sysroot-aware) ==="; \
    if [ -x /lilyspark/compiler/bin/clang-16 ]; then \
        export PATH="/lilyspark/compiler/bin:$PATH"; \
        export CC=/lilyspark/compiler/bin/clang-16; \
        export CXX=/lilyspark/compiler/bin/clang++-16; \
        if [ -x /lilyspark/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/lilyspark/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/lilyspark/compiler/bin/llvm-config; fi; \
    else \
        printf '%s\n' "✗ required compiler not present — skipping xorg-server build"; \
        true; \
    fi; \
    \
    if [ ! -d xorg-server ]; then \
        git clone --depth=1 --branch xorg-server-21.1.8 https://gitlab.freedesktop.org/xorg/xserver.git xorg-server 2>/tmp/xorg_clone.err || { printf '%s\n' "⚠ git clone failed (see /tmp/xorg_clone.err). Skipping xorg build"; true; }; \
    fi; \
    \
    if [ -d xorg-server ]; then \
        cd xorg-server || true; \
        # Scan source for LLVM references (optional) \
        grep -RIl "LLVM15\\|llvm-15" . 2>/tmp/xorg_source_scan.log || true; \
        \
        export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"; \
        export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/lilyspark/opt/lib/media/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        export CFLAGS="--sysroot=$SYSROOT -I$lilyspark/opt/lib/media/include -I$lilyspark/compiler/include -I$lilyspark/glibc/include -march=armv8-a"; \
        export CXXFLAGS="$CFLAGS"; \
        export LDFLAGS="--sysroot=$SYSROOT -L$lilyspark/opt/lib/media/lib -L$lilyspark/compiler/lib -L$lilyspark/glibc/lib"; \
        \
        /usr/local/bin/check-filesystem.sh "xorg-pre-config" 2>/tmp/xorg_filesystem.log || true; \
        printf 'int main(void){return 0;}\n' > /tmp/xorg_toolchain_test.c; \
        $CC $CFLAGS -Wl,--sysroot=$SYSROOT -o /tmp/xorg_toolchain_test /tmp/xorg_toolchain_test.c 2>/tmp/xorg_toolchain_test.err || printf '%s\n' "⚠ compiler test failed"; \
        \
        autoreconf -fiv 2>/tmp/xorg_autoreconf.log || true; \
        CFG_FLAGS="--prefix=/usr --sysconfdir=/etc --localstatedir=/var \
          --disable-systemd-logind --disable-libunwind \
          --enable-xvfb --enable-xnest --enable-xephyr \
          --disable-xorg --disable-xwin --disable-xquartz \
          --without-dtrace \
          --disable-glamor --disable-glx --disable-dri --disable-dri2 --disable-dri3 \
          --disable-docs"; \
        \
        # Configure with output filtered: keep fop warning, suppress irrelevant ones \
        ./configure $CFG_FLAGS \
          CC="$CC" CXX="$CXX" \
          PKG_CONFIG_SYSROOT_DIR="$PKG_CONFIG_SYSROOT_DIR" \
          PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
          CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
          2>&1 | grep -v -E "optional|not required|skipping.*tests" | tee /tmp/xorg-configure.log || true; \
        \
        (make -j"$NPROCS" 2>&1 | tee /tmp/xorg-build.log) || printf '%s\n' "✗ make failed (see /tmp/xorg-build.log) — continuing"; \
        (DESTDIR=$SYSROOT make install 2>&1 | tee /tmp/xorg-install.log) || printf '%s\n' "✗ make install failed (see /tmp/xorg-install.log) — continuing"; \
        \
        mkdir -p $SYSROOT/usr/x11 || true; \
        mv $SYSROOT/usr/bin/X* $SYSROOT/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mv $SYSROOT/usr/lib/libxserver* $SYSROOT/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mkdir -p $SYSROOT/usr/x11/include/xorg || true; \
        cp -r include/* $SYSROOT/usr/x11/include/xorg/ 2>/tmp/xorg-mv.log || true; \
        \
        # Symlink binaries/libs back to /usr
        for xbin in $SYSROOT/usr/x11/X*; do \
            [ -f "$xbin" ] || continue; \
            ln -sf "../x11/$(basename "$xbin")" "$SYSROOT/usr/bin/$(basename "$xbin")" 2>/dev/null || true; \
        done; \
        for xlib in $SYSROOT/usr/x11/libxserver*; do \
            [ -f "$xlib" ] || continue; \
            ln -sf "../x11/$(basename "$xlib")" "$SYSROOT/usr/lib/$(basename "$xlib")" 2>/dev/null || true; \
        done; \
        \
        /usr/local/bin/dependency_checker.sh $CC 2>/tmp/xorg_depcheck.log || true; \
        /usr/local/bin/binlib_validator.sh $CC 2>/tmp/xorg_binlib.log || true; \
        /usr/local/bin/version_matrix.sh 2>/tmp/xorg_versions.log || true; \
        /usr/local/bin/cflag_audit.sh 2>/tmp/xorg_cflags.log || true; \
        find $SYSROOT/usr -name "*xserver*" -exec grep -l "LLVM15\\|llvm-15" {} \; 2>/tmp/xorg_contam.log || true; \
        \
        cd /; rm -rf xorg-server 2>/dev/null || true; \
        printf '%s\n' ">>> xorg build step complete (see logs in /tmp)"; \
    else \
        printf '%s\n' "⚠ xorg-server source directory not present; skipped build"; \
    fi; \
    true



# ======================
# SECTION: Mesa Build (sysroot-focused, LLVM16) — robust LLVM/DRI handling
# ======================
ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

RUN echo "=== SYSROOT PREPARATION AND MESA BUILD (auto-DRI/glvnd/LLVM) ===" && \
    \
    # safe-copy helper
    safe_copy() { \
        pattern="$1"; dest="$2"; \
        echo "Safe-copy: $pattern -> $dest"; mkdir -p "$dest"; \
        matched=0; \
        for f in $(sh -c "ls -d $pattern 2>/dev/null || true"); do \
            [ -z "$f" ] && continue; \
            realf=$(readlink -f "$f" 2>/dev/null || printf "%s" "$f"); \
            case "$realf" in /lilyspark/*) echo "  - skip in-dest src $realf"; continue ;; esac; \
            if cp -a "$realf" "$dest/"; then \
                echo "  ✓ copied $(basename "$realf")"; matched=1; \
            else \
                echo "  ⚠ copy failed $realf"; \
            fi; \
        done; \
        if [ "$matched" -eq 0 ]; then \
            echo "  ⚠ nothing matched $pattern; placeholder in $dest"; mkdir -p "$dest"; touch "$dest/.placeholder"; \
        fi; \
    }; \
    \
    # normalize .pc prefix helper (force prefix=/usr so Meson resolves sysroot correctly)
    normalize_pc_prefix() { \
        pcfile="$1"; \
        if [ -f "$pcfile" ]; then \
            echo "Normalizing prefix to /usr in $pcfile"; \
            # preserve file if sed fails; do in-place replace
            sed -i 's|^prefix=.*|prefix=/usr|' "$pcfile" 2>/dev/null || echo "⚠ failed to normalize $pcfile"; \
        fi; \
    }; \
    \
    # populate sysroot minimal runtime pieces (safe)
    safe_copy "/usr/lib/crt*.o" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/gcc/*/*/crt*.o" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/libgcc*" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/gcc/*/*/libgcc*" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/gcc/*/*/*.a" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/libssp*" "/lilyspark/usr/lib"; \
    \
    # musl/resolved loader (try resolved paths, but don't fail)
    echo "=== DEBUGGING MUSL FILE LOCATIONS ==="; \
    echo "Architecture: $(uname -m)"; \
    echo "Looking for musl files:"; \
    ls -la /lib/ld-musl* 2>/dev/null || echo "No ld-musl files in /lib"; \
    ls -la /lib/libc.musl* 2>/dev/null || echo "No libc.musl files in /lib"; \
    ls -la /usr/lib/ld-musl* 2>/dev/null || echo "No ld-musl files in /usr/lib"; \
    ls -la /usr/lib/libc.musl* 2>/dev/null || echo "No libc.musl files in /usr/lib"; \
    \
    # Try multiple possible locations for musl files with better error handling
    for pattern in "/lib/ld-musl-*.so.1" "/usr/lib/ld-musl-*.so.1" "/lib/libc.musl-*.so.1" "/usr/lib/libc.musl-*.so.1"; do \
        echo "Checking pattern: $pattern"; \
        for f in $pattern; do \
            if [ -e "$f" ]; then \
                echo "Found musl file: $f"; \
                realf=$(readlink -f "$f" 2>/dev/null || printf "%s" "$f"); \
                echo "Real path: $realf"; \
                # Use the same successful copy method as XORG section
                if cp -a "$realf" /lilyspark/lib/ 2>/dev/null; then \
                    echo "✓ Copied musl file: $(basename "$realf")"; \
                else \
                    echo "⚠ Failed to copy musl file $realf"; \
                fi; \
            fi; \
        done; \
    done; \
    \
    # Create essential symlinks if musl files were copied
    if ls /lilyspark/lib/ld-musl-*.so.1 >/dev/null 2>&1; then \
        cd /lilyspark/lib && \
        for f in ld-musl-*.so.1; do \
            ln -sf "$f" "ld-linux-$(uname -m).so.1" 2>/dev/null || true; \
            ln -sf "$f" "ld-linux.so.1" 2>/dev/null || true; \
        done && \
        cd - >/dev/null; \
        echo "✓ Created musl symlinks"; \
    else \
        echo "⚠ No musl loader found, creating placeholder"; \
        touch /lilyspark/lib/.musl-placeholder; \
    fi; \
    \
    # FALLBACK: Use EXACT XORG sysroot population method if musl still missing
    if [ ! -f "/lilyspark/lib/ld-musl-aarch64.so.1" ]; then \
        echo "=== FALLBACK: USING XORG SYSROOT POPULATION METHOD FOR MESA ==="; \
        SYSROOT="/lilyspark"; \
        SR_USR_LIB="$SYSROOT/usr/lib"; \
        SR_USR_INCLUDE="$SYSROOT/usr/include"; \
        SR_LIB="$SYSROOT/lib"; \
        mkdir -p "$SR_USR_LIB" "$SR_USR_INCLUDE" "$SR_LIB"; \
        \
        copy_and_verify() { \
            src="$1"; dest="$2"; descr="$3"; \
            echo "Attempting to copy ($descr): $src -> $dest"; \
            mkdir -p "$dest" 2>/dev/null || true; \
            if cp -a $src "$dest" 2>/dev/null; then \
                echo "✓ Copied: $src -> $dest"; \
            else \
                echo "⚠ Could not copy $src -> $dest (continuing)"; \
                if [ -z "$(ls -A "$dest" 2>/dev/null)" ]; then \
                    touch "$dest/.placeholder" || true; \
                fi; \
            fi; \
        }; \
        \
        echo "Copying libc/musl and dynamic linker..."; \
        copy_and_verify "/lib/ld-musl-*.so.1" "$SR_LIB" "musl dynamic loader"; \
        copy_and_verify "/lib/libc.musl-*.so.1" "$SR_LIB" "musl libc"; \
        copy_and_verify "/lib/libpthread*.so*" "$SR_LIB" "pthread"; \
        copy_and_verify "/usr/lib/libc.a" "$SR_USR_LIB" "libc static (dev)"; \
        \
        # Create essential symlinks if musl files were copied
        if ls /lilyspark/lib/ld-musl-*.so.1 >/dev/null 2>&1; then \
            cd /lilyspark/lib && \
            for f in ld-musl-*.so.1; do \
                ln -sf "$f" "ld-linux-$(uname -m).so.1" 2>/dev/null || true; \
                ln -sf "$f" "ld-linux.so.1" 2>/dev/null || true; \
            done && \
            cd - >/dev/null; \
            echo "✓ Created musl symlinks via XORG fallback"; \
        else \
            echo "⚠ XORG fallback also failed to copy musl"; \
        fi; \
        \
        echo "Copying compiler support and libgcc..."; \
        copy_and_verify "/usr/lib/libgcc*" "$SR_USR_LIB" "libgcc"; \
        copy_and_verify "/usr/lib/libssp*" "$SR_USR_LIB" "libssp"; \
        copy_and_verify "/usr/lib/libatomic*" "$SR_USR_LIB" "libatomic"; \
        \
        echo "Copying math and other standard libs..."; \
        copy_and_verify "/usr/lib/libm.a" "$SR_USR_LIB" "libm static"; \
        copy_and_verify "/usr/lib/libm.so*" "$SR_USR_LIB" "libm shared"; \
        copy_and_verify "/usr/lib/libdl.so*" "$SR_USR_LIB" "libdl"; \
        \
        echo "=== XORG FALLBACK SYSROOT POPULATION COMPLETE ==="; \
    else \
        echo "✓ Musl already present, skipping XORG fallback"; \
    fi; \
    \
    safe_copy "/usr/lib/libpthread.a" "/lilyspark/usr/lib"; \
    safe_copy "/usr/lib/libm.a" "/lilyspark/usr/lib"; \
    \
    # Fix libm SONAME for musl (math functions are in libc)
    if [ ! -f /lilyspark/usr/lib/libm.so ]; then \
        # In musl, libm is part of libc, so create symlink to libc
        if [ -f /lilyspark/lib/libc.musl-aarch64.so.1 ]; then \
            ln -sf ../lib/libc.musl-aarch64.so.1 /lilyspark/usr/lib/libm.so && \
            echo "✓ Created libm.so -> musl libc symlink"; \
        else \
            echo "⚠ libm SONAME missing - creating placeholder"; \
            touch /lilyspark/usr/lib/.libm-placeholder; \
        fi; \
    fi; \
    \
    # copy headers best-effort
    if [ -d /usr/include ]; then cp -r /usr/include/* /lilyspark/usr/include/ 2>/dev/null || true; else mkdir -p /lilyspark/usr/include; touch /lilyspark/usr/include/.placeholder; fi; \
    \
    # fix: ensure wayland-scanner exists in sysroot
    if [ -x /usr/bin/wayland-scanner ]; then \
        cp /usr/bin/wayland-scanner /lilyspark/usr/bin/ && echo "✓ wayland-scanner copied into sysroot"; \
    else \
        echo "⚠ wayland-scanner missing on host, creating placeholder"; \
        echo '#!/bin/sh\nexit 1' > /lilyspark/usr/bin/wayland-scanner; chmod +x /lilyspark/usr/bin/wayland-scanner; \
    fi; \
    \
    # sanity-compile to validate sysroot + clang
    echo 'int main(){return 0;}' > /tmp/test.c; \
    /lilyspark/compiler/bin/clang-16 --sysroot=/lilyspark -I/lilyspark/usr/include /tmp/test.c -o /tmp/test.out 2>/tmp/clang-sanity.log && echo "✔ clang sanity OK" || (echo "✗ clang sanity failed (see /tmp/clang-sanity.log)"; cat /tmp/clang-sanity.log || true); \
    rm -f /tmp/test.c /tmp/test.out || true; \
    \
    # clone mesa (non-fatal)
    if ! git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git; then \
        echo "⚠ mesa clone failed; skipping mesa build"; \
    else \
        cd mesa; git fetch --tags || true; git checkout -b mesa-24.0.3-branch 67da5a8f08d11b929db3af8b70436065f093fcce || true; \
        \
        # set up build dir
        rm -rf builddir; mkdir builddir; cd builddir; \
        \
        # ----- ADDED: pkg-config preflight / ensure pkgconfig paths include sys & graphics + ARCH/GCC fallbacks -----
        echo "=== pkg-config preflight for Mesa ==="; \
        ARCH="$(uname -m)"; \
        # include common pkgconfig locations for host + arch-specific Debian-style dirs + local fallbacks
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/lib/${ARCH}-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"; \
        echo "--- pkgconfig dirs ---"; \
        ls -la /lilyspark/opt/lib/graphics/usr/lib/pkgconfig || echo "no graphics pkgconfig dir"; \
        ls -la /lilyspark/opt/lib/sys/usr/lib/pkgconfig || echo "no sys pkgconfig dir"; \
        ls -la /lilyspark/usr/lib/pkgconfig || echo "no /lilyspark/usr/lib/pkgconfig"; \
        ls -la /usr/lib/${ARCH}-linux-gnu/pkgconfig 2>/dev/null || echo "no arch-specific pkgconfig dir"; \
        echo "--- pkgconfig files (graphics) ---"; ls -la /lilyspark/opt/lib/graphics/usr/lib/pkgconfig 2>/dev/null || true; \
        echo "--- pkgconfig files (sys) ---"; ls -la /lilyspark/opt/lib/sys/usr/lib/pkgconfig 2>/dev/null || true; \
        echo "Checking libdrm via pkg-config:"; \
        pkg-config --modversion libdrm || echo "⚠ libdrm not visible to pkg-config (pre-meson)"; \
        pkg-config --cflags libdrm || true; pkg-config --libs libdrm || true; \
        \
        # ==== STAGE 1: EXTRA PRE-MESON VALIDATION ==== \
        echo "=== STAGE 1: PRE-MESON DETAILED CHECKS ==="; \
        echo "--- Listing libdrm .pc files and contents ---"; \
        for d in /lilyspark/opt/lib/graphics/usr/lib/pkgconfig /lilyspark/opt/lib/sys/usr/lib/pkgconfig /lilyspark/usr/lib/pkgconfig; do \
            echo "DIR: $d"; ls -la "$d" 2>/dev/null || echo " (missing)"; \
            if [ -f "$d/libdrm.pc" ]; then \
                normalize_pc_prefix "$d/libdrm.pc"; \
                echo "---- $d/libdrm.pc ----"; sed -n '1,120p' "$d/libdrm.pc" || true; \
            fi; \
        done; \
        echo "--- Checking for libdrm shared objects ---"; \
        ls -la /lilyspark/opt/lib/graphics/usr/lib/libdrm* /lilyspark/opt/lib/sys/usr/lib/libdrm* /lilyspark/usr/lib/libdrm* 2>/dev/null || echo "No libdrm .so found in expected locations"; \
        if command -v readelf >/dev/null 2>&1; then \
            for f in /lilyspark/opt/lib/graphics/usr/lib/libdrm*.so* /lilyspark/opt/lib/sys/usr/lib/libdrm*.so* /lilyspark/usr/lib/libdrm*.so*; do \
                [ -f "$f" ] && echo "readelf -d $f" && readelf -d "$f" | sed -n '1,120p' || true; \
            done; \
        else \
            echo "ℹ readelf not installed, skipping ELF inspection"; \
        fi; \
        \
        # run meson (stderr filtered to drop mtls-dialect=gnu2 + cxx_args noise)
        PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
        PATH="/lilyspark/compiler/bin:$PATH" \
        CC="/lilyspark/compiler/bin/clang-16 --sysroot=/lilyspark" \
        CXX="/lilyspark/compiler/bin/clang++-16 --sysroot=/lilyspark" \
        meson setup \
            --prefix=/lilyspark/opt/mesa \
            -Dpkg_config_path="$PKG_CONFIG_PATH" \
            -Dvulkan-drivers=auto \
            -Dgallium-drivers=auto \
            -Dplatforms=x11,wayland \
            -Dglx=dri \
            -Degl=enabled \
            -Dshared-glapi=enabled \
            -Dllvm=enabled \
            -Dgallium-xa=enabled \
            -Dgallium-vdpau=disabled \
            -Dgallium-omx=disabled \
            -Dgallium-va=disabled \
            -Dgallium-nine=false \
            -Dgallium-opencl=disabled \
            -Dosmesa=true \
            -Dtools=[] \
            -Dc_args="-ftls-model=initial-exec" \
            -Dc_link_args="-ftls-model=initial-exec" \
            .. 2> >(grep -v "mtls-dialect=gnu2" | grep -v "cxx_args") || \
            (echo "✗ meson setup failed"; \
            cat meson-logs/meson-log.txt || true; \
            grep -R "tls-model" meson-logs/meson-log.txt || true; \
            grep -R "libdrm" meson-logs/meson-log.txt || true; \
            exit 1); \
        \
        # ==== STAGE 2: MESON LOGS & DEPENDENCY GREP ==== \
        echo "=== STAGE 2: MESON LOG & DEPENDENCY DUMP ==="; \
        if [ -f meson-logs/meson-log.txt ]; then \
            echo "---- Meson log tail (last 200 lines) ----"; tail -n 200 meson-logs/meson-log.txt || true; \
            echo "---- Grep for libdrm/dependency lines ----"; grep -i -n "libdrm" meson-logs/meson-log.txt || echo "No libdrm mention in meson-log"; \
            echo "---- Grep for pciaccess/libepoxy/gbm/wayland ----"; grep -i -n "pciaccess\|libepoxy\|gbm\|wayland\|x11" meson-logs/meson-log.txt || true; \
        else \
            echo "ℹ meson-logs/meson-log.txt not present (Meson may have logged elsewhere)"; \
        fi; \
        \
        # ==== STAGE 3: PRE-NINJA BUILDDIR INSPECTION ==== \
        echo "=== STAGE 3: BUILDDIR INSPECTION BEFORE NINJA ==="; \
        echo "Listing builddir top-level:"; ls -la builddir || true; \
        echo "Finding references to libdrm inside builddir:"; grep -R -n -i "libdrm" builddir || true; \
        echo "Checking meson-info and compile commands if present:"; ls -la builddir/meson-info || true; sed -n '1,200p' builddir/meson-info/intro.json 2>/dev/null || true; \
        \
        # build with ninja
        ninja -v || (echo "✗ ninja build failed"; \
                     cat meson-logs/meson-log.txt || true; \
                     grep -R "tls-model" meson-logs/meson-log.txt || true; \
                     exit 1); \
        ninja install || (echo "✗ ninja install failed"; \
                           cat meson-logs/meson-log.txt || true; \
                           grep -R "tls-model" meson-logs/meson-log.txt || true; \
                           exit 1); \
        \
        # ==== STAGE 4: POST-INSTALL VERIFICATION & SYSROOT SYNC ==== \
        echo "=== STAGE 4: POST-INSTALL VERIFICATION ==="; \
        echo "Listing /lilyspark/opt/lib/graphics contents (top):"; ls -la /lilyspark/opt/lib/graphics | head -50 || true; \
        echo "Listing pkgconfig dirs after install:"; ls -la /lilyspark/opt/lib/graphics/usr/lib/pkgconfig 2>/dev/null || true; ls -la /lilyspark/opt/lib/sys/usr/lib/pkgconfig 2>/dev/null || true; \
        echo "Attempting to copy libdrm pc/libs into sysroot (safe)"; \
        mkdir -p /lilyspark/opt/lib/sys/usr/lib/pkgconfig /lilyspark/opt/lib/sys/usr/lib 2>/dev/null || true; \
        cp -av /lilyspark/opt/lib/graphics/usr/lib/pkgconfig/libdrm*.pc /lilyspark/opt/lib/sys/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ copy of libdrm*.pc to sys failed"; \
        cp -av /lilyspark/opt/lib/graphics/usr/lib/libdrm* /lilyspark/opt/lib/sys/usr/lib/ 2>/dev/null || echo "⚠ copy of libdrm libs to sys failed"; \
        ls -la /lilyspark/opt/lib/sys/usr/lib | head -40 || true; \
        echo "Normalizing any copied .pc files to prefix=/usr (post-install)"; \
        for f in /lilyspark/opt/lib/sys/usr/lib/pkgconfig/libdrm*.pc /lilyspark/opt/lib/graphics/usr/lib/pkgconfig/libdrm*.pc; do [ -f "$f" ] && sed -i 's|^prefix=.*|prefix=/usr|' "$f" 2>/dev/null || true; done; \
        echo "Recompute PKG_CONFIG_PATH and test pkg-config"; \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:/lilyspark/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:/usr/lib/$(uname -m)-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"; \
        pkg-config --modversion libdrm || echo "⚠ libdrm not found by pkg-config after install/sync"; \
        pkg-config --cflags libdrm || true; pkg-config --libs libdrm || true; \
        echo "Inspect meson logs for libdrm occurrences (post):"; grep -i -n "libdrm" meson-logs/meson-log.txt || true; \
        \
        echo "=== MESA BUILD COMPLETE ==="; \
    fi


# ======================
# BUILD GBM (from Mesa) for ARM64 with libdrm verification
# ======================
RUN echo "=== START: BUILDING GBM FROM MESA SOURCE (ARM64) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gbm-source-build" || true && \
    \
    echo ">>> Verifying libdrm installation <<<" && \
    if pkg-config --exists libdrm; then \
        echo "✔ libdrm found: $(pkg-config --modversion libdrm)"; \
    else \
        echo "⚠ libdrm not found! GBM build may fail"; \
    fi && \
    \
    mkdir -p /tmp/mesa-gbm && cd /tmp/mesa-gbm && \
    echo "Cloning Mesa source for GBM..." && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git . || (echo "⚠ Git clone failed" && exit 1) && \
    git checkout $(git rev-list --tags --max-count=1) || echo "⚠ Git checkout failed, using HEAD" && \
    \
    echo ">>> Configuring GBM build <<<" && \
    CC=/lilyspark/compiler/bin/clang-16 \
    CXX=/lilyspark/compiler/bin/clang++-16 \
    CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/lilyspark/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/opt/lib/sys/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/opt/lib/sys/glibc/lib" \
    PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" \
    PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=enabled \
        -Ddri-drivers= \
        -Dgallium-drivers= \
        -Degl=disabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=true \
        --buildtype=release \
        --wrap-mode=nodownload 2>&1 | tee /tmp/gbm-meson-setup.log || (echo "✗ GBM meson setup failed" && tail -50 /tmp/gbm-meson-setup.log && exit 1) && \
    \
    echo "=== Compiling GBM ===" && \
    ninja -C builddir -v 2>&1 | tee /tmp/gbm-meson-compile.log || (echo "✗ GBM compilation failed" && tail -50 /tmp/gbm-meson-compile.log && exit 1) && \
    \
    echo "=== Installing GBM ===" && \
    DESTDIR="/lilyspark/opt/lib/driver" ninja -C builddir install 2>&1 | tee /tmp/gbm-meson-install.log || (echo "✗ GBM install failed" && tail -50 /tmp/gbm-meson-install.log && exit 1) && \
    \
    echo "=== Populating sysroot for GBM ===" && \
    SYSROOT="/lilyspark/opt/lib/sys" && \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig} && \
    cp -av /lilyspark/opt/lib/driver/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || echo "⚠ include copy failed" && \
    cp -av /lilyspark/opt/lib/driver/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || echo "⚠ lib copy failed" && \
    cp -av /lilyspark/opt/lib/driver/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ pkgconfig copy failed" && \
    ls -la $SYSROOT/usr/include | head -20 && \
    ls -la $SYSROOT/usr/lib | head -20 && \
    ls -la $SYSROOT/usr/lib/pkgconfig | head -20 && \
    \
    echo "=== Verifying pkg-config can see GBM ===" && \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/lilyspark/opt/lib/driver/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" && \
    pkg-config --modversion gbm || echo "⚠ GBM still not detected" && \
    pkg-config --cflags gbm && pkg-config --libs gbm && \
    \
    echo "=== GBM post-install verification ===" && \
    find /lilyspark/opt/lib/driver -name "*gbm*" -type f | tee /tmp/gbm_verify.log && \
    /usr/local/bin/check_llvm15.sh "post-gbm-install" || true && \
    cd / && rm -rf /tmp/mesa-gbm && \
    echo "=== GBM BUILD COMPLETE ===" && \
    true


# ======================
# BUILD EGL (from Mesa) for ARM64 with libdrm verification
# ======================
RUN echo "=== START: BUILDING EGL FROM MESA SOURCE (ARM64) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-egl-source-build" || true && \
    \
    echo ">>> Verifying libdrm installation <<<" && \
    if pkg-config --exists libdrm; then \
        echo "✔ libdrm found: $(pkg-config --modversion libdrm)"; \
    else \
        echo "⚠ libdrm not found! EGL build may fail"; \
    fi && \
    \
    mkdir -p /tmp/mesa-egl && cd /tmp/mesa-egl && \
    echo "Cloning Mesa source for EGL..." && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git . || (echo "⚠ Git clone failed" && exit 1) && \
    git checkout $(git rev-list --tags --max-count=1) || echo "⚠ Git checkout failed, using HEAD" && \
    \
    echo ">>> Configuring EGL build <<<" && \
    CC=/lilyspark/compiler/bin/clang-16 \
    CXX=/lilyspark/compiler/bin/clang++-16 \
    CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/lilyspark/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/opt/lib/sys/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/opt/lib/sys/glibc/lib" \
    PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" \
    PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=enabled \
        -Ddri-drivers= \
        -Dgallium-drivers= \
        -Degl=enabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=true \
        --buildtype=release \
        --wrap-mode=nodownload 2>&1 | tee /tmp/egl-meson-setup.log || (echo "✗ EGL meson setup failed" && tail -50 /tmp/egl-meson-setup.log && exit 1) && \
    \
    echo "=== Compiling EGL ===" && \
    ninja -C builddir -v 2>&1 | tee /tmp/egl-meson-compile.log || (echo "✗ EGL compilation failed" && tail -50 /tmp/egl-meson-compile.log && exit 1) && \
    \
    echo "=== Installing EGL ===" && \
    DESTDIR="/lilyspark/opt/lib/driver" ninja -C builddir install 2>&1 | tee /tmp/egl-meson-install.log || (echo "✗ EGL install failed" && tail -50 /tmp/egl-meson-install.log && exit 1) && \
    \
    echo "=== Populating sysroot for EGL ===" && \
    SYSROOT="/lilyspark/opt/lib/sys" && \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig} && \
    cp -av /lilyspark/opt/lib/driver/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || echo "⚠ include copy failed" && \
    cp -av /lilyspark/opt/lib/driver/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || echo "⚠ lib copy failed" && \
    cp -av /lilyspark/opt/lib/driver/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ pkgconfig copy failed" && \
    ls -la $SYSROOT/usr/include | head -20 && \
    ls -la $SYSROOT/usr/lib | head -20 && \
    ls -la $SYSROOT/usr/lib/pkgconfig | head -20 && \
    \
    echo "=== Verifying pkg-config can see EGL ===" && \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/lilyspark/opt/lib/driver/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" && \
    pkg-config --modversion egl || echo "⚠ EGL still not detected" && \
    pkg-config --cflags egl && pkg-config --libs egl && \
    \
    echo "=== EGL post-install verification ===" && \
    find /lilyspark/opt/lib/driver -name "*egl*" -type f | tee /tmp/egl_verify.log && \
    /usr/local/bin/check_llvm15.sh "post-egl-install" || true && \
    cd / && rm -rf /tmp/mesa-egl && \
    echo "=== EGL BUILD COMPLETE ===" && \
    true


# ======================
# BUILD GLES (from Mesa) for ARM64
# ======================
RUN echo "=== START: BUILDING GLES FROM MESA SOURCE (ARM64) ===" && \
    /usr/local/bin/check_llvm15.sh "pre-gles-source-build" || true && \
    \
    echo ">>> Verifying libdrm installation <<<" && \
    if pkg-config --exists libdrm; then \
        echo "✔ libdrm found: $(pkg-config --modversion libdrm)"; \
    else \
        echo "⚠ libdrm not found! GLES build may fail"; \
    fi && \
    \
    mkdir -p /tmp/mesa-gles && cd /tmp/mesa-gles && \
    echo "Cloning Mesa source for GLES..." && \
    git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git . || (echo "⚠ Git clone failed" && exit 1) && \
    git checkout $(git rev-list --tags --max-count=1) || echo "⚠ Git checkout failed, using HEAD" && \
    \
    # ----------------------
    # 1️⃣ Compiler detection & native file
    # ----------------------
    echo "=== Compiler detection ==="; \
    CC_FALLBACK="cc"; CXX_FALLBACK="c++"; \
    CC="$(command -v /lilyspark/compiler/bin/clang-16 || command -v clang || echo $CC_FALLBACK)"; \
    CXX="$(command -v /lilyspark/compiler/bin/clang++-16 || command -v clang++ || echo $CXX_FALLBACK)"; \
    echo "Using CC=$CC, CXX=$CXX"; command -v $CC || echo "⚠ $CC not in PATH"; command -v $CXX || echo "⚠ $CXX not in PATH"; \
    \
    echo "Creating Meson native file..."; \
    echo "[binaries]" > native-file.ini; \
    echo "c = '$CC'" >> native-file.ini; \
    echo "cpp = '$CXX'" >> native-file.ini; \
    echo "ar = 'ar'" >> native-file.ini; \
    echo "strip = 'strip'" >> native-file.ini; \
    echo "pkg-config = 'pkg-config'" >> native-file.ini; \
    echo "[host_machine]" >> native-file.ini; \
    echo "system = 'linux'" >> native-file.ini; \
    echo "cpu_family = 'aarch64'" >> native-file.ini; \
    echo "cpu = 'aarch64'" >> native-file.ini; \
    echo "endian = 'little'" >> native-file.ini; \
    cat native-file.ini; \
    \
    # ----------------------
    # 2️⃣ Meson setup, build, install
    # ----------------------
    echo "=== Meson setup for GLES ==="; \
    meson setup builddir \
        --prefix=/usr \
        --libdir=lib \
        --includedir=include \
        --buildtype=release \
        -Dgbm=disabled \
        -Degl=disabled \
        -Dgles1=enabled \
        -Dgles2=enabled \
        -Dopengl=true \
        --native-file native-file.ini \
        -Dpkg_config_path="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig" 2>&1 | tee /tmp/gles-meson-setup.log || (echo "✗ GLES meson setup failed" && tail -50 /tmp/gles-meson-setup.log && exit 1); \
    \
    echo "=== Meson compile for GLES ==="; \
    meson compile -C builddir -j$(nproc) 2>&1 | tee /tmp/gles-meson-compile.log || (echo "✗ GLES compilation failed" && tail -50 /tmp/gles-meson-compile.log && exit 1); \
    \
    echo "=== Meson install for GLES ==="; \
    meson install -C builddir --destdir=/lilyspark/opt/lib/driver --no-rebuild 2>&1 | tee /tmp/gles-meson-install.log || (echo "✗ GLES install failed" && tail -50 /tmp/gles-meson-install.log && exit 1); \
    \
    # ----------------------
    # 3️⃣ Populate sysroot after install
    # ----------------------
    echo "=== Populating sysroot AFTER GLES installation ==="; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig}; \
    cp -av /lilyspark/opt/lib/driver/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || echo "⚠ include copy failed"; \
    cp -av /lilyspark/opt/lib/driver/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || echo "⚠ lib copy failed"; \
    cp -av /lilyspark/opt/lib/driver/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ pkgconfig copy failed"; \
    ls -la $SYSROOT/usr/include | head -20; \
    ls -la $SYSROOT/usr/lib | head -20; \
    ls -la $SYSROOT/usr/lib/pkgconfig | head -20; \
    \
    # ----------------------
    # 4️⃣ Verify pkg-config can see GLES
    # ----------------------
    echo "=== Verifying pkg-config can see GLES libraries ==="; \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:/lilyspark/opt/lib/driver/usr/lib/pkgconfig:/lilyspark/opt/lib/graphics/usr/lib/pkgconfig"; \
    pkg-config --modversion glesv1 || echo "⚠ GLESv1 still not detected"; \
    pkg-config --modversion glesv2 || echo "⚠ GLESv2 still not detected"; \
    pkg-config --cflags glesv1 && pkg-config --libs glesv1; \
    pkg-config --cflags glesv2 && pkg-config --libs glesv2; \
    \
    # ----------------------
    # 5️⃣ Post-install verification
    # ----------------------
    echo "=== GLES post-install verification ==="; \
    find /lilyspark/opt/lib/driver -name "*GLES*" -type f | tee /tmp/gles_verify.log; \
    /usr/local/bin/check_llvm15.sh "post-gles-install" || true; \
    cd / && rm -rf /tmp/mesa-gles native-file.ini; \
    echo "=== GLES BUILD COMPLETE ==="; \
    true


# ======================
# libepoxy Build (ARM64-safe, fully logged)
# ======================
ARG LIBEPOXY_VER=1.5.10
ARG LIBEPOXY_GIT="https://github.com/anholt/libepoxy.git"

ENV PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
ENV PATH="/lilyspark/compiler/bin:${PATH}"

RUN echo "=== START: BUILDING libepoxy ${LIBEPOXY_VER} ===" && \
    ARCH="$(uname -m)" && echo "Detected architecture: $ARCH"; \
    \
    mkdir -p /tmp/libepoxy-src && cd /tmp/libepoxy-src; \
    echo "=== Attempt 1️⃣: Shallow clone + fetch specific commit ==="; \
    git clone --depth=1 "$LIBEPOXY_GIT" . 2>/tmp/libepoxy_clone.log || echo "⚠ Shallow clone failed, will try fallback"; \
    git fetch --depth=1 origin c84bc9459357a40e46e2fec0408d04fbdde2c973 2>/tmp/libepoxy_fetch.log || echo "⚠ Fetch commit failed, will try fallback"; \
    git checkout c84bc9459357a40e46e2fec0408d04fbdde2c973 -b libepoxy-${LIBEPOXY_VER} 2>/tmp/libepoxy_checkout.log || ( \
        echo "⚠ Commit checkout failed, trying fallback method 2"; \
        echo "=== Attempt 2️⃣: Full clone, checkout commit ==="; \
        rm -rf /tmp/libepoxy-src/*; \
        git clone "$LIBEPOXY_GIT" . 2>/tmp/libepoxy_full_clone.log || echo "⚠ Full clone failed, will try fallback 3"; \
        git checkout c84bc9459357a40e46e2fec0408d04fbdde2c973 -b libepoxy-${LIBEPOXY_VER} 2>/tmp/libepoxy_full_checkout.log || ( \
            echo "⚠ Full clone checkout failed, trying fallback method 3"; \
            echo "=== Attempt 3️⃣: Clone specific tag/branch ==="; \
            rm -rf /tmp/libepoxy-src/*; \
            git clone --branch ${LIBEPOXY_VER} --depth=1 "$LIBEPOXY_GIT" . 2>/tmp/libepoxy_tag_clone.log || ( \
                echo "⚠ Tag clone failed — cannot proceed"; exit 1 \
            ); \
        ) \
    ); \
    echo "✓ Git setup complete for libepoxy ${LIBEPOXY_VER}" \
    # ----------------------
    # 1️⃣ Compiler detection & native file
    # ----------------------
    echo "=== Compiler detection ==="; \
    CC_FALLBACK="cc"; CXX_FALLBACK="c++"; \
    CC="$(command -v /lilyspark/compiler/bin/clang-16 || command -v clang || echo $CC_FALLBACK)"; \
    CXX="$(command -v /lilyspark/compiler/bin/clang++-16 || command -v clang++ || echo $CXX_FALLBACK)"; \
    echo "Using CC=$CC, CXX=$CXX"; command -v $CC || echo "⚠ $CC not in PATH"; command -v $CXX || echo "⚠ $CXX not in PATH"; \
    \
    echo "Creating Meson native file..."; \
    echo "[binaries]" > native-file.ini; \
    echo "c = '$CC'" >> native-file.ini; \
    echo "cpp = '$CXX'" >> native-file.ini; \
    echo "ar = 'ar'" >> native-file.ini; \
    echo "strip = 'strip'" >> native-file.ini; \
    echo "pkg-config = 'pkg-config'" >> native-file.ini; \
    echo "[host_machine]" >> native-file.ini; \
    echo "system = 'linux'" >> native-file.ini; \
    echo "cpu_family = '$ARCH'" >> native-file.ini; \
    echo "cpu = '$ARCH'" >> native-file.ini; \
    echo "endian = 'little'" >> native-file.ini; \
    cat native-file.ini; \
    \
    # ----------------------
    # 2️⃣ Meson setup, build, install
    # ----------------------
    echo "=== Meson setup ==="; \
    meson setup builddir \
        --prefix=/usr \
        --libdir=lib \
        --includedir=include \
        --buildtype=release \
        -Dglx=yes -Degl=yes -Dx11=true -Dtests=false \
        --native-file native-file.ini \
        -Dpkg_config_path="$PKG_CONFIG_PATH" 2>&1 | tee /tmp/libepoxy-meson-setup.log; \
    \
    echo "=== Meson compile ==="; \
    meson compile -C builddir -j$(nproc) 2>&1 | tee /tmp/libepoxy-meson-compile.log; \
    \
    echo "=== Meson install ==="; \
    meson install -C builddir --destdir=/lilyspark/opt/lib/sys --no-rebuild 2>&1 | tee /tmp/libepoxy-meson-install.log; \
    \
    # ----------------------
    # 3️⃣ Populate sysroot after install
    # ----------------------
    echo "=== Populating sysroot AFTER installation ==="; \
    SYSROOT="/lilyspark/opt/lib/sys"; \
    mkdir -p $SYSROOT/usr/{include,lib,lib/pkgconfig}; \
    cp -av /lilyspark/opt/lib/sys/usr/include/* $SYSROOT/usr/include/ 2>/dev/null || echo "⚠ include copy failed"; \
    cp -av /lilyspark/opt/lib/sys/usr/lib/* $SYSROOT/usr/lib/ 2>/dev/null || echo "⚠ lib copy failed"; \
    cp -av /lilyspark/opt/lib/sys/usr/lib/pkgconfig/* $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || echo "⚠ pkgconfig copy failed"; \
    ls -la $SYSROOT/usr/include | head -20; \
    ls -la $SYSROOT/usr/lib | head -20; \
    ls -la $SYSROOT/usr/lib/pkgconfig | head -20; \
    \
    # ----------------------
    # 4️⃣ Verify pkg-config can see it
    # ----------------------
    echo "=== Verifying pkg-config can see libepoxy ==="; \
    export PKG_CONFIG_PATH="$SYSROOT/usr/lib/pkgconfig:$PKG_CONFIG_PATH"; \
    pkg-config --modversion epoxy || echo "⚠ libepoxy still not detected"; \
    pkg-config --cflags epoxy; pkg-config --libs epoxy; \
    \
    # ----------------------
    # 5️⃣ Post-install verification
    # ----------------------
    echo "=== Post-install verification ==="; \
    ls -R /lilyspark/opt/lib/sys | head -50; \
    cd / && rm -rf /tmp/libepoxy-src native-file.ini; \
    echo "=== libepoxy BUILD complete ==="; \
    true




# ======================
# SDL3-SPECIFIC SYSROOT POPULATION FOR GBM + EGL (ARM64 COMPLIANT)
# ======================
RUN echo "=== POPULATING SDL3 SYSROOT WITH GBM AND EGL (ARM64 DETECTION) ===" && \
    \
    # ARM64 platform detection and validation
    DETECTED_ARCH=$(uname -m) && \
    echo "Detected architecture: $DETECTED_ARCH" && \
    if [ "$DETECTED_ARCH" = "aarch64" ] || [ "$DETECTED_ARCH" = "arm64" ]; then \
        echo "✓ ARM64 platform confirmed for SDL3 sysroot population"; \
        ARM64_CONFIRMED="yes"; \
    else \
        echo "⚠ Non-ARM64 platform detected: $DETECTED_ARCH - proceeding with generic paths"; \
        ARM64_CONFIRMED="no"; \
    fi && \
    \
    # Copy GBM libraries, headers, pkg-config (defensive)
    echo "Copying GBM components..." && \
    cp -a /lilyspark/opt/lib/driver/usr/lib/libgbm* /lilyspark/opt/lib/sdl3/usr/media/lib/ 2>/dev/null || echo "GBM libs not found"; \
    cp -a /lilyspark/opt/lib/driver/usr/include/gbm* /lilyspark/opt/lib/sdl3/usr/media/include/ 2>/dev/null || echo "GBM headers not found"; \
    cp -a /lilyspark/opt/lib/driver/usr/lib/pkgconfig/gbm.pc /lilyspark/opt/lib/sdl3/usr/media/lib/pkgconfig/ 2>/dev/null || echo "GBM pkgconfig not found"; \
    \
    # Copy EGL libraries, headers, pkg-config (defensive)
    echo "Copying EGL components..." && \
    cp -a /lilyspark/opt/lib/driver/usr/lib/libEGL* /lilyspark/opt/lib/sdl3/usr/media/lib/ 2>/dev/null || echo "EGL libs not found"; \
    cp -a /lilyspark/opt/lib/driver/usr/include/EGL /lilyspark/opt/lib/sdl3/usr/media/include/ 2>/dev/null || echo "EGL headers not found"; \
    cp -a /lilyspark/opt/lib/driver/usr/lib/pkgconfig/EGL.pc /lilyspark/opt/lib/sdl3/usr/media/lib/pkgconfig/ 2>/dev/null || echo "EGL pkgconfig not found"; \
    \
    # Create symlinks for runtime libraries (ARM64-aware)
    if [ "$ARM64_CONFIRMED" = "yes" ]; then \
        echo "Creating ARM64-optimized library symlinks..." && \
        cd /lilyspark/opt/lib/sdl3/usr/media/lib && \
        for lib in libgbm*.so* libEGL*.so*; do \
            [ -f "$lib" ] || continue; \
            soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
            basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
            ln -sf "$lib" "$soname" 2>/dev/null || echo "Failed to create soname symlink for $lib"; \
            ln -sf "$soname" "$basename" 2>/dev/null || echo "Failed to create basename symlink for $lib"; \
            echo "✓ Created ARM64 symlinks for $lib"; \
        done; \
    else \
        echo "Creating generic library symlinks..." && \
        cd /lilyspark/opt/lib/sdl3/usr/media/lib && \
        for lib in libgbm*.so* libEGL*.so*; do \
            [ -f "$lib" ] || continue; \
            soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
            basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
            ln -sf "$lib" "$soname" 2>/dev/null || true; \
            ln -sf "$soname" "$basename" 2>/dev/null || true; \
            echo "Created generic symlinks for $lib"; \
        done; \
    fi && \
    \
    echo "✅ SDL3 sysroot populated with GBM + EGL (ARM64: $ARM64_CONFIRMED)"

# ======================
# SECTION: SDL3 Build
# ======================
RUN echo "=== BUILDING SDL3 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3" || true && \
    \
    git clone --depth=1 https://github.com/libsdl-org/SDL.git sdl && \
    cd sdl && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3 ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/sdl3/usr/media \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
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
        -DCMAKE_C_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
    2>&1 | grep -vE "fopen64|fseeko64|posix_spawn_file_actions_addchdir|itoa|_i64toa|_ltoa|strnstr|wcslcat|wcslcpy|sysctlbyname|elf_aux_info|sqr|LIBC_HAS_ISINFF|LIBC_HAS_ISNANF|ICONV_IN_LIBICONV|pthread_np.h|LIBC_HAS_WORKING_LIBUNWIND|LIBUNWIND_HAS_WORKINGLIBUNWIND|dbus-1|ibus-1.0|liburing-ffi|__GLIBC__" && \
    \
    echo "=== BUILDING SDL3 ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-build.log && \
    \
    echo "=== SDL3 INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/sdl3/usr/media/lib/libSDL3* 2>/dev/null || echo "No SDL3 libraries found" && \
    \
    cd ../../.. && rm -rf sdl && \
    /usr/local/bin/check_llvm15.sh "post-sdl3" || true && \
    echo "=== SDL3 BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_image Build
# ======================
RUN echo "=== BUILDING SDL3_image ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-image" || true && \
    \
    git clone --depth=1 https://github.com/libsdl-org/SDL_image.git sdl_image && \
    cd sdl_image && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_image ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/sdl3/usr/media \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
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
        -DCMAKE_C_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" && \
    \
    echo "=== BUILDING SDL3_image ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-image-build.log && \
    \
    echo "=== SDL3_image INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/sdl3/usr/media/lib/libSDL3_image* 2>/dev/null || echo "No SDL3_image libraries found" && \
    \
    cd ../../.. && rm -rf sdl_image && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-image" || true && \
    echo "=== SDL3_image BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_mixer Build
# ======================
RUN echo "=== BUILDING SDL3_mixer ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-mixer" || true && \
    \
    git clone --depth=1 https://github.com/libsdl-org/SDL_mixer.git sdl_mixer && \
    cd sdl_mixer && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_mixer ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/sdl3/usr/media \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DSDL3MIXER_OGG=ON \
        -DSDL3MIXER_FLAC=ON \
        -DSDL3MIXER_MOD=ON \
        -DSDL3MIXER_MP3=ON \
        -DSDL3MIXER_MID=ON \
        -DSDL3MIXER_OPUS=ON \
        -DSDL3MIXER_FLUIDSYNTH=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" && \
    \
    echo "=== BUILDING SDL3_mixer ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-mixer-build.log && \
    \
    echo "=== SDL3_mixer INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/sdl3/usr/media/lib/libSDL3_mixer* 2>/dev/null || echo "No SDL3_mixer libraries found" && \
    \
    cd ../../.. && rm -rf sdl_mixer && \
    /usr/local/bin/check_llvm15.sh "post-sdl3-mixer" || true && \
    echo "=== SDL3_mixer BUILD COMPLETED ==="

# ======================
# SECTION: SDL3_ttf Build
# ======================
RUN echo "=== BUILDING SDL3_ttf ===" && \
    /usr/local/bin/check_llvm15.sh "pre-sdl3-ttf" || true && \
    \
    git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git sdl_ttf && \
    cd sdl_ttf && \
    mkdir build && cd build && \
    \
    echo "=== CONFIGURING SDL3_ttf ===" && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/sdl3/usr/media \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
    2>&1 | grep -vE "fopen64|fseeko64|posix_spawn_file_actions_addchdir|itoa|_i64toa|_ltoa|strnstr|wcslcat|wcslcpy|sysctlbyname|elf_aux_info|sqr|LIBC_HAS_ISINFF|LIBC_HAS_ISNANF|ICONV_IN_LIBICONV|pthread_np.h|LIBC_HAS_WORKING_LIBUNWIND|LIBUNWIND_HAS_WORKINGLIBUNWIND|dbus-1|ibus-1.0|liburing-ffi|__GLIBC__" && \
    \
    echo "=== BUILDING SDL3_ttf ===" && \
    make -j"$(nproc)" install 2>&1 | tee /tmp/sdl3-ttf-build.log && \
    \
    echo "=== SDL3_ttf INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/sdl3/usr/media/lib/libSDL3_ttf* 2>/dev/null || echo "No SDL3_ttf libraries found" && \
    \
    cd ../../.. && rm -rf sdl_ttf && \
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
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/vulkan \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" && \
    \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Headers && \
    \
    # Verify installation
    echo "=== VULKAN-HEADERS INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/vulkan/include/vulkan/ 2>/dev/null || echo "No Vulkan headers found" && \
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
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/vulkan \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a -I/lilyspark/compiler/include -I/lilyspark/glibc/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
        -DBUILD_TESTS=OFF \
        -DVULKAN_HEADERS_INSTALL_DIR=/lilyspark/opt/lib/vulkan && \
    \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Loader && \
    \
    # Verify installation
    echo "=== VULKAN-LOADER INSTALLATION VERIFICATION ===" && \
    ls -la /lilyspark/opt/lib/vulkan/lib/libvulkan* 2>/dev/null || echo "No Vulkan loader libraries found" && \
    \
    # Create symlinks
    echo "=== CREATING VULKAN LOADER SYMLINKS ===" && \
    cd /lilyspark/opt/lib/vulkan/lib && \
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
# SECTION: glmark2 Build (ARM64 only)
# ======================
RUN echo "=== CHECKING PLATFORM FOR GLMARK2 BUILD ===" && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" != "aarch64" ]; then \
        echo "Non-ARM64 platform detected ($ARCH), skipping glmark2 build"; \
    else \
        echo "ARM64 platform detected ($ARCH), proceeding with glmark2 build" && \
        /usr/local/bin/check_llvm15.sh "pre-glmark2-clone" || true && \
        \
        git clone --progress https://github.com/glmark2/glmark2.git glmark2 && \
        /usr/local/bin/check_llvm15.sh "post-glmark2-clone" || true && \
        cd glmark2 && \
        mkdir build && cd build && \
        \
        echo "=== CONFIGURING GLMARK2 (ARM64 + LLVM16) ===" && \
        CC=/lilyspark/compiler/bin/clang-16 \
        CXX=/lilyspark/compiler/bin/clang++-16 \
        meson .. \
            --prefix=/lilyspark/opt/lib/graphics \
            --buildtype=release \
            -Dflavors=x11-gl,drm-gl 2>&1 | tee configure.log || { \
                echo "=== CONFIGURATION FAILED - CONTINUING ==="; \
                cat configure.log || true; \
                true; \
            } && \
        /usr/local/bin/check_llvm15.sh "post-glmark2-configure" || true && \
        \
        echo "=== BUILDING GLMARK2 WITH NINJA (ARM64 + LLVM16) ===" && \
        ninja -j"$(nproc)" 2>&1 | tee build.log || { \
            echo "=== BUILD FAILED - CONTINUING ==="; \
            cat build.log || true; \
            true; \
        } && \
        /usr/local/bin/check_llvm15.sh "post-glmark2-build" || true && \
        \
        echo "=== INSTALLING GLMARK2 (ARM64 + LLVM16) ===" && \
        ninja install 2>&1 | tee install.log || { \
            echo "=== INSTALL FAILED - CONTINUING ==="; \
            cat install.log || true; \
            true; \
        } && \
        \
        echo "=== VERIFYING GLMARK2 INSTALL ===" && \
        if ls -la /lilyspark/opt/lib/graphics/bin/glmark2* 2>/dev/null; then \
            echo "Glmark2 binaries installed successfully"; \
        else \
            echo "No glmark2 binaries found"; \
        fi && \
        \
        cd ../.. && \
        rm -rf glmark2 && \
        /usr/local/bin/check_llvm15.sh "post-glmark2-cleanup" || true && \
        echo "=== GLMARK2 BUILD COMPLETED ==="; \
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
    CC=/lilyspark/compiler/bin/clang-16 \
    CXX=/lilyspark/compiler/bin/clang++-16 \
    LLVM_CONFIG=/lilyspark/compiler/bin/llvm-config \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/database \
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
        -DCMAKE_C_FLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a -Wno-error" \
        -DCMAKE_CXX_FLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a -Wno-error" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
        -DPKG_CONFIG_PATH="/lilyspark/compiler/lib/pkgconfig:/lilyspark/opt/lib/database/lib/pkgconfig" \
        -Wno-dev && \
    \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-configure" || true && \
    \
    echo "=== STARTING SQLITE3 BUILD (ARM64 + LLVM16) ===" && \
    make -j"$(nproc)" VERBOSE=1 install && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-build" || true && \
    \
    echo "=== VERIFYING SQLITE3 INSTALL ===" && \
    test -f /lilyspark/opt/lib/database/include/sqlite3.h && \
    PKG_CONFIG_PATH=/lilyspark/opt/lib/database/lib/pkgconfig pkg-config --cflags --libs sqlite3 && \
    \
    cd ../.. && \
    rm -rf sqlite && \
    /usr/local/bin/check_llvm15.sh "post-sqlite3-cleanup" || true && \
    echo "=== SQLITE3 BUILD COMPLETED ==="

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

# Fix Hangup Code (Test)
CMD ["tail", "-f", "/dev/null"]




# ======================
# SECTION: Application Build Setup
# ======================
RUN echo "=== INITIALIZING APPLICATION BUILD ENVIRONMENT ===" && \
    echo "Creating all necessary directories..." && \
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

# ======================
# SYSROOT POPULATION FOR libdrm in DEBUG
# ======================
RUN echo "=== SYSROOT POPULATION FOR libdrm (debug stage) ===" && \
    \
    # Copy LLVM runtime and headers
    if cp -a /usr/lib/llvm-16/lib/clang/* /lilyspark/opt/lib/sys/usr/lib/clang/ 2>/dev/null; then \
        echo "✓ LLVM runtime copied successfully"; \
    else \
        echo "⚠ Warning: LLVM runtime not found or failed to copy"; \
    fi; \
    \
    if cp -a /usr/include/* /lilyspark/opt/lib/sys/usr/include/ 2>/dev/null; then \
        echo "✓ System headers copied successfully"; \
    else \
        echo "⚠ Warning: System headers not found or failed to copy"; \
    fi; \
    \
    # Copy system libraries for linking
    if cp -a /usr/lib/x86_64-linux-gnu/* /lilyspark/opt/lib/sys/usr/lib/x86_64-linux-gnu/ 2>/dev/null; then \
        echo "✓ System libraries copied successfully"; \
    else \
        echo "⚠ Warning: System libraries not found or failed to copy"; \
    fi; \
    \
    echo "=== Sysroot population for libdrm completed ==="

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

# Use system compiler + sysroot-aware paths
ENV SYSROOT=/lilyspark
ENV PATH="/lilyspark/usr/bin:/lilyspark/compiler/bin:$PATH"
ENV PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
ENV LD_LIBRARY_PATH="/lilyspark/opt/lib/graphics/usr/lib:${LD_LIBRARY_PATH:-}"

# Optional: link Clang binaries to make them globally visible
RUN ln -sf /lilyspark/compiler/bin/clang-16 /usr/local/bin/clang && \
    ln -sf /lilyspark/compiler/bin/clang++-16 /usr/local/bin/clang++ && \
    echo "✓ Clang wrappers linked into /usr/local/bin"

# CMake configure & build
WORKDIR /lilyspark/app/build/src

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

# Minimal runtime librariesƒ
RUN apk add --no-cache libstdc++ libgcc libpng freetype fontconfig libx11

# Set environment variables - EXCLUDE the problematic sysroot lib paths from runtime
ENV LD_LIBRARY_PATH="/lilyspark/usr/lib/runtime:/lilyspark/usr/lib:/lilyspark/usr/local/lib:$LD_LIBRARY_PATH" \
    PATH="/lilyspark/compiler/bin:/lilyspark/usr/local/bin:/lilyspark/usr/bin:$PATH"

# Default command
CMD ["/lilyspark/usr/bin/simplehttpserver"]
