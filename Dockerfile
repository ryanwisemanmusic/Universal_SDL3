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

# create a reusable verbose checker for LLVM-15
RUN cat > /usr/local/bin/check_llvm15.sh <<'SH' && chmod +x /usr/local/bin/check_llvm15.sh
#!/bin/sh
set -eu

STAGE="${1:-unknown-stage}"
OUT="/tmp/llvm15_debug_${STAGE}.log"
echo "=== check_llvm15: stage=${STAGE} timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >"$OUT"

# 1) find files
echo ">> find libLLVM-15 / libclang-15 files (if any)" | tee -a "$OUT"
find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null | tee -a "$OUT" || true

# 2) who-owns each file
echo "" | tee -a "$OUT"
echo ">> apk owners (for each file found):" | tee -a "$OUT"
find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null \
  | while read -r f; do
      printf "FILE: %s\n" "$f" | tee -a "$OUT"
      apk info --who-owns "$f" 2>/dev/null | tee -a "$OUT" || echo "  (no owning package)" | tee -a "$OUT"
    done

# 3) show if llvm15-libs is installed (package info)
echo "" | tee -a "$OUT"
echo ">> apk info llvm15-libs (installed?)" | tee -a "$OUT"
if apk info llvm15-libs >/dev/null 2>&1; then
  apk info llvm15-libs 2>/dev/null | tee -a "$OUT"
  echo "QUICK: llvm15-libs INSTALLED" | tee -a "$OUT"
else
  echo "QUICK: llvm15-libs NOT INSTALLED" | tee -a "$OUT"
fi

# 4) packages that explicitly depend on llvm15-libs (reverse deps)
echo "" | tee -a "$OUT"
echo ">> Packages that declare 'llvm15-libs' as a dependency (reverse deps):" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
  if apk info -R "$pkg" 2>/dev/null | grep -q '^llvm15-libs$'; then
    echo "$pkg" | tee -a "$OUT"
  fi
done | sort -u | tee -a "$OUT" || true

# 5) packages that provide libLLVM-15 (via apk -L)
echo "" | tee -a "$OUT"
echo ">> Installed packages that list libLLVM-15 in their file list (apk info -L):" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
  if apk info -L "$pkg" 2>/dev/null | grep -q 'libLLVM-15'; then
    echo "$pkg" | tee -a "$OUT"
  fi
done | sort -u | tee -a "$OUT" || true

# 6) scan ELF DT_NEEDED entries for libLLVM-15 references (heavier but useful)
echo "" | tee -a "$OUT"
echo ">> ELF objects depending on libLLVM-15 (readelf -d | grep NEEDED):" | tee -a "$OUT"
# check .so files and executables under /usr, but keep it bounded
find /usr -type f \( -name '*.so*' -o -perm /111 \) -print0 2>/dev/null \
  | xargs -0 -n1 sh -c 'readelf -d "$0" 2>/dev/null | grep -q "NEEDED.*libLLVM-15" && printf "%s\n" "$0"' 2>/dev/null \
  | tee -a "$OUT" || true

# 7) detect multiple LLVM major versions present
echo "" | tee -a "$OUT"
echo ">> Major LLVM versions present on disk (quick):" | tee -a "$OUT"
for v in 15 16 14; do
  if find /usr -name "libLLVM-${v}*.so*" -print -quit 2>/dev/null | grep -q .; then
    echo "Found LLVM ${v}" | tee -a "$OUT"
  fi
done

# 8) small heuristic: check for duplicate "CommandLine" option registration strings
echo "" | tee -a "$OUT"
echo ">> Heuristic: count occurrences of suspicious option names in LLVM libs (e.g. 'use-dbg-addr')" | tee -a "$OUT"
grep -a -o 'use-dbg-addr' /usr/lib/*/libLLVM-* /usr/lib/libLLVM-* 2>/dev/null | wc -l | tee -a "$OUT"

# 9) final verdict line (one-liner summary)
echo "" | tee -a "$OUT"
if grep -q 'libLLVM-15' "$OUT" 2>/dev/null; then
  echo "FINAL_VERDICT: LLVM15 FOUND in stage=${STAGE}" | tee -a "$OUT"
else
  echo "FINAL_VERDICT: LLVM15 NOT FOUND in stage=${STAGE}" | tee -a "$OUT"
fi

# always print log to stdout for Docker log capture
echo "" && echo "=== /tmp/llvm15_debug_${STAGE}.log ===" && cat "$OUT" || true
SH

# Step-by-step checks
RUN set -eux; \
    echo "=== Step 1: Installing bash, ca-certificates, git ==="; \
    apk add --no-cache bash ca-certificates git; \
    echo "=== Checking for LLVM/Clang after Step 1 ==="; \
    find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null || true

RUN set -eux; \
    echo "=== Step 2: Installing build-base ==="; \
    apk add --no-cache build-base; \
    echo "=== Checking for LLVM/Clang after Step 2 ==="; \
    find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null || true

RUN set -eux; \
    echo "=== Step 3: Installing linux-headers, musl-dev ==="; \
    apk add --no-cache linux-headers musl-dev; \
    echo "=== Checking for LLVM/Clang after Step 3 ==="; \
    find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null || true

RUN set -eux; \
    echo "=== Step 4: Installing cmake, ninja, pkgconf ==="; \
    apk add --no-cache cmake ninja pkgconf; \
    echo "=== Checking for LLVM/Clang after Step 4 ==="; \
    find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null || true

RUN set -eux; \
    echo "=== Step 5: Installing python3, py3-pip ==="; \
    apk add --no-cache python3 py3-pip; \
    echo "=== Checking for LLVM/Clang after Step 5 ==="; \
    find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null || true

# Final big install (all remaining deps)
RUN apk add --no-cache \
    vulkan-headers \
    vulkan-loader \
    vulkan-tools \
    freetype-dev \
    fontconfig-dev \
    libxcomposite-dev \
    libxinerama-dev \
    libxi-dev \
    libxcursor-dev \
    libxrandr-dev \
    libxshmfence-dev \
    libxxf86vm-dev \
    alsa-lib-dev \
    pulseaudio-dev \
    bsd-compat-headers \
    xf86-video-fbdev \
    xf86-video-dummy \
    glslang \
    net-tools \
    iproute2

RUN apk add --no-cache bash ca-certificates git && \
    /usr/local/bin/check_llvm15.sh base-step1 | tee /tmp/llvm15_base_step1.log

RUN apk add --no-cache bash ca-certificates git

RUN set -eux; \
    echo "=== Checking for llvm15-libs ==="; \
    if apk info llvm15-libs >/dev/null 2>&1; then echo "llvm15-libs is installed"; else echo "llvm15-libs NOT installed"; fi; \
    echo "=== Verifying installed packages ==="; \
    for pkg in bash ca-certificates git; do \
        if apk info --installed "$pkg" >/dev/null 2>&1; then \
            echo "Package $pkg is installed"; \
        else \
            echo "Package $pkg is NOT installed"; \
        fi; \
    done; \
    echo "=== Listing installed packages with 'llvm15' in name ==="; \
    apk info --installed | grep llvm15 || echo "No packages with llvm15 in name installed"

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

RUN apk add --no-cache bash ca-certificates git

# Stage: build core libraries
FROM base-deps AS libs-build
WORKDIR /build

# I will see exactly where this path is
RUN find /usr -name "libLLVM*.so*" -o -name "libclang*.so*" 2>/dev/null
# Install build dependencies with debugging tools
RUN apk add --no-cache \
    llvm16-dev llvm16-libs clang16 \
    m4 \
    bison \
    flex \
    zlib-dev \
    expat-dev \
    ncurses-dev \
    alsa-lib-dev \
    libx11-dev \
    xorg-server-dev \
    xf86driproto \
    xf86vidmodeproto \
    glproto \
    dri2proto \
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
    python3-dev \
    py3-setuptools \
    jpeg-dev \
    libpng-dev \
    libxkbcommon-dev \
    strace \
    file \
    tree \
    shaderc-dev \
    vulkan-tools \
    libpcap-dev \
    gst-plugins-base-dev \
    v4l-utils-dev

# Let's see what is triggering the LLVM 15 reason, so we can clone whatever library and prevent us from gathering LLVM 15
RUN set -eux; \
    echo "=== Checking for llvm15-libs ==="; \
    apk info llvm15-libs && echo "llvm15-libs is installed" || echo "llvm15-libs NOT installed"; \
    echo "=== Checking for xorg-server-dev ==="; \
    apk info xorg-server-dev && echo "xorg-server-dev is installed" || echo "xorg-server-dev NOT installed"; \
    \
    echo "=== Verifying all required packages installed ==="; \
    for pkg in llvm16-dev llvm16-libs clang16 m4 bison flex zlib-dev expat-dev ncurses-dev alsa-lib-dev libx11-dev xorg-server-dev xf86driproto xf86vidmodeproto glproto dri2proto libxext-dev libxrandr-dev libxrender-dev libxfixes-dev libxcursor-dev libxi-dev libxinerama-dev libxdamage-dev libxshmfence-dev libxcb-dev libxxf86vm-dev wayland-dev wayland-protocols libdrm-dev python3-dev py3-setuptools jpeg-dev libpng-dev libxkbcommon-dev strace file tree shaderc-dev vulkan-tools libpcap-dev gst-plugins-base-dev v4l-utils-dev; do \
        if apk info --installed "$pkg" >/dev/null 2>&1; then \
            echo "Package $pkg is installed"; \
        else \
            echo "Package $pkg is NOT installed"; \
        fi; \
    done; \
    \
    echo "=== Listing installed packages with 'llvm15' in name ==="; \
    apk info --installed | grep llvm15 || echo "No packages with llvm15 in name installed"; \
    echo "=== Listing installed packages with 'xorg-server-dev' in name ==="; \
    apk info --installed | grep xorg-server-dev || echo "No packages with xorg-server-dev in name installed"

# Install Python dependencies for Mesa and glmark2
RUN pip install --no-cache-dir meson==1.4.0 mako==1.3.3

# Set verbose build environment
ENV MESON_LOG_LEVEL=debug \
    NINJA_STATUS="[%f/%t] %es "

# Replace the existing Mesa build with this ARM-optimized version:
RUN git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git && \
    cd mesa && \
    git checkout mesa-24.0.3 && \
    echo "=== MESA BUILD CONFIGURATION (ARM64) ===" && \
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
        -Dc_args="-v -Wno-error -march=armv8-a" \
        -Dcpp_args="-v -Wno-error -march=armv8-a" && \
    echo "=== MESA BUILD LOGS ===" && \
    cat builddir/meson-logs/meson-log.txt && \
    echo "=== MESA CONFIGURATION ===" && \
    meson configure builddir/ && \
    echo "=== STARTING NINJA BUILD (ARM64) ===" && \
    ninja -C builddir -v install && \
    echo "=== VULKAN ICD CONFIGURATION (ARM64) ===" && \
    mkdir -p /usr/share/vulkan/icd.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"libvulkan_swrast.so","api_version":"1.3.0"}}' > /usr/share/vulkan/icd.d/swrast_icd.arm64.json && \
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
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
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
    make -j"$(nproc)" install

# before Vulkan-Headers clone/build
RUN /usr/local/bin/check_llvm15.sh before-vulkan-build | tee /tmp/llvm15_before_vulkan.log

RUN git clone --progress https://github.com/KhronosGroup/Vulkan-Headers.git && \
    cd Vulkan-Headers && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a" \
          -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a" && \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Headers && \
    /usr/local/bin/check_llvm15.sh after-vulkan-headers | tee /tmp/llvm15_after_vulkan_headers.log

# Vulkan-Loader
RUN /usr/local/bin/check_llvm15.sh before-vulkan-loader | tee /tmp/llvm15_before_vulkan_loader.log

RUN git clone --progress https://github.com/KhronosGroup/Vulkan-Loader.git && \
    cd Vulkan-Loader && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_C_FLAGS="-v -Wno-error -march=armv8-a" \
          -DCMAKE_CXX_FLAGS="-v -Wno-error -march=armv8-a" \
          -DBUILD_TESTS=OFF -DVULKAN_HEADERS_INSTALL_DIR=/usr/local && \
    make -j"$(nproc)" VERBOSE=1 install && \
    cd ../.. && rm -rf Vulkan-Loader && \
    /usr/local/bin/check_llvm15.sh after-vulkan-loader | tee /tmp/llvm15_after_vulkan_loader.log


RUN apk add --no-cache \
    vulkan-headers vulkan-loader vulkan-tools freetype-dev ... && \
    /usr/local/bin/check_llvm15.sh base-post-vulkan-packages | tee /tmp/llvm15_base_post_vulkan.log


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
    llvm16-libs \
    xf86-video-fbdev \
    xf86-video-dummy 


RUN set -eux; \
    echo "=== Checking for llvm15-libs ==="; \
    if apk info llvm15-libs >/dev/null 2>&1; then echo "llvm15-libs is installed"; else echo "llvm15-libs NOT installed"; fi; \
    echo "=== Verifying installed packages ==="; \
    for pkg in bash ca-certificates git; do \
        if apk info --installed "$pkg" >/dev/null 2>&1; then \
            echo "Package $pkg is installed"; \
        else \
            echo "Package $pkg is NOT installed"; \
        fi; \
    done; \
    echo "=== Listing installed packages with 'llvm15' in name ==="; \
    apk info --installed | grep llvm15 || echo "No packages with llvm15 in name installed"

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
    vulkan-loader \
    vulkan-tools \
    freetype \
    fontconfig \
    libx11 \
    libxcomposite \
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
    mesa-vulkan-swrast \
    glu \
    llvm16-libs

RUN set -eux; \
    echo "=== Checking for llvm15-libs ==="; \
    if apk info llvm15-libs >/dev/null 2>&1; then echo "llvm15-libs is installed"; else echo "llvm15-libs NOT installed"; fi; \
    echo "=== Verifying installed packages ==="; \
    for pkg in bash ca-certificates git; do \
        if apk info --installed "$pkg" >/dev/null 2>&1; then \
            echo "Package $pkg is installed"; \
        else \
            echo "Package $pkg is NOT installed"; \
        fi; \
    done; \
    echo "=== Listing installed packages with 'llvm15' in name ==="; \
    apk info --installed | grep llvm15 || echo "No packages with llvm15 in name installed"

# Final detailed debug check before finishing image
RUN set -eux; \
    echo "=== Final global check for LLVM 15 libs and package origins ==="; \
    find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null | tee /tmp/llvm15_files.txt || true; \
    if [ ! -s /tmp/llvm15_files.txt ]; then \
        echo "No LLVM 15 libs present."; \
    else \
        echo "LLVM 15 libs found:"; \
        cat /tmp/llvm15_files.txt; \
        echo "Owning packages (from file owners):"; \
        while read -r f; do apk info --who-owns "$f" || true; done < /tmp/llvm15_files.txt | sort -u; \
        echo "Installed packages referencing llvm15 (direct depends or libs):"; \
        apk info --installed | while read -r pkg; do \
            if apk info -R "$pkg" 2>/dev/null | grep -q '^llvm15-libs$'; then \
                echo "Direct depends-on: $pkg"; \
            elif apk info -L "$pkg" 2>/dev/null | grep -q 'libLLVM-15'; then \
                echo "Provides libLLVM-15: $pkg"; \
            fi; \
        done | sort -u; \
        echo "Is llvm15-libs installed?"; \
        apk info llvm15-libs || echo "llvm15-libs not installed"; \
        echo "Reverse dependencies of llvm15-libs:"; \
        apk info --depends llvm15-libs || echo "No dependencies found for llvm15-libs"; \
        echo "Full list of installed packages with llvm15 in the name:"; \
        apk info --installed | grep llvm15 || echo "No packages with llvm15 in name installed"; \
    fi | tee /tmp/llvm15_debug.log; \
    cat /tmp/llvm15_debug.log

RUN /usr/local/bin/check_llvm15.sh final-runtime | tee /tmp/llvm15_final_runtime.log


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
    MESA_GLSL_VERSION_OVERRIDE=330 

ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/usr/glibc-compat/lib

USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]
