cmake_minimum_required(VERSION 3.16)
project(SDL3HelloWorld)

set(CMAKE_CXX_STANDARD 17)

# Find packages
find_package(PkgConfig REQUIRED)

# SDL3
pkg_check_modules(SDL3 REQUIRED sdl3)

# SDL3_image - UPDATED: Use different approach if pkg-config fails
pkg_check_modules(SDL3_IMAGE QUIET SDL3_image)

if(NOT SDL3_IMAGE_FOUND)
    # Fallback: manually find SDL3_image
    message(WARNING "SDL3_image not found via pkg-config, trying manual discovery...")
    
    # Try to find the library manually
    find_library(SDL3_IMAGE_LIBRARY
        NAMES SDL3_image
        PATHS /usr/local/lib /usr/lib
        NO_DEFAULT_PATH
    )
    
    find_path(SDL3_IMAGE_INCLUDE_DIR
        NAMES SDL3_image/SDL_image.h
        PATHS /usr/local/include /usr/include
        NO_DEFAULT_PATH
    )
    
    if(SDL3_IMAGE_LIBRARY AND SDL3_IMAGE_INCLUDE_DIR)
        message(STATUS "Found SDL3_image manually: ${SDL3_IMAGE_LIBRARY}")
        set(SDL3_IMAGE_LIBRARIES ${SDL3_IMAGE_LIBRARY})
        set(SDL3_IMAGE_INCLUDE_DIRS ${SDL3_IMAGE_INCLUDE_DIR})
        set(SDL3_IMAGE_FOUND TRUE)
    else()
        message(FATAL_ERROR "SDL3_image not found! Check your installation.")
    endif()
endif()

find_package(OpenGL REQUIRED)

add_executable(simplehttpserver main.cpp)

# Include directories
target_include_directories(simplehttpserver PRIVATE 
    ${SDL3_INCLUDE_DIRS}
    ${SDL3_IMAGE_INCLUDE_DIRS}
    ${OPENGL_INCLUDE_DIRS}
)

# Link with ALL required libraries including Vulkan and SDL3_image
target_link_libraries(simplehttpserver 
    ${SDL3_LIBRARIES}
    ${SDL3_IMAGE_LIBRARIES}
    OpenGL::GL
    vulkan
)

# Add compiler definitions
target_compile_definitions(simplehttpserver PRIVATE
    SDL_VIDEO_OPENGL=1
    GL_GLEXT_PROTOTYPES=1
    HAS_VULKAN=1
)