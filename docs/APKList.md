alsa-lib-dev
autoconf
automake
bash 
bison
bsd-compat-headers
build-base
bzip2-dev
ca-certificates
cairo-dev
clang16
cmake
coreutils
curl
db-dev
eudev-dev
expat-dev
file
findutils
flac-dev
flex
fontconfig-dev
freetype-dev
gettext-dev
git
glslang
gtk+3-dev
harfbuzz-dev
icu-dev
jpeg-dev
libavif
libc-dev
libedit-dev
libjpeg-turbo-dev
libmodplug-dev
libogg-dev
libpng-dev
libsamplerate-dev
libstdc++
libtiff
libtool
libusb-dev
libvorbis-dev
libwebp
linux-headers
linux-tools-dev
llvm16-dev
llvm16-libs
lz4-dev
m4
make
meson
mpg123-dev
musl-dev
ncurses-dev
ninja
openssl-dev
opusfile-dev
pciutils-dev
pipewire-dev
pixman-dev
pkgconf
pkgconf-dev
portaudio-dev
pulseaudio-dev
readline-dev
sndio-dev
sqlite-dev
tar
tcl-dev
tiff-dev
tree
util-macros
valgrind-dev
vulkan-headers
vulkan-loader
vulkan-tools
wget
xmlto
xz-dev
zlib-dev
zstd-dev


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
COPY setup-scripts/sgid_suid_scanner.sh /usr/local/bin/sgid_suid_scanner.sh
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker.sh
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix.sh
COPY setup-scripts/cflag_audit.sh /usr/local/bin/cflag_audit.sh
RUN chmod +x /usr/local/bin/dep_chain_visualizer.sh \
    /usr/local/bin/sgid_suid_scanner.sh \
    /usr/local/bin/dependency_checker.sh \
    /usr/local/bin/version_matrix.sh \
    /usr/local/bin/cflag_audit.sh
