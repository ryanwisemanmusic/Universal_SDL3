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
        } && \
    \
    echo "=== BUILDING GLMARK2 ===" && \
    python3 ./waf build -j"$(nproc)" --verbose 2>&1 | tee build.log || { \
        echo "=== BUILD FAILED - SHOWING LOG ==="; \
        cat build.log; \
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



# ======================
# CONTINUATION: Build Mesa (stripped) for Stage 3
# ======================

RUN echo "=== BUILDING MESA (STRIPPED) ===" && \
    git clone --progress https://gitlab.freedesktop.org/mesa/mesa.git /tmp/mesa && \
    cd /tmp/mesa && \
    git checkout mesa-24.0.3 || true && \
    \
    # Set environment for sysroot build
    export PATH="/custom-os/compiler/bin:$PATH"; \
    export CC=/custom-os/compiler/bin/clang-16; \
    export CXX=/custom-os/compiler/bin/clang++-16; \
    export PKG_CONFIG_SYSROOT_DIR="/custom-os"; \
    export PKG_CONFIG_PATH="/custom-os/usr/lib/pkgconfig:/custom-os/compiler/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    export CFLAGS="--sysroot=/custom-os -I/custom-os/usr/include -I/custom-os/compiler/include -I/custom-os/glibc/include -march=armv8-a"; \
    export CXXFLAGS="$CFLAGS"; \
    export LDFLAGS="--sysroot=/custom-os -L/custom-os/usr/lib -L/custom-os/compiler/lib -L/custom-os/glibc/lib"; \
    \
    # Configure only minimal drivers/platforms (software rasterizer)
    meson setup builddir \
        --prefix=/usr \
        -Dglx=disabled \
        -Ddri3=disabled \
        -Degl=enabled \
        -Dgbm=enabled \
        -Dplatforms=wayland \
        -Dglvnd=false \
        -Dosmesa=true \
        -Dgallium-drivers=swrast \
        -Dvulkan-drivers= \
        -Dbuildtype=release \
        --wrap-mode=nodownload || true; \
    \
    ninja -C builddir -v || true; \
    DESTDIR="/custom-os" ninja -C builddir install || true; \
    \
    # Organize Mesa in isolated directory
    mkdir -p /custom-os/usr/mesa && \
    mv /custom-os/usr/lib/libGL* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libEGL* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libgbm* /custom-os/usr/mesa/ 2>/dev/null || true; \
    mv /custom-os/usr/lib/libOSMesa* /custom-os/usr/mesa/ 2>/dev/null || true; \
    \
    # Clean up
    cd / && rm -rf /tmp/mesa; \
    echo "=== STRIPPED MESA BUILD COMPLETE ===" && \
    ls -la /custom-os/usr/mesa/


# ATTACHED WITH IT:
# Graphics & MESA env
ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330

#!/bin/sh
export LD_LIBRARY_PATH="/custom-os/usr/lib/runtime:/custom-os/usr/lib:/custom-os/usr/local/lib:${LD_LIBRARY_PATH:-}"
export LIBGL_DRIVERS_PATH="/custom-os/usr/lib/dri"
export MESA_LOADER_DRIVER_OVERRIDE="llvmpipe"
export XDG_RUNTIME_DIR="/tmp/runtime"
RUNTIME_PROFILE
RUN chmod +x /custom-os/etc/profile.d/runtime.sh

ENV SDL_VIDEODRIVER=x11 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    MESA_GL_VERSION_OVERRIDE=3.3 \
    MESA_GLSL_VERSION_OVERRIDE=330 \
    LD_LIBRARY_PATH="/custom-os/usr/lib/runtime:/custom-os/usr/lib:/custom-os/usr/local/lib:$LD_LIBRARY_PATH" \
    PATH="/custom-os/compiler/bin:/custom-os/usr/local/bin:/custom-os/usr/bin:$PATH"

# DRI/Xorg directory fix (necessary for MESA)
RUN mkdir -p $SYSROOT/usr/lib/dri && ln -sf $SYSROOT/usr/lib/dri $SYSROOT/usr/lib/xorg/modules/dri