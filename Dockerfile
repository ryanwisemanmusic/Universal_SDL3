FROM alpine:3.17.0 AS build
RUN apk update && \
    apk add --no-cache \
        build-base \
        cmake \
        boost1.80-dev

WORKDIR /simplehttpserver
COPY . .

WORKDIR /simplehttpserver/build

RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=1 ../src && \
    cmake --build . --parallel 8 && \
    cp compile_commands.json ../

FROM alpine:3.17.0
RUN apk update && \
    apk add --no-cache \
        libstdc++=12.2.1_git20220924-r4 \
        boost1.80-program_options=1.80.0-r3 \
        boost1.80-system=1.80.0-r3 \
        boost1.80-filesystem=1.80.0-r3

RUN addgroup -S shs && adduser -S shs -G shs
USER shs

COPY --chown=shs:shs --from=build \
    /simplehttpserver/build/simplehttpserver \
    ./app/

ENTRYPOINT [ "./app/simplehttpserver" ]
