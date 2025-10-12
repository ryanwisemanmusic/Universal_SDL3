cmake_minimum_required(VERSION 3.16)
project(SDL3HelloWorld)

set(CMAKE_CXX_STANDARD 17)

# Find packages
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL3 REQUIRED sdl3)
find_package(OpenGL REQUIRED)

add_executable(simplehttpserver main.cpp)

# Include directories
target_include_directories(simplehttpserver PRIVATE 
    ${SDL3_INCLUDE_DIRS}
    ${OPENGL_INCLUDE_DIRS}
)

# Link with ALL required libraries including Vulkan
target_link_libraries(simplehttpserver 
    ${SDL3_LIBRARIES}
    OpenGL::GL
    vulkan
)

# Add compiler definitions
target_compile_definitions(simplehttpserver PRIVATE
    SDL_VIDEO_OPENGL=1
    GL_GLEXT_PROTOTYPES=1
    HAS_VULKAN=1
)