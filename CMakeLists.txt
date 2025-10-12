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

# FFmpeg libraries - ADD THIS SECTION
pkg_check_modules(LIBAVCODEC QUIET libavcodec)
pkg_check_modules(LIBAVFORMAT QUIET libavformat)
pkg_check_modules(LIBAVUTIL QUIET libavutil)
pkg_check_modules(LIBSWSCALE QUIET libswscale)
pkg_check_modules(LIBSWRESAMPLE QUIET libswresample)

# Fallback for FFmpeg if pkg-config fails
if(NOT LIBAVCODEC_FOUND)
    message(WARNING "FFmpeg not found via pkg-config, trying manual discovery...")
    
    # Find FFmpeg libraries manually
    find_library(LIBAVCODEC_LIB NAMES avcodec PATHS /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBAVFORMAT_LIB NAMES avformat PATHS /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBAVUTIL_LIB NAMES avutil PATHS /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBSWSCALE_LIB NAMES swscale PATHS /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBSWRESAMPLE_LIB NAMES swresample PATHS /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    
    find_path(LIBAVCODEC_INCLUDE_DIR libavcodec/avcodec.h PATHS /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBAVFORMAT_INCLUDE_DIR libavformat/avformat.h PATHS /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBAVUTIL_INCLUDE_DIR libavutil/avutil.h PATHS /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBSWSCALE_INCLUDE_DIR libswscale/swscale.h PATHS /usr/local/include /usr/include NO_DEFAULT_PATH)
    
    if(LIBAVCODEC_LIB AND LIBAVCODEC_INCLUDE_DIR)
        set(LIBAVCODEC_LIBRARIES ${LIBAVCODEC_LIB})
        set(LIBAVCODEC_INCLUDE_DIRS ${LIBAVCODEC_INCLUDE_DIR})
        set(LIBAVCODEC_FOUND TRUE)
    endif()
    
    if(LIBAVFORMAT_LIB AND LIBAVFORMAT_INCLUDE_DIR)
        set(LIBAVFORMAT_LIBRARIES ${LIBAVFORMAT_LIB})
        set(LIBAVFORMAT_INCLUDE_DIRS ${LIBAVFORMAT_INCLUDE_DIR})
        set(LIBAVFORMAT_FOUND TRUE)
    endif()
    
    if(LIBAVUTIL_LIB AND LIBAVUTIL_INCLUDE_DIR)
        set(LIBAVUTIL_LIBRARIES ${LIBAVUTIL_LIB})
        set(LIBAVUTIL_INCLUDE_DIRS ${LIBAVUTIL_INCLUDE_DIR})
        set(LIBAVUTIL_FOUND TRUE)
    endif()
    
    if(LIBSWSCALE_LIB AND LIBSWSCALE_INCLUDE_DIR)
        set(LIBSWSCALE_LIBRARIES ${LIBSWSCALE_LIB})
        set(LIBSWSCALE_INCLUDE_DIRS ${LIBSWSCALE_INCLUDE_DIR})
        set(LIBSWSCALE_FOUND TRUE)
    endif()
    
    if(LIBSWRESAMPLE_LIB)
        set(LIBSWRESAMPLE_LIBRARIES ${LIBSWRESAMPLE_LIB})
        set(LIBSWRESAMPLE_FOUND TRUE)
    endif()
endif()

# Check if essential FFmpeg components are found
if(NOT LIBAVCODEC_FOUND OR NOT LIBAVFORMAT_FOUND OR NOT LIBAVUTIL_FOUND)
    message(WARNING "Essential FFmpeg components not found. Video playback may not work.")
else()
    message(STATUS "FFmpeg support enabled")
    # Add FFmpeg compiler definitions
    add_definitions(-DHAS_FFMPEG=1)
endif()

find_package(OpenGL REQUIRED)

add_executable(simplehttpserver main.cpp)

# Include directories - UPDATED: Add FFmpeg includes
target_include_directories(simplehttpserver PRIVATE 
    ${SDL3_INCLUDE_DIRS}
    ${SDL3_IMAGE_INCLUDE_DIRS}
    ${OPENGL_INCLUDE_DIRS}
    ${LIBAVCODEC_INCLUDE_DIRS}
    ${LIBAVFORMAT_INCLUDE_DIRS}
    ${LIBAVUTIL_INCLUDE_DIRS}
    ${LIBSWSCALE_INCLUDE_DIRS}
)

# Link with ALL required libraries including Vulkan, SDL3_image, and FFmpeg - UPDATED
target_link_libraries(simplehttpserver 
    ${SDL3_LIBRARIES}
    ${SDL3_IMAGE_LIBRARIES}
    ${LIBAVCODEC_LIBRARIES}
    ${LIBAVFORMAT_LIBRARIES}
    ${LIBAVUTIL_LIBRARIES}
    ${LIBSWSCALE_LIBRARIES}
    ${LIBSWRESAMPLE_LIBRARIES}
    OpenGL::GL
    vulkan
)

# Add compiler definitions - UPDATED: Add FFmpeg definition
target_compile_definitions(simplehttpserver PRIVATE
    SDL_VIDEO_OPENGL=1
    GL_GLEXT_PROTOTYPES=1
    HAS_VULKAN=1
    $<$<BOOL:${LIBAVCODEC_FOUND}>:HAS_FFMPEG=1>
)