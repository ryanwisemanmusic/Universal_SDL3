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
    /lilyspark/usr/local/lib/audio \
    /lilyspark/usr/local/lib/audio/codec \
    /lilyspark/usr/local/lib/audio/codec/bin \
    /lilyspark/usr/local/lib/audio/codec/lib \
    /lilyspark/usr/local/lib/audio/codec/share \
    /lilyspark/usr/local/lib/audio/codec/pkgconfig \
    /lilyspark/usr/local/lib/audio/formats \
    /lilyspark/usr/local/lib/audio/formats/bin \
    /lilyspark/usr/local/lib/audio/formats/lib \
    /lilyspark/usr/local/lib/audio/formats/share \
    /lilyspark/usr/local/lib/audio/formats/pkgconfig \
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
    /lilyspark/usr/local/lib/graphics/vulkan/pkgconfig \
    /lilyspark/usr/local/lib/network \
    /lilyspark/usr/local/lib/network/streaming \
    /lilyspark/usr/local/lib/network/streaming/bin \
    /lilyspark/usr/local/lib/network/streaming/lib \
    /lilyspark/usr/local/lib/network/streaming/share \
    /lilyspark/usr/local/lib/network/streaming/pkgconfig \
    /lilyspark/usr/local/lib/system/encoding \
    /lilyspark/usr/local/lib/system/audio/framework \
    /lilyspark/usr/local/lib/system/audio/framework/bin \
    /lilyspark/usr/local/lib/system/audio/framework/lib \
    /lilyspark/usr/local/lib/system/audio/framework/share \
    /lilyspark/usr/local/lib/system/audio/framework/pkgconfig \
    /lilyspark/usr/local/lib/system/audio/pkgconfig \
    /lilyspark/usr/local/lib/system/encoding/bin \
    /lilyspark/usr/local/lib/system/encoding/lib \
    /lilyspark/usr/local/lib/system/encoding/share \
    /lilyspark/usr/local/lib/system/encoding/pkgconfig \
    /lilyspark/usr/local/lib/system/graphics \
    /lilyspark/usr/local/lib/system/graphics/bin \
    /lilyspark/usr/local/lib/system/graphics/lib \
    /lilyspark/usr/local/lib/system/graphics/share \
    /lilyspark/usr/local/lib/system/graphics/pkgconfig \
    /lilyspark/usr/local/lib/system/utilities \
    /lilyspark/usr/local/lib/system/utilities/bin \
    /lilyspark/usr/local/lib/system/utilities/lib \
    /lilyspark/usr/local/lib/system/utilities/share \
    /lilyspark/usr/local/lib/system/utilities/pkgconfig \
    /lilyspark/usr/local/lib/video \
    /lilyspark/usr/local/lib/video/bin \
    /lilyspark/usr/local/lib/video/lib \
    /lilyspark/usr/local/lib/video/share \
    /lilyspark/usr/local/lib/video/pkgconfig \
    /lilyspark/usr/local/lib/video/codec \
    /lilyspark/usr/local/lib/video/codec/bin \
    /lilyspark/usr/local/lib/video/codec/lib \
    /lilyspark/usr/local/lib/video/codec/share \
    /lilyspark/usr/local/lib/video/codec/pkgconfig \
    /lilyspark/usr/local/lib/video/ffmpeg \
    /lilyspark/usr/local/lib/video/ffmpeg/bin \
    /lilyspark/usr/local/lib/video/ffmpeg/lib \
    /lilyspark/usr/local/lib/video/ffmpeg/share \
    /lilyspark/usr/local/lib/video/ffmpeg/pkgconfig \
    /lilyspark/usr/local/lib/video/formats \
    /lilyspark/usr/local/lib/video/formats/bin \
    /lilyspark/usr/local/lib/video/formats/lib \
    /lilyspark/usr/local/lib/video/formats/share \
    /lilyspark/usr/local/lib/video/formats/pkgconfig \
    /lilyspark/usr/local/lib/video/hardware \
    /lilyspark/usr/local/lib/video/hardware/bin \
    /lilyspark/usr/local/lib/video/hardware/lib \
    /lilyspark/usr/local/lib/video/hardware/share \
    /lilyspark/usr/local/lib/video/hardware/pkgconfig

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

# /lilyspark/usr/local/lib/audio/codec packages
RUN apk add --no-cache alsa-lib-dev ladspa-dev lame-dev libopenmpt-dev \
    libvorbis-dev opus-dev pulseaudio-dev soxr-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*asound*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*ladspa*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*mp3lame*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*openmpt*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*vorbis*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*opus*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*pulse*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*soxr*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*alsa*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*pulse*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*alsa*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*ladspa*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*lame*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*openmpt*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vorbis*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vorbisenc*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vorbisfile*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*opus*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*pulse*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*soxr*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/codec/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/audio/codec/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/audio/codec/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/audio/codec/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/audio/formats packages
RUN apk add --no-cache libsrt-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*srt*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/formats/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*srt*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/formats/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*srt*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/audio/formats/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/audio/formats/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/audio/formats/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/audio/formats/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/graphics/image packages
RUN apk add --no-cache libpng-dev libjpeg-turbo-dev libwebp-dev tiff-dev zlib-dev imlib2-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Copy image format libraries to sysroot
RUN find /usr/lib -name "libpng*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libjpeg*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libwebp*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libtiff*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "libz*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true && \
    find /usr/lib -name "imlib2*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/lib/ 2>/dev/null || true
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
RUN apk add --no-cache vulkan-loader vulkan-loader-dev vulkan-tools vulkan-headers mesa-vulkan-swrast \
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

# /lilyspark/usr/local/lib/network/streaming packages
RUN apk add --no-cache librist-dev libssh-dev zeromq-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*rist*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*ssh*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*zmq*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*rist*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*ssh*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*zmq*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*librist*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libssh*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*zeromq*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libzmq*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/network/streaming/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/network/streaming/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/network/streaming/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/network/streaming/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/system/audio/framework
RUN apk add --no-cache lilv-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*lilv*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/audio/framework/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*lilv*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/audio/framework/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*lilv*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/audio/framework/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/system/audio/framework/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/system/audio/framework/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/system/audio/framework/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/system/encoding packages
RUN apk add --no-cache bzip2-dev nasm openssl-dev perl-dev zlib-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*bz2*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*ssl*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*crypto*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*perl*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*z*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*bzip2*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/bin/ 2>/dev/null || true && \
    cp /usr/bin/nasm /lilyspark/usr/local/lib/system/encoding/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*openssl*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*perl*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*bz2*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*openssl*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libssl*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libcrypto*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*zlib*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/encoding/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/system/encoding/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/system/encoding/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/system/encoding/lib/pkgconfig:${PKG_CONFIG_PATH}"
#
#
#

# /lilyspark/usr/local/lib/system/graphics packages
RUN apk add --no-cache libtheora-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*theora*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/graphics/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*theora*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/graphics/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*theora*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/graphics/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/system/graphics/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/system/graphics/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/system/graphics/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/system/utilities packages
RUN apk add --no-cache coreutils \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*coreutils*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "[" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "base64" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "basename" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "cat" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "chmod" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "cp" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "cut" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "date" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "dd" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "df" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "dir" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "echo" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "false" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "ln" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "ls" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "mkdir" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "mktemp" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "mv" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "printf" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "pwd" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "rm" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "rmdir" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "sleep" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "sync" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "tee" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "test" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "touch" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true && \
    find /usr/bin -name "true" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*coreutils*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/system/utilities/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/system/utilities/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/system/utilities/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/system/utilities/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/fonts packages
RUN apk add --no-cache fontconfig fontconfig-dev freetype-dev fribidi-dev ttf-dejavu \
    harfbuzz-dev libass-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*fontconfig*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*freetype*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*fribidi*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*harfbuzz*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*ass*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*font*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/bin/ 2>/dev/null || true && \
    cp -r /usr/share/fonts /lilyspark/usr/local/lib/fonts/share/ 2>/dev/null || true && \
    cp -r /usr/share/fontconfig /lilyspark/usr/local/lib/fonts/share/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*fontconfig*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*freetype*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*fribidi*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*harfbuzz*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libass*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/fonts/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/fonts/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/fonts/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/fonts/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/video/codec packages
RUN apk add --no-cache aom-dev dav1d-dev rav1e-dev x264-dev x265-dev xvidcore-dev \
    libvpx-dev libwebp-dev vidstab-dev zimg-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*aom*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*dav1d*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*rav1e*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*x264*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*x265*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*xvidcore*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*vpx*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*webp*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*vidstab*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*zimg*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*aom*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*dav1d*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*rav1e*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*x264*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*x265*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*aom*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*dav1d*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*rav1e*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*x264*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*x265*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*xvidcore*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vpx*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*webp*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vidstab*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*zimg*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/codec/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/video/codec/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/video/codec/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/video/codec/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/video/hardware packages
RUN apk add --no-cache libdrm-dev libva-dev libvdpau-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*drm*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*va*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*vdpau*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*drm*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*va*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*vdpau*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*libdrm*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libva*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*vdpau*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/hardware/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/video/hardware/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/video/hardware/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/video/hardware/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/video/formats packages
RUN apk add --no-cache libbluray-dev libplacebo-dev libxfixes-dev v4l-utils-dev \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*bluray*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*placebo*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*xfixes*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*v4l*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*bluray*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*placebo*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/bin/ 2>/dev/null || true && \
    find /usr/bin -name "*v4l*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/bin/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*bluray*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libplacebo*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*xfixes*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*v4l*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/formats/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/video/formats/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/video/formats/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/video/formats/lib/pkgconfig:${PKG_CONFIG_PATH}"

#
#
#

# /lilyspark/usr/local/lib/video/ffmpeg packages
RUN apk add --no-cache ffmpeg-dev ffmpeg-libs \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

# Sysroot integration
RUN find /usr/lib -name "*avcodec*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*avformat*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*avutil*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*swscale*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*swresample*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*avdevice*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*avfilter*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true && \
    find /usr/lib -name "*postproc*" \( -name "*.so*" -o -name "*.a" \) -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/ 2>/dev/null || true

# Copy binary paths
RUN find /usr/bin -name "*ffmpeg*" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/bin/ 2>/dev/null || true && \
    find /usr/share -name "*ffmpeg*" -type d | xargs -I {} cp -r {} /lilyspark/usr/local/lib/video/ffmpeg/share/ 2>/dev/null || true

# pkgconfig stuff
RUN find /usr/lib -name "*avcodec*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*avformat*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*avutil*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*swscale*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*swresample*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*avdevice*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*avfilter*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*postproc*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libx264*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true && \
    find /usr/lib -name "*libx265*.pc" -type f | xargs -I {} cp {} /lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig/ 2>/dev/null || true

# ENV setup
ENV PATH="/lilyspark/usr/local/lib/video/ffmpeg/bin:${PATH}"
ENV LD_LIBRARY_PATH="/lilyspark/usr/local/lib/video/ffmpeg/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="/lilyspark/usr/local/lib/video/ffmpeg/lib/pkgconfig:${PKG_CONFIG_PATH}"

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

# Vulkan Symlink
RUN ln -sf /usr/lib/libvulkan.so.1 /usr/lib/libvulkan.so && \
    ln -sf /usr/lib/libvulkan.so.1.4.313 /usr/lib/libvulkan.so.1

CMD ["./build/simplehttpserver"]