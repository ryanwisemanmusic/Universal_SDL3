cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Generate compile_commands.json for IntelliSense (ONLY ADDITION)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

#find_package(SDL3 REQUIRED)
# -------------------------------
# Simple Hello World executable
# -------------------------------
add_executable(simplehttpserver
    /lilyspark/app/src/main.cpp
)

# So like is this actually valid or am I just being fucking stupid????
#target_link_libraries(${simplehttpserver} PRIVATE SDL3::SDL3)

# No external dependencies needed for Hello World
target_compile_definitions(simplehttpserver PRIVATE
    HELLO_WORLD_BUILD=1
)

# Installation
install(TARGETS simplehttpserver
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib/static
)
