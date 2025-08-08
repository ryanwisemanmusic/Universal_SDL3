cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)

find_package(Boost REQUIRED COMPONENTS program_options)
find_package(SDL3 REQUIRED CONFIG)  # Use CONFIG mode to find static libs properly

set(PROJECT_ROOT "${CMAKE_SOURCE_DIR}/..")
add_executable(simplehttpserver ${PROJECT_ROOT}/main.cpp)

target_link_libraries(simplehttpserver
    PRIVATE
        ${Boost_LIBRARIES}
        SDL3::SDL3-static
)

target_include_directories(simplehttpserver PRIVATE ${Boost_INCLUDE_DIRS})

# Copy compile_commands.json to .vscode folder in PROJECT_ROOT
add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${PROJECT_ROOT}/.vscode/compile_commands.json
)
