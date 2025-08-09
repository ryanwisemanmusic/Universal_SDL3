# Stage: base deps
FROM ubuntu:22.04 AS base-deps
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ca-certificates \
    git \
    build-essential \
    cmake \
    pkg-config \
    libboost-program-options-dev \
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxrender-dev \
    libxfixes-dev \
    libxcursor-dev \
    libxi-dev \
    libxinerama-dev \
    libxdamage-dev \
    libxshmfence-dev \
    libxcb1-dev \
    mesa-common-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libosmesa6-dev \
    libgbm-dev \
    libwayland-dev \
    wayland-protocols \
    libasound2-dev \
    libpulse-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage: build SDL3 once
FROM base-deps AS sdl3-build
WORKDIR /deps
RUN git clone --depth=1 https://github.com/libsdl-org/SDL.git SDL3 && \
    mkdir -p SDL3/build && cd SDL3/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_INSTALL_PREFIX=/usr/local \
         -DSDL_STATIC=ON \
         -DSDL_SHARED=OFF \
         -DSDL_VIDEO=ON \
         -DSDL_X11=ON \
         -DSDL_WAYLAND=ON \
         -DSDL_OPENGL=ON \
         -DSDL_OPENGLES=ON \
         -DSDL_RENDER=ON \
         -DSDL_AUDIO=ON && \
    make -j"$(nproc)" && make install

# Stage: build the app using SDL3 installed in /usr/local
FROM sdl3-build AS app-build
WORKDIR /app
COPY . .
WORKDIR /app/build
RUN cmake -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
         ../src && \
    cmake --build . --parallel "$(nproc)"

# Stage: debug image (optional tools) - copies SDL3 and app
FROM base-deps AS debug
COPY --from=sdl3-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver
RUN apt-get update && apt-get install -y \
    mesa-utils \
    x11-apps \
    strace \
    gdb \
    && rm -rf /var/lib/apt/lists/*

# Stage: runtime
FROM ubuntu:22.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgcc-s1 \
    libboost-program-options1.74.0 \
    libx11-6 \
    libxext6 \
    libxrandr2 \
    libxrender1 \
    libxfixes3 \
    libxcursor1 \
    libxi6 \
    libxinerama1 \
    libxdamage1 \
    libxshmfence1 \
    libxcb1 \
    mesa-utils \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libegl1-mesa \
    libgles2-mesa \
    libosmesa6 \
    libgbm1 \
    libglu1-mesa \
    libwayland-client0 \
    libasound2 \
    libpulse0 \
    strace \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=sdl3-build /usr/local /usr/local
COPY --from=app-build /app/build/simplehttpserver /app/simplehttpserver

RUN groupadd -g 1000 shs || true && \
    useradd -u 1000 -g 1000 -m -s /bin/bash shs || true && \
    chown -R shs:shs /app /usr/local

ENV SDL_VIDEODRIVER=x11
USER shs
WORKDIR /app
CMD ["/app/simplehttpserver"]
