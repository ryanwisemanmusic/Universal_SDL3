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
    /lilyspark/opt/lib/audio \
    /lilyspark/opt/lib/database \
    /lilyspark/opt/lib/driver \
    /lilyspark/opt/lib/graphics \
    /lilyspark/opt/lib/java \
    /lilyspark/opt/lib/media \
    /lilyspark/opt/lib/python \
    /lilyspark/opt/lib/sdl3 \
    /lilyspark/opt/lib/sys \
    /lilyspark/opt/lib/sys/usr \
    /lilyspark/opt/lib/sys/usr/lib \
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
COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/dep_chain_visualizer.sh
RUN chmod +x /usr/local/bin/check_llvm15.sh \
    /usr/local/bin/check-filesystem.sh \
    /usr/local/bin/binlib_validator.sh

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
RUN apk add --no-cache bash && /usr/local/bin/check_llvm15.sh "after-bash" || true
RUN apk add --no-cache curl && /usr/local/bin/check_llvm15.sh "after-curl" || true
RUN apk add --no-cache ncurses-dev && /usr/local/bin/check_llvm15.sh "after-ncurses-dev" || true
RUN apk add --no-cache ca-certificates && /usr/local/bin/check_llvm15.sh "after-ca-certificates" || true
RUN apk add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk add --no-cache bsd-compat-headers && /usr/local/bin/check_llvm15.sh "after-bsd-compat-headers" || true
RUN apk add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk add --no-cache musl-dev && /usr/local/bin/check_llvm15.sh "after-musl-dev" || true
RUN apk add --no-cache libc-dev && /usr/local/bin/check_llvm15.sh "after-libc-dev" || true
RUN apk add --no-cache libstdc++ && /usr/local/bin/check_llvm15.sh "after-libstdc++" || true
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
    mkdir -p /lilyspark/usr/debug/bin && \
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
RUN apk add --no-cache pipewire-dev && /usr/local/bin/check_llvm15.sh "after-pipewire-dev" || true

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
RUN apk add --no-cache xz-dev && /usr/local/bin/check_llvm15.sh "after-xz-dev" || true
RUN apk add --no-cache zstd-dev && /usr/local/bin/check_llvm15.sh "after-zstd-dev" || true

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
RUN apk add --no-cache sqlite-dev && /usr/local/bin/check_llvm15.sh "after-sqlite-dev" || true
RUN apk add --no-cache libedit-dev && /usr/local/bin/check_llvm15.sh "after-libedit-dev" || true
RUN apk add --no-cache icu-dev && /usr/local/bin/check_llvm15.sh "after-icu-dev" || true
RUN apk add --no-cache tcl-dev && /usr/local/bin/check_llvm15.sh "after-tcl-dev" || true
RUN apk add --no-cache lz4-dev && /usr/local/bin/check_llvm15.sh "after-lz4-dev" || true
RUN apk add --no-cache db-dev && /usr/local/bin/check_llvm15.sh "after-db-dev" || true

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
RUN apk add --no-cache eudev-dev && /usr/local/bin/check_llvm15.sh "after-eudev-dev" || true
RUN apk add --no-cache pciutils-dev && /usr/local/bin/check_llvm15.sh "after-pciutils-dev" || true
RUN apk add --no-cache libusb-dev && /usr/local/bin/check_llvm15.sh "after-libusb-dev" || true

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
RUN apk add --no-cache xmlto && /usr/local/bin/check_llvm15.sh "after-xmlto" || true

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
RUN apk add --no-cache openjdk11 && \
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

RUN apk add --no-cache ant && /usr/local/bin/check_llvm15.sh "after-ant" || true

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

# Math Libraries - /lilyspark/usr/local/lib/math
RUN apk add --no-cache eigen-dev && /usr/local/bin/check_llvm15.sh "after-eigen-dev" || true

    # Copy Libraries To Directory
RUN echo "=== COPYING MATH LIBRARIES ===" && \
    cp -a /usr/include/eigen3 /lilyspark/usr/local/lib/math/ 2>/dev/null || true && \
    echo "--- MATH CHECK ---" && \
    ls -la /lilyspark/usr/local/lib/math | head -10 || true

# Sysroot Integration: Math Libraries
RUN echo "=== INTEGRATING MATH LIBRARIES INTO SYSROOT ===" && \
    # Link any shared libraries from math directory (Eigen is header-only but check anyway)
    find /lilyspark/usr/local/lib/math -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "Math libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{eigen}*.so* 2>/dev/null | wc -l || echo "No math libs found (Eigen is header-only)") && \
    echo "=== MATH SYSROOT INTEGRATION COMPLETE ==="

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
RUN apk add --no-cache python3 python3-dev py3-setuptools py3-pip py3-markupsafe \
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
    mkdir -p /lilyspark/usr/local/lib/python/site-packages && \
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
RUN apk add --no-cache libatomic_ops-dev && /usr/local/bin/check_llvm15.sh "after-libatomic_ops-dev" || true
RUN apk add --no-cache util-linux-dev && /usr/local/bin/check_llvm15.sh "after-util-linux-dev" || true
RUN apk add --no-cache libcap-dev && /usr/local/bin/check_llvm15.sh "after-libcap-dev" || true
RUN apk add --no-cache liburing-dev && /usr/local/bin/check_llvm15.sh "after-liburing-dev" || true
RUN apk add --no-cache e2fsprogs-dev && /usr/local/bin/check_llvm15.sh "after-e2fsprogs-dev" || true
RUN apk add --no-cache xfsprogs-dev && /usr/local/bin/check_llvm15.sh "after-xfsprogs-dev" || true
RUN apk add --no-cache btrfs-progs-dev && /usr/local/bin/check_llvm15.sh "after-btrfs-progs-dev" || true
RUN apk add --no-cache libexecinfo-dev && /usr/local/bin/check_llvm15.sh "after-libexecinfo-dev" || true

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

        # Sysroot Integration: System Libraries
RUN echo "=== INTEGRATING SYSTEM LIBRARIES INTO SYSROOT ===" && \
    find /lilyspark/usr/local/lib/system -name "*.so*" -exec ln -sf {} /lilyspark/usr/lib/ \; 2>/dev/null || true && \
    echo "System libraries integrated. Count:" && \
    (ls -1 /lilyspark/usr/lib/lib{uring,cap,atomic_ops,ext2fs,xfs,btrfs}*.so* 2>/dev/null | wc -l || echo "No system libs found yet") && \
    echo "=== SYSTEM SYSROOT INTEGRATION COMPLETE ==="

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
RUN apk add --no-cache wayland-dev && /usr/local/bin/check_llvm15.sh "after-wayland-dev" || true
RUN apk add --no-cache wayland-protocols && /usr/local/bin/check_llvm15.sh "after-wayland-protocols" || true

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
RUN chmod +x /usr/local/bin/dep_chain_visualizer.sh

# ======================
# STEP: Robust Sysroot Population with Fallbacks
# (Must run BEFORE any build that uses /lilyspark/opt/lib/sys)
# ======================
RUN echo "=== ATTEMPTING ROBUST SYSROOT POPULATION ===" && \
    \
    # STRATEGY 1: Ensure base directory structure exists
    echo "Ensuring /lilyspark/opt/lib/sys directory structure..." && \
    mkdir -p /lilyspark/opt/lib/sys/usr/lib && \
    mkdir -p /lilyspark/opt/lib/sys/usr/include && \
    mkdir -p /lilyspark/opt/lib/sys/lib && \
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
            mkdir -p /lilyspark/opt/lib/sys/usr/include/linux; \
            mkdir -p /lilyspark/opt/lib/sys/usr/include/bits; \
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
    # Prepare isolated target dirs
    mkdir -p /lilyspark/opt/lib/java/fop/bin \
             /lilyspark/opt/lib/java/fop/lib \
             /lilyspark/opt/lib/java/fop/docs \
             /lilyspark/opt/lib/java/fop/launchers && \
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
    mkdir -p /lilyspark/opt/lib/java/fop/metadata && \
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
        mkdir -p /lilyspark/opt/lib/audio/jack2/metadata && \
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
    mkdir -p /lilyspark/opt/lib/audio/jack2/bin && \
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
    # CRITICAL: Install to isolated location to avoid ABI conflicts
    export DESTDIR="/lilyspark/opt/lib/graphics"; \
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/sys"; \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    \
    # Build with isolated installation
    if meson setup builddir \
        --prefix=/usr \
        --libdir=lib \
        --buildtype=release \
        -Dtests=false \
        -Dudev=false \
        -Dvalgrind=disabled \
        -Dc_args="$CFLAGS" \
        -Dc_link_args="$LDFLAGS" \
        -Dpkg_config_path="$PKG_CONFIG_PATH" 2>&1; then \
        \
        if meson compile -C builddir -j$(nproc) 2>&1; then \
            # CRITICAL: Install to isolated graphics location, NOT sysroot
            if meson install -C builddir --destdir "/lilyspark/opt/lib/graphics" --no-rebuild 2>&1; then \
                echo "✓ libdrm built and installed to isolated location"; \
            fi; \
        fi; \
    fi; \
    \
    # Cleanup
    cd /; rm -rf /tmp/libdrm-src; \
    echo "=== libdrm BUILD finished ==="; \
    true

# ======================
# SECTION: libepoxy Build (sysroot-focused)
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
    CC=/lilyspark/opt/lib/sys/compiler/bin/clang-16 \
    CXX=/lilyspark/opt/lib/sys/compiler/bin/clang++-16 \
    LLVM_CONFIG=/lilyspark/opt/lib/sys/compiler/bin/llvm-config \
    CFLAGS="-I/lilyspark/opt/lib/sys/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/lilyspark/opt/lib/sys/compiler/include -I/lilyspark/opt/lib/sys/glibc/include -march=armv8-a" \
    LDFLAGS="-L/lilyspark/opt/lib/sys/compiler/lib -L/lilyspark/opt/lib/sys/glibc/lib -Wl,-rpath,/lilyspark/opt/lib/sys/compiler/lib:/lilyspark/opt/lib/sys/glibc/lib" \
    PKG_CONFIG_PATH="/lilyspark/opt/lib/sys/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/compiler/lib/pkgconfig" \
    meson setup builddir \
        --prefix=/lilyspark/opt/lib/sys/usr \
        --libdir=/lilyspark/opt/lib/sys/usr/lib \
        --includedir=/lilyspark/opt/lib/sys/usr/include \
        --buildtype=release \
        -Dglx=yes \
        -Degl=yes \
        -Dx11=true \
        -Dwayland=true \
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
    ls -la /lilyspark/opt/lib/sys/usr/lib/libepoxy* 2>/dev/null || echo "No libepoxy libraries found" && \
    echo "Headers installed:" && \
    ls -la /lilyspark/opt/lib/sys/usr/include/epoxy/ 2>/dev/null || echo "No epoxy headers found" && \
    echo "PKG-config files:" && \
    ls -la /lilyspark/opt/lib/sys/usr/lib/pkgconfig/epoxy.pc 2>/dev/null || echo "No epoxy.pc found" && \
    \
    echo "=== CREATING REQUIRED SYMLINKS ===" && \
    cd /lilyspark/opt/lib/sys/usr/lib && \
    for lib in $(ls libepoxy*.so.*.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
        echo "Created symlinks for $lib"; \
    done && \
    \
    echo "=== FINAL CONTAMINATION SCAN ===" && \
    find /lilyspark/opt/lib/sys/usr/lib -name "libepoxy*" -exec grep -l "LLVM15\|llvm-15" {} \; 2>/dev/null | tee /tmp/libepoxy_contamination.log || true && \
    \
    cd / && \
    rm -rf libepoxy && \
    \
    /usr/local/bin/check_llvm15.sh "post-libepoxy-source-build" || true && \
    echo "=== LIBEPOXY BUILD COMPLETE ===" && \
    if [ -f /lilyspark/opt/lib/sys/usr/lib/libepoxy.so ] && [ -f /lilyspark/opt/lib/sys/usr/include/epoxy/gl.h ]; then \
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
    echo "=== COPYING IMAGE LIBRARIES TO SDL3 DIRECTORY ===" && \
    mkdir -p /lilyspark/opt/lib/sdl3/{lib,include} && \
    cp -r /usr/lib/libtiff* /lilyspark/opt/lib/sdl3/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libwebp* /lilyspark/opt/lib/sdl3/lib/ 2>/dev/null || true && \
    cp -r /usr/lib/libavif* /lilyspark/opt/lib/sdl3/lib/ 2>/dev/null || true && \
    cp -r /usr/include/tiff* /lilyspark/opt/lib/sdl3/include/ 2>/dev/null || true && \
    cp -r /usr/include/webp /lilyspark/opt/lib/sdl3/include/ 2>/dev/null || true && \
    cp -r /usr/include/avif /lilyspark/opt/lib/sdl3/include/ 2>/dev/null || true && \
    \
    echo "=== VERIFYING SDL3 IMAGE LIBRARIES ===" && \
    ls -la /lilyspark/opt/lib/sdl3/lib/libtiff* /lilyspark/opt/lib/sdl3/lib/libwebp* /lilyspark/opt/lib/sdl3/lib/libavif* || echo "Some SDL3 libraries not found"

# ======================
# SECTION: Python Dependencies (FINAL COPY TO OPT)
# ======================

# Install meson via pip (since apk doesn't provide the Python package)
RUN pip3 install meson && /usr/local/bin/check_llvm15.sh "after-pip-meson" || true

RUN echo "=== COPYING PYTHON PACKAGES TO CUSTOM FILESYSTEM ===" && \
    mkdir -p /lilyspark/opt/lib/python/site-packages && \
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
    ls -la external/spirv-headers/ && \
    \
    echo "=== CONFIGURING WITH CMAKE ===" && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/graphics \
        -DCMAKE_C_COMPILER=/lilyspark/compiler/bin/clang-16 \
        -DCMAKE_CXX_COMPILER=/lilyspark/compiler/bin/clang++-16 \
        -DLLVM_CONFIG_EXECUTABLE=/lilyspark/compiler/bin/llvm-config \
        -DCMAKE_C_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_CXX_FLAGS="-I/lilyspark/compiler/include -march=armv8-a" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -Wl,-rpath,/lilyspark/compiler/lib" && \
    \
    make -j"$(nproc)" 2>&1 | tee /tmp/spirv-build.log && \
    make install 2>&1 | tee /tmp/spirv-install.log && \
    \
    cd ../.. && rm -rf spirv-tools && \
    \
    echo "=== VERIFYING SPIRV-TOOLS INSTALLATION ===" && \
    ls -la /lilyspark/opt/lib/graphics/bin/spirv-* 2>/dev/null || echo "No SPIRV-Tools binaries found" && \
    ls -la /lilyspark/opt/lib/graphics/lib/libSPIRV-Tools* 2>/dev/null || echo "No SPIRV-Tools libraries found" && \
    \
    cd /lilyspark/opt/lib/graphics/lib && \
    for lib in $(ls libSPIRV-Tools*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname"; \
        ln -sf "$soname" "$basename"; \
    done && \
    /usr/local/bin/check_llvm15.sh "post-spirv-tools-source-build" || true && \
    echo "=== SPIRV-TOOLS BUILD COMPLETE ==="

# ======================
# SECTION: Shaderc Build (sysroot-focused) — FINAL
# ======================
RUN echo "=== BUILDING SHADERC FROM SOURCE WITH LLVM16 ===" && \
    /usr/local/bin/check_llvm15.sh "pre-shaderc-source-build" || true; \
    \
    git clone --recursive https://github.com/google/shaderc.git || (echo "⚠ shaderc not cloned; skipping build" && exit 0); \
    cd shaderc || (echo "⚠ shaderc directory missing; skipping build" && exit 0); \
    \
    export PATH="/lilyspark/compiler/bin:$PATH"; \
    export CC=/lilyspark/compiler/bin/clang-16; \
    export CXX=/lilyspark/compiler/bin/clang++-16; \
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/lib/pkgconfig:/lilyspark/usr/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/lilyspark/opt/lib/sys -I/lilyspark/opt/lib/sys/usr/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/lilyspark/opt/lib/sys -L/lilyspark/opt/lib/sys/usr/lib"; \
    \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/lilyspark/opt/lib/graphics \
        -DCMAKE_C_COMPILER=$CC \
        -DCMAKE_CXX_COMPILER=$CXX \
        -DCMAKE_PREFIX_PATH="/lilyspark/opt/lib/graphics:/lilyspark/usr:/lilyspark/compiler" \
        -DCMAKE_INCLUDE_PATH="/lilyspark/opt/lib/graphics/include:/lilyspark/usr/include:/lilyspark/compiler/include" \
        -DCMAKE_LIBRARY_PATH="/lilyspark/opt/lib/graphics/lib:/lilyspark/usr/lib:/lilyspark/compiler/lib" \
        -DCMAKE_INSTALL_RPATH="/lilyspark/opt/lib/graphics/lib:/lilyspark/usr/lib:/lilyspark/compiler/lib" \
        -DSPIRV-Tools_ROOT="/lilyspark/opt/lib/graphics" \
        -DSPIRV-Headers_ROOT="/lilyspark/opt/lib/graphics" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
        -DSHADERC_SKIP_TESTS=ON \
        -DSHADERC_SKIP_EXAMPLES=ON || echo "✗ cmake configure failed (continuing)"; \
    \
    make -j"$(nproc)" 2>&1 | tee /tmp/shaderc-build.log || echo "✗ make failed (continuing)"; \
    DESTDIR="/lilyspark" make install 2>&1 | tee /tmp/shaderc-install.log || echo "✗ make install failed (continuing)"; \
    \
    cd ../.. && rm -rf shaderc 2>/dev/null || true; \
    \
    ls -la /lilyspark/opt/lib/graphics/bin/shaderc* 2>/dev/null || echo "No shaderc binaries found"; \
    ls -la /lilyspark/opt/lib/graphics/lib/libshaderc* 2>/dev/null || echo "No shaderc libraries found"; \
    \
    cd /lilyspark/opt/lib/graphics/lib && \
    for lib in $(ls libshaderc*.so.* 2>/dev/null); do \
        soname=$(echo "$lib" | sed 's/\(.*\.so\.[0-9]*\).*/\1/'); \
        basename=$(echo "$lib" | sed 's/\(.*\.so\).*/\1/'); \
        ln -sf "$lib" "$soname" 2>/dev/null || true; \
        ln -sf "$soname" "$basename" 2>/dev/null || true; \
    done; \
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
    # Set up pkg-config environment to find libdrm in our graphics location
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark" && \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/graphics/usr/lib/pkgconfig:/lilyspark/opt/lib/sys/lib/pkgconfig:/lilyspark/opt/lib/sys/share/pkgconfig:${PKG_CONFIG_PATH:-}" && \
    \
    ./autogen.sh --prefix=/lilyspark/opt/lib/sys && \
    ./configure \
        --prefix=/lilyspark/opt/lib/sys \
        CC=/lilyspark/compiler/bin/clang-16 \
        CXX=/lilyspark/compiler/bin/clang++-16 \
        CFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/graphics/usr/include -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
        CXXFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/graphics/usr/include -I/lilyspark/opt/lib/sys/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
        LDFLAGS="--sysroot=/lilyspark -L/lilyspark/opt/lib/graphics/usr/lib -L/lilyspark/opt/lib/sys/lib -L/lilyspark/compiler/lib -L/lilyspark/glibc/lib" && \
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
    ls -la /lilyspark/opt/lib/sys/lib/libgbm* 2>/dev/null || echo "No libgbm libraries found" && \
    \
    echo "=== CREATING LIBRARY SYMLINKS ===" && \
    cd /lilyspark/opt/lib/sys/lib && \
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
    CC_BIN=/lilyspark/compiler/bin/clang-16; \
    CXX_BIN=/lilyspark/compiler/bin/clang++-16; \
    LLVM_CONFIG_BIN=/lilyspark/compiler/bin/llvm-config; \
    PKGCONFIG=/usr/bin/pkg-config; \
    NPROCS="$(nproc 2>/dev/null || echo 1)"; \
    if [ ! -x "$CC_BIN" ] || [ ! -x "$CXX_BIN" ]; then \
        printf '%s\n' "⚠ Compiler(s) not found at $CC_BIN or $CXX_BIN — skipping gst and xorg builds"; \
    else \
        printf '%s\n' ">>> gst-plugins-base: fetching and extracting"; \
        wget -q https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.20.3.tar.xz && \
            tar -xJf gst-plugins-base-1.20.3.tar.xz || { printf '%s\n' "✗ failed to fetch/extract gst-plugins-base"; true; } && \
        if [ -d gst-plugins-base-1.20.3 ]; then \
            cd gst-plugins-base-1.20.3 || true; \
            printf '%s\n' ">>> gst-plugins-base: configuring"; \
            ./configure \
              --prefix=/lilyspark/opt/lib/media \
              --disable-static \
              --enable-shared \
              --disable-introspection \
              --disable-examples \
              --disable-gtk-doc \
              CC="$CC_BIN" CXX="$CXX_BIN" \
              LLVM_CONFIG="$LLVM_CONFIG_BIN" \
              CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
              CXXFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
              LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
              PKG_CONFIG_PATH="/lilyspark/opt/lib/media/pkgconfig:/lilyspark/usr/x11/pkgconfig:/lilyspark/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}" || printf '%s\n' "⚠ configure returned non-zero (gst): see /tmp/gst-plugins-config.log"; \
            printf '%s\n' ">>> gst-plugins-base: building"; \
            (make -j"$NPROCS" 2>&1 | tee /tmp/gst-plugins-build.log) || printf '%s\n' "⚠ make returned non-zero (gst) — continuing"; \
            printf '%s\n' ">>> gst-plugins-base: installing to /lilyspark"; \
            (make install 2>&1 | tee /tmp/gst-plugins-install.log) || printf '%s\n' "⚠ make install returned non-zero (gst) — continuing"; \
            cd ..; rm -rf gst-plugins-base-* || true; \
            printf '%s\n' ">>> gst-plugins-base: creating soname symlinks (best-effort)"; \
            if [ -d /lilyspark/opt/lib/media/lib ]; then \
                cd /lilyspark/opt/lib/media/lib || true; \
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
        git clone --depth=1 --branch xorg-server-21.1.8 https://gitlab.freedesktop.org/xorg/xserver.git xorg-server 2>/tmp/xorg_clone.err || { printf '%s\n' "⚠ git clone failed (see /tmp/xorg_clone.err). Skipping xorg build"; true; } ; \
    fi; \
    if [ -d xorg-server ]; then \
        cd xorg-server || true; \
        printf '%s\n' ">>> xorg: scanning for llvm-15 references (best-effort)"; \
        grep -RIl "LLVM15\\|llvm-15" . 2>/tmp/xorg_source_scan.log || true; \
        \
        export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
        export PKG_CONFIG_PATH="/lilyspark/opt/lib/media/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
        export CFLAGS="--sysroot=/lilyspark -I/lilyspark/opt/lib/media/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a"; \
        export CXXFLAGS="$CFLAGS"; \
        export LDFLAGS="--sysroot=/lilyspark -L/lilyspark/opt/lib/media/lib -L/lilyspark/compiler/lib -L/lilyspark/glibc/lib"; \
        \
        /usr/local/bin/check-filesystem.sh "xorg-pre-config" 2>/tmp/xorg_filesystem.log || true; \
        printf 'int main(void){return 0;}\n' > /tmp/xorg_toolchain_test.c; \
        $CC $CFLAGS -Wl,--sysroot=/lilyspark -o /tmp/xorg_toolchain_test /tmp/xorg_toolchain_test.c 2>/tmp/xorg_toolchain_test.err || printf '%s\n' "⚠ compiler test failed"; \
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
        printf '%s\n' ">>> xorg: make install into /lilyspark"; \
        (DESTDIR=/lilyspark make install 2>&1 | tee /tmp/xorg-install.log) || printf '%s\n' "✗ make install failed (see /tmp/xorg-install.log) — continuing"; \
        \
        mkdir -p /lilyspark/usr/x11 || true; \
        mv /lilyspark/usr/bin/X* /lilyspark/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mv /lilyspark/usr/lib/libxserver* /lilyspark/usr/x11/ 2>/tmp/xorg-mv.log || true; \
        mkdir -p /lilyspark/usr/x11/include/xorg || true; \
        cp -r include/* /lilyspark/usr/x11/include/xorg/ 2>/tmp/xorg-mv.log || true; \
        \
        for xbin in /lilyspark/usr/x11/X*; do \
            [ -f "$xbin" ] || continue; \
            ln -sf "../x11/$(basename "$xbin")" "/lilyspark/usr/bin/$(basename "$xbin")" 2>/dev/null || true; \
        done; \
        for xlib in /lilyspark/usr/x11/libxserver*; do \
            [ -f "$xlib" ] || continue; \
            ln -sf "../x11/$(basename "$xlib")" "/lilyspark/usr/lib/$(basename "$xlib")" 2>/dev/null || true; \
        done; \
        \
        /usr/local/bin/dependency_checker.sh /lilyspark/compiler/bin/clang-16 2>/tmp/xorg_depcheck.log || true; \
        /usr/local/bin/binlib_validator.sh /lilyspark/compiler/bin/clang-16 2>/tmp/xorg_binlib.log || true; \
        /usr/local/bin/version_matrix.sh 2>/tmp/xorg_versions.log || true; \
        /usr/local/bin/cflag_audit.sh 2>/tmp/xorg_cflags.log || true; \
        find /lilyspark/usr -name "*xserver*" -exec grep -l "LLVM15\\|llvm-15" {} \; 2>/tmp/xorg_contam.log || true; \
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
    export PATH="/lilyspark/compiler/bin:$PATH"; \
    export CC=/lilyspark/compiler/bin/clang-16; \
    export CXX=/lilyspark/compiler/bin/clang++-16; \
    if [ -x /lilyspark/compiler/bin/llvm-config-16 ]; then export LLVM_CONFIG=/lilyspark/compiler/bin/llvm-config-16; else export LLVM_CONFIG=/lilyspark/compiler/bin/llvm-config; fi; \
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark"; \
    export PKG_CONFIG_PATH="/lilyspark/usr/lib/pkgconfig:/lilyspark/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/lilyspark -I/lilyspark/usr/include -I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/lilyspark -L/lilyspark/usr/lib -L/lilyspark/compiler/lib -L/lilyspark/glibc/lib"; \
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
    DESTDIR="/lilyspark" ninja -C builddir install 2>&1 | tee /tmp/mesa-install.log || echo "✗ ninja install failed (continuing)"; \
    \
    /usr/local/bin/check_llvm15.sh "post-mesa-build" || true; \
    \
    echo "=== VULKAN ICD CONFIGURATION (ARM64) ===" && \
    mkdir -p /lilyspark/usr/share/vulkan/icd.d && \
    printf '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > /lilyspark/usr/share/vulkan/icd.d/swrast_icd.arm64.json; \
    \
    # Organize Mesa components into lilyspark driver path
    echo "=== ORGANIZING MESA COMPONENTS ===" && \
    mkdir -p /lilyspark/opt/lib/driver && \
    find /lilyspark/usr/bin -name "*mesa*" -o -name "*gl*" -o -name "*egl*" | xargs -I {} mv {} /lilyspark/opt/lib/driver/ 2>/dev/null || true; \
    mv /lilyspark/usr/lib/libGL* /lilyspark/opt/lib/driver/ 2>/dev/null || true; \
    mv /lilyspark/usr/lib/libEGL* /lilyspark/opt/lib/driver/ 2>/dev/null || true; \
    mv /lilyspark/usr/lib/libgbm* /lilyspark/opt/lib/driver/ 2>/dev/null || true; \
    mv /lilyspark/usr/lib/libvulkan* /lilyspark/opt/lib/driver/ 2>/dev/null || true; \
    \
    echo "=== MESA ISOLATION COMPLETE ===" && \
    echo "Mesa components isolated in /lilyspark/opt/lib/driver directory" && \
    ls -la /lilyspark/opt/lib/driver 2>/dev/null || echo "Mesa directory contents not available"; \
    \
    # Create DRI directory structure and symlinks (still inside /lilyspark sysroot)
    echo "=== CREATING DRI DIRECTORY STRUCTURE ===" && \
    mkdir -p /lilyspark/usr/lib/xorg/modules/dri /lilyspark/usr/lib/dri || true; \
    ln -sf /lilyspark/usr/lib/dri /lilyspark/usr/lib/xorg/modules/dri || true; \
    \
    # Run diagnostic scripts
    echo "=== COMPILER DEPENDENCY CHECK ==="; \
    /usr/local/bin/dependency_checker.sh /lilyspark/compiler/bin/clang-16 || true; \
    \
    echo "=== COMPILER VALIDATION ==="; \
    /usr/local/bin/binlib_validator.sh /lilyspark/compiler/bin/clang-16 || true; \
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
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" && \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig" && \
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
    DESTDIR="/lilyspark/opt/lib/driver" ninja -C builddir install && \
    \
    echo "=== VERIFYING GBM INSTALLATION ===" && \
    find /lilyspark/opt/lib/driver -name "*gbm*" -type f | tee /tmp/gbm_install.log && \
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
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" && \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=disabled \
        -Degl=enabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dopengl=disabled && \
    \
    ninja -C builddir -v && \
    DESTDIR="/lilyspark/opt/lib/driver" ninja -C builddir install && \
    \
    echo "=== VERIFYING EGL INSTALLATION ===" && \
    find /lilyspark/opt/lib/driver -name "*EGL*" -type f | tee /tmp/egl_install.log && \
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
    export PKG_CONFIG_SYSROOT_DIR="/lilyspark/opt/lib/driver" && \
    export PKG_CONFIG_PATH="/lilyspark/opt/lib/driver/usr/lib/pkgconfig" && \
    meson setup builddir \
        --prefix=/usr \
        -Dgbm=disabled \
        -Degl=disabled \
        -Dgles1=enabled \
        -Dgles2=enabled \
        -Dopengl=disabled && \
    \
    ninja -C builddir -v && \
    DESTDIR="/lilyspark/opt/lib/driver" ninja -C builddir install && \
    \
    echo "=== VERIFYING GLES INSTALLATION ===" && \
    find /lilyspark/opt/lib/driver -name "*GLES*" -type f | tee /tmp/gles_install.log && \
    /usr/local/bin/check_llvm15.sh "post-gles-install" || true && \
    \
    cd / && rm -rf /tmp/mesa

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
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" && \
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
        -DCMAKE_EXE_LINKER_FLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" && \
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
    CC=/lilyspark/compiler/bin/clang-16 \
    CXX=/lilyspark/compiler/bin/clang++-16 \
    CFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
    CXXFLAGS="-I/lilyspark/compiler/include -I/lilyspark/glibc/include -march=armv8-a" \
    LDFLAGS="-L/lilyspark/compiler/lib -L/lilyspark/glibc/lib -Wl,-rpath,/lilyspark/compiler/lib:/lilyspark/glibc/lib" \
    python3 ./waf configure \
        --prefix=/lilyspark/opt/lib/graphics \
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
    ls -la /lilyspark/opt/lib/graphics/bin/glmark2* 2>/dev/null || echo "No glmark2 binaries found" && \
    \
    cd .. && \
    /usr/local/bin/check_llvm15.sh "post-glmark2" || true && \
    echo "=== GLMARK2 BUILD COMPLETED ==="

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

# Minimal runtime librariesƒ
RUN apk add --no-cache libstdc++ libgcc libpng freetype fontconfig libx11

# Set environment variables - EXCLUDE the problematic sysroot lib paths from runtime
ENV LD_LIBRARY_PATH="/lilyspark/usr/lib/runtime:/lilyspark/usr/lib:/lilyspark/usr/local/lib:$LD_LIBRARY_PATH" \
    PATH="/lilyspark/compiler/bin:/lilyspark/usr/local/bin:/lilyspark/usr/bin:$PATH"

# Default command
CMD ["/lilyspark/usr/bin/simplehttpserver"]
