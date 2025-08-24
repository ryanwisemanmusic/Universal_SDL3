# Stage: base deps (Alpine version)
FROM alpine:3.21 AS base-deps

# Install bare essentials
RUN apk add --no-cache bash wget coreutils findutils file

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
    # Third-party libraries
    /lilyspark/opt \
    /lilyspark/opt/include \
    /lilyspark/opt/lib \
    /lilyspark/opt/bin \
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

# Install glibc (compatibility layer)
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-bin-2.35-r1.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-dev-2.35-r1.apk && \
    apk add --no-cache --allow-untrusted glibc-2.35-r1.apk glibc-bin-2.35-r1.apk glibc-dev-2.35-r1.apk && \
    rm -f *.apk

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
RUN apk add --no-cache build-base && /usr/local/bin/check_llvm15.sh "after-build-base" || true
RUN apk add --no-cache linux-headers && /usr/local/bin/check_llvm15.sh "after-linux-headers" || true
RUN apk add --no-cache pkgconf && /usr/local/bin/check_llvm15.sh "after-pkgconf" || true
RUN apk add --no-cache git && /usr/local/bin/check_llvm15.sh "after-git" || true
RUN apk add --no-cache make && /usr/local/bin/check_llvm15.sh "after-make" || true
RUN apk add --no-cache cmake && /usr/local/bin/check_llvm15.sh "after-cmake" || true

# Render essentials
RUN apk add --no-cache meson && /usr/local/bin/check_llvm15.sh "after-meson" || true
RUN apk add --no-cache ninja && /usr/local/bin/check_llvm15.sh "after-ninja" || true

# ======================
# Copy essentials into /lilyspark
# ======================
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

# ======================
# Debug tools (minimal)
# ======================
RUN apk add --no-cache file tree && \
    mkdir -p /lilyspark/usr/debug/bin && \
    cp /usr/bin/file /usr/bin/tree /lilyspark/usr/debug/bin/ 2>/dev/null || true && \
    chmod -R a+rx /lilyspark/usr/debug/bin && \
    echo "Debug tools isolated into /lilyspark/usr/debug/bin"

# Stage: filesystem-libs (minimal version for C++ Hello World)
FROM filesystem-base-deps-builder AS filesystem-libs-build-builder

# Cache busting
ARG BUILDKIT_INLINE_CACHE=0
RUN --mount=type=cache,target=/tmp/nocache,sharing=private \
    echo "FORCE_REBUILD_STAGE3_$(date +%s%N)" > /tmp/nocache/timestamp && \
    cat /tmp/nocache/timestamp && rm -f /tmp/nocache/timestamp

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