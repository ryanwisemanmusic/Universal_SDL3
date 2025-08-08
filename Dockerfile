FROM alpine:3.17 AS build

RUN apk add --no-cache \
    build-base cmake git pkgconf boost1.80-dev \
    libx11-dev libxext-dev libxrandr-dev libxrender-dev \
    libxfixes-dev libxcursor-dev libxi-dev libxinerama-dev \
    libxscrnsaver-dev mesa-dev wayland-dev wayland-protocols-dev \
    libxkbcommon-dev

WORKDIR /deps
RUN git clone --depth=1 https://github.com/libsdl-org/SDL.git SDL3 && \
    mkdir SDL3/build && cd SDL3/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DSDL_STATIC=ON -DSDL_SHARED=OFF \
             -DSDL_VIDEO=ON -DSDL_X11=ON -DSDL_WAYLAND=ON && \
    make -j$(nproc) && make install

WORKDIR /app
COPY . .

WORKDIR /app/build
RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
          ../src && \
    cmake --build . --parallel $(nproc)

# Stage 2: Runtime environment
FROM alpine:3.17

RUN apk add --no-cache \
    libstdc++ \
    boost1.80-program_options \
    libx11 libxext libxrandr libxrender libxfixes \
    libxcursor libxi libxinerama mesa mesa-dri-gallium \
    wayland libxkbcommon

RUN addgroup -S shs && adduser -S shs -G shs
USER shs

COPY --from=build /app/build/simplehttpserver /app/
WORKDIR /app
ENTRYPOINT ["./simplehttpserver"]
