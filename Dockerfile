# Single stage: Build and run in Alpine
FROM alpine:3.22

RUN mkdir -p \
    /lilyspark \
    # Essential dependencies
    /lilyspark/lib \
    # Essentials - no build from source
    /lilyspark/usr \
    /lilyspark/usr/local \
    /lilyspark/usr/local/lib \
    /lilyspark/usr/local/lib/display \
    /lilyspark/usr/local/lib/graphics \
    /lilyspark/usr/local/lib/graphics/mesa \
    /lilyspark/usr/local/lib/graphics/sdl3 \
    /lilyspark/usr/local/lib/graphics/vulkan \
# Install dependencies
RUN apk update && \
    apk add --no-cache \
    build-base cmake ninja git pkgconfig \
    sdl3-dev sdl3 \
    mesa mesa-dri-gallium mesa-gl mesa-egl mesa-gles mesa-demos \
    vulkan-loader vulkan-tools vulkan-headers mesa-vulkan-swrast \
    xvfb \
    libxkbcommon fontconfig ttf-dejavu bash \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

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