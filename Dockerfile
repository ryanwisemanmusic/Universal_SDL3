# Single stage: Build and run in Alpine
FROM alpine:3.22

RUN mkdir -p \
    /lilyspark \
    /lilyspark/lib/bin \
    /lilyspark/lib/lib \
    /lilyspark/lib/share \
    /lilyspark/lib/pkgconfig \
    /lilyspark/usr \
    /lilyspark/usr/local/bin \
    /lilyspark/usr/local \
    /lilyspark/usr/local/lib \
    /lilyspark/usr/local/lib/display \
    /lilyspark/usr/local/lib/display/bin \
    /lilyspark/usr/local/lib/display/lib \
    /lilyspark/usr/local/lib/display/share \
    /lilyspark/usr/local/lib/display/pkgconfig \
    /lilyspark/usr/local/lib/fonts \
    /lilyspark/usr/local/lib/fonts/bin \
    /lilyspark/usr/local/lib/fonts/lib \
    /lilyspark/usr/local/lib/fonts/share \
    /lilyspark/usr/local/lib/fonts/pkgconfig \
    /lilyspark/usr/local/lib/graphics \
    /lilyspark/usr/local/lib/graphics/image \
    /lilyspark/usr/local/lib/graphics/image/bin \
    /lilyspark/usr/local/lib/graphics/image/lib \
    /lilyspark/usr/local/lib/graphics/image/share \
    /lilyspark/usr/local/lib/graphics/image/pkgconfig \
    /lilyspark/usr/local/lib/graphics/mesa \
    /lilyspark/usr/local/lib/graphics/mesa/bin \
    /lilyspark/usr/local/lib/graphics/mesa/lib \
    /lilyspark/usr/local/lib/graphics/mesa/share \
    /lilyspark/usr/local/lib/graphics/mesa/pkgconfig \
    /lilyspark/usr/local/lib/graphics/sdl3 \
    /lilyspark/usr/local/lib/graphics/sdl3/bin \
    /lilyspark/usr/local/lib/graphics/sdl3/lib \
    /lilyspark/usr/local/lib/graphics/sdl3/share \
    /lilyspark/usr/local/lib/graphics/sdl3/pkgconfig \
    /lilyspark/usr/local/lib/graphics/vulkan \
    /lilyspark/usr/local/lib/graphics/vulkan/bin \
    /lilyspark/usr/local/lib/graphics/vulkan/lib \
    /lilyspark/usr/local/lib/graphics/vulkan/share \
    /lilyspark/usr/local/lib/graphics/vulkan/pkgconfig

# Install dependencies

# /lilyspark/lib packages
RUN apk add --no-cache build-base bash cmake ninja git pkgconfig samurai curl ca-certificates \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*.a" -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /lib -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true

# CMake setup
RUN mkdir -p /lilyspark/lib/share && \
    cp -r /usr/share/cmake* /lilyspark/lib/share/ 2>/dev/null || true && \
    cp /usr/bin/cmake /lilyspark/lib/bin/ 2>/dev/null || true && \
    cp /usr/bin/ctest /lilyspark/lib/bin/ 2>/dev/null || true
    
# Symbolic links
RUN cd /lilyspark/lib && \
    for lib in libstdc++.so.*; do [ -f "$lib" ] && ln -sf "$lib" "${lib%.*}"; done 2>/dev/null || true && \
    ln -sf libgcc_s.so.1 libgcc_s.so 2>/dev/null || true && \
    ln -sf libc.musl-*.so.1 libc.so 2>/dev/null || true

# Copy binary paths
RUN cp /usr/bin/ninja /lilyspark/lib/bin/ 2>/dev/null || true && \
    cp /usr/bin/pkg-config /lilyspark/lib/bin/ 2>/dev/null || true && \
    cp /usr/bin/git /lilyspark/lib/bin/ 2>/dev/null || true && \
    cp /bin/bash /lilyspark/lib/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*.pc" -type f | xargs -I {} cp {} /lilyspark/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/share -name "*.pc" -type f | xargs -I {} cp {} /lilyspark/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/lib/bin:$PATH"
ENV LD_LIBRARY_PATH="/lilyspark/lib"
ENV PKG_CONFIG_PATH="/lilyspark/lib/pkgconfig"

#
#
#

# /lilyspark/usr/local/lib/graphics/image packages
RUN apk add --no-cache libpng-dev libjpeg-turbo-dev libwebp-dev tiff-dev zlib-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Copy image format libraries to sysroot
RUN find /usr/lib -name "libpng*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libjpeg*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libwebp*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libtiff*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libz*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true
#
#
#


# /lilyspark/usr/local/lib/graphics/sdl3 packages
RUN apk add --no-cache sdl3-dev sdl3 sdl3_ttf sdl3_ttf-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# SDL3_Image Build-From Source
RUN cd /tmp && \
    wget https://github.com/libsdl-org/SDL_image/releases/download/release-3.2.4/SDL3_image-3.2.4.tar.gz && \
    tar -xzf SDL3_image-3.2.4.tar.gz && \
    cd SDL3_image-3.2.4 && \
    cmake -B build -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build -j$(nproc) && \
    cmake --install build && \
    cd / && rm -rf /tmp/SDL3_image*

# Sysroot integration
RUN find /usr/lib -name "*sdl3*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*SDL3_image*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*SDL3_ttf*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/ 2>/dev/null || true && \
    find /usr/local/lib -name "*sdl3*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*sdl3*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/bin/ 2>/dev/null || true && \
    find /usr/share -name "*sdl3*" -type d | xargs -I {} cp -r {} /lilyspark/usr/local/lib/graphics/sdl3/share/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*sdl3*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*SDL3_image*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*SDL3_ttf*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/local/lib -name "*sdl3*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/local/lib/pkgconfig -name "*SDL3_image*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig/ 2>/dev/null || true
    
# ENV setup
ENV PATH="/lilyspark/usr/local/lib/graphics/sdl3/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/graphics/sdl3/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/graphics/sdl3/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/graphics/mesa packages
RUN apk add --no-cache mesa mesa-dri-gallium mesa-gl mesa-egl mesa-gles mesa-demos \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*mesa*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/lib/ && \
    find /usr/lib -name "*mesa*" -name "*.a" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/lib/ && \
    find /usr/lib -name "*EGL*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/lib/ && \
    find /usr/lib -name "*GL*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/lib/

# Copy binary paths
RUN find /usr/bin -name "*mesa*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/bin/ && \
    find /usr/bin -name "*gl*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/mesa/bin/ && \
    find /usr/share -name "*mesa*" -type d | xargs -I {} cp -r {} /lilyspark/usr/local/lib/graphics/mesa/share/

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/graphics/mesa/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/graphics/mesa/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/graphics/mesa/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/graphics/vulkan packages
RUN apk add --no-cache vulkan-loader vulkan-tools vulkan-headers mesa-vulkan-swrast \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*vulkan*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/vulkan/lib/ && \
    find /usr/lib -name "*vulkan*" -name "*.a" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/vulkan/lib/ && \
    find /usr/lib -name "*VkLayer*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/vulkan/lib/

# Copy binary paths
RUN find /usr/bin -name "*vulkan*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/graphics/vulkan/bin/ && \
    find /usr/share -name "*vulkan*" -type d | xargs -I {} cp -r {} /lilyspark/usr/local/lib/graphics/vulkan/share/

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/graphics/vulkan/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/graphics/vulkan/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/graphics/vulkan/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/display packages
RUN apk add --no-cache xvfb libxkbcommon \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*xkb*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/display/lib/ && \
    find /usr/lib -name "*X11*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/display/lib/

# Copy binary paths
RUN cp /usr/bin/Xvfb /lilyspark/usr/local/lib/display/bin/ && \
    find /usr/bin -name "*xkb*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/display/bin/ && \
    find /usr/share -name "*xkb*" -type d | xargs -I {} cp -r {} /lilyspark/usr/local/lib/display/share/

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/display/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/display/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/display/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/fonts packages
RUN apk add --no-cache fontconfig ttf-dejavu \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*font*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ && \
    find /usr/lib -name "*freetype*" -name "*.so*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/

# Copy binary paths
RUN find /usr/bin -name "*font*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/bin/ && \
    cp -r /usr/share/fonts /lilyspark/usr/local/lib/fonts/share/ && \
    cp -r /usr/share/fontconfig /lilyspark/usr/local/lib/fonts/share/

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/fonts/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/fonts/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/fonts/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# ENV variables - GRAPHICS
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe
ENV MESA_LOADER_DRIVER_OVERRIDE=swrast
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
ENV DISPLAY=:99

# Create runtime directories
RUN mkdir -p /tmp/runtime-root && \
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    chmod 0700 /tmp/runtime-root

WORKDIR /app

COPY main.cpp .
COPY CMakeLists.txt .

# Vulkan Symlink
RUN ln -sf /usr/lib/libvulkan.so.1 /usr/lib/libvulkan.so && \
    ln -sf /usr/lib/libvulkan.so.1.4.313 /usr/lib/libvulkan.so.1

RUN mkdir build && cd build && cmake .. && make

COPY fb-wrapper.sh .
RUN chmod +x fb-wrapper.sh

ENTRYPOINT ["./fb-wrapper.sh"]
CMD ["./build/simplehttpserver"]