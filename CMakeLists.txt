cmake_minimum_required(VERSION 3.16)
project(SDL3HelloWorld)

set(CMAKE_CXX_STANDARD 17)

find_package(PkgConfig REQUIRED)

# SDL3 libraries
pkg_check_modules(SDL3 REQUIRED sdl3)

pkg_check_modules(SDL3_TTF QUIET sdl3_ttf SDL3_ttf SDL_ttf)

if(NOT SDL3_TTF_FOUND)
    message(WARNING "SDL3_ttf not found via pkg-config, trying manual discovery...")
    
    find_library(SDL3_TTF_LIBRARY
        NAMES SDL3_ttf SDL_ttf
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib
        NO_DEFAULT_PATH
    )
    
    find_path(SDL3_TTF_INCLUDE_DIR
        NAMES SDL3_ttf/SDL_ttf.h SDL_ttf.h
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include
        NO_DEFAULT_PATH
    )
    
    if(SDL3_TTF_LIBRARY AND SDL3_TTF_INCLUDE_DIR)
        message(STATUS "Found SDL3_ttf manually: ${SDL3_TTF_LIBRARY}")
        set(SDL3_TTF_LIBRARIES ${SDL3_TTF_LIBRARY})
        set(SDL3_TTF_INCLUDE_DIRS ${SDL3_TTF_INCLUDE_DIR})
        set(SDL3_TTF_FOUND TRUE)
    else()
        message(FATAL_ERROR "SDL3_ttf not found! Check your installation.")
    endif()
endif()

pkg_check_modules(SDL3_IMAGE QUIET SDL3_image)

if(NOT SDL3_IMAGE_FOUND)
    message(WARNING "SDL3_image not found via pkg-config, trying manual discovery...")
    
    find_library(SDL3_IMAGE_LIBRARY
        NAMES SDL3_image
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib
        NO_DEFAULT_PATH
    )
    
    find_path(SDL3_IMAGE_INCLUDE_DIR
        NAMES SDL3_image/SDL_image.h
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include
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

# FFmpeg libraries
pkg_check_modules(LIBAVCODEC QUIET libavcodec)
pkg_check_modules(LIBAVFORMAT QUIET libavformat)
pkg_check_modules(LIBAVUTIL QUIET libavutil)
pkg_check_modules(LIBSWSCALE QUIET libswscale)
pkg_check_modules(LIBSWRESAMPLE QUIET libswresample)

if(NOT LIBAVCODEC_FOUND OR NOT LIBAVFORMAT_FOUND OR NOT LIBAVUTIL_FOUND)
    message(WARNING "FFmpeg not found via pkg-config, trying manual discovery...")
    
    # Search in standard paths AND your custom lilyspark paths
    find_library(LIBAVCODEC_LIB NAMES avcodec 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBAVFORMAT_LIB NAMES avformat 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBAVUTIL_LIB NAMES avutil 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBSWSCALE_LIB NAMES swscale 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    find_library(LIBSWRESAMPLE_LIB NAMES swresample 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib NO_DEFAULT_PATH)
    
    find_path(LIBAVCODEC_INCLUDE_DIR libavcodec/avcodec.h 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBAVFORMAT_INCLUDE_DIR libavformat/avformat.h 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBAVUTIL_INCLUDE_DIR libavutil/avutil.h 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include NO_DEFAULT_PATH)
    find_path(LIBSWSCALE_INCLUDE_DIR libswscale/swscale.h 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/include /usr/local/include /usr/include NO_DEFAULT_PATH)
    
    if(LIBAVCODEC_LIB AND LIBAVCODEC_INCLUDE_DIR)
        set(LIBAVCODEC_LIBRARIES ${LIBAVCODEC_LIB})
        set(LIBAVCODEC_INCLUDE_DIRS ${LIBAVCODEC_INCLUDE_DIR})
        set(LIBAVCODEC_FOUND TRUE)
        message(STATUS "Found libavcodec manually: ${LIBAVCODEC_LIB}")
    endif()
    
    if(LIBAVFORMAT_LIB AND LIBAVFORMAT_INCLUDE_DIR)
        set(LIBAVFORMAT_LIBRARIES ${LIBAVFORMAT_LIB})
        set(LIBAVFORMAT_INCLUDE_DIRS ${LIBAVFORMAT_INCLUDE_DIR})
        set(LIBAVFORMAT_FOUND TRUE)
        message(STATUS "Found libavformat manually: ${LIBAVFORMAT_LIB}")
    endif()
    
    if(LIBAVUTIL_LIB AND LIBAVUTIL_INCLUDE_DIR)
        set(LIBAVUTIL_LIBRARIES ${LIBAVUTIL_LIB})
        set(LIBAVUTIL_INCLUDE_DIRS ${LIBAVUTIL_INCLUDE_DIR})
        set(LIBAVUTIL_FOUND TRUE)
        message(STATUS "Found libavutil manually: ${LIBAVUTIL_LIB}")
    endif()
    
    if(LIBSWSCALE_LIB AND LIBSWSCALE_INCLUDE_DIR)
        set(LIBSWSCALE_LIBRARIES ${LIBSWSCALE_LIB})
        set(LIBSWSCALE_INCLUDE_DIRS ${LIBSWSCALE_INCLUDE_DIR})
        set(LIBSWSCALE_FOUND TRUE)
        message(STATUS "Found libswscale manually: ${LIBSWSCALE_LIB}")
    endif()
    
    if(LIBSWRESAMPLE_LIB)
        set(LIBSWRESAMPLE_LIBRARIES ${LIBSWRESAMPLE_LIB})
        set(LIBSWRESAMPLE_FOUND TRUE)
        message(STATUS "Found libswresample manually: ${LIBSWRESAMPLE_LIB}")
    endif()
endif()

if(NOT LIBAVCODEC_FOUND OR NOT LIBAVFORMAT_FOUND OR NOT LIBAVUTIL_FOUND)
    message(WARNING "Essential FFmpeg components not found. Video playback may not work.")
else()
    message(STATUS "FFmpeg support enabled")
    add_definitions(-DHAS_FFMPEG=1)
endif()

# OpenGL
find_package(OpenGL REQUIRED)

# SQLite3 library
pkg_check_modules(SQLITE3 QUIET sqlite3)
if(NOT SQLITE3_FOUND)
    message(WARNING "SQLite3 not found via pkg-config, trying manual discovery...")
    find_library(SQLITE3_LIB NAMES sqlite3 
        PATHS /lilyspark/usr/local/lib/graphics/sdl3/lib /usr/local/lib /usr/lib)
    if(SQLITE3_LIB)
        set(SQLITE3_LIBRARIES ${SQLITE3_LIB})
        set(SQLITE3_FOUND TRUE)
        message(STATUS "Found SQLite3 manually: ${SQLITE3_LIB}")
    else()
        message(WARNING "SQLite3 not found! Database functionality will not work.")
    endif()
endif()

find_library(OPENMPT_LIB NAMES openmpt PATHS /usr/lib /usr/local/lib)
if(OPENMPT_LIB)
    message(WARNING "libopenmpt found: ${OPENMPT_LIB}, so the why tf are you causing a problem with MY FUCKING SOUND")
else()
    message(STATUS "libopenmpt not found, later, I want to tackle this because mp3 encoding is something I don't want to leave out")
endif()

add_executable(lilyspark-alpha 
    main.cpp 
)

pkg_check_modules(python3 QUIET python3)
if(NOT python3_FOUND)
    message(WARNING "Python3 not found via pkg-config, trying manual discovery...")
    find_library(PYTHON3_LIB NAMES python3 PATHS /usr/lib /usr/local/lib)
    if(PYTHON3_LIB)
        set(PYTHON3_LIBRARIES ${PYTHON3_LIB})
        set(PYTHON3_FOUND TRUE)
        message(STATUS "Found Python3 manually: ${PYTHON3_LIB}")
    else()
        message(WARNING "Python3 not found! Some features may not work.")
    endif()
endif()


target_include_directories(lilyspark-alpha PRIVATE 
    ${SDL3_INCLUDE_DIRS}
    ${SDL3_TTF_INCLUDE_DIRS}
    ${SDL3_IMAGE_INCLUDE_DIRS}
    ${OPENGL_INCLUDE_DIRS}
    ${LIBAVCODEC_INCLUDE_DIRS}
    ${LIBAVFORMAT_INCLUDE_DIRS}
    ${LIBAVUTIL_INCLUDE_DIRS}
    ${LIBSWSCALE_INCLUDE_DIRS}
    ${LIBSWRESAMPLE_INCLUDE_DIRS}
    ${SQLITE3_INCLUDE_DIRS}
    ${PYTHON3_INCLUDE_DIRS}
)

# Alright, check back here if you aren't finding shit; because chances are, it's here
target_link_directories(lilyspark-alpha PRIVATE
    /usr/lib
    /usr/local/lib
    /lilyspark/usr/local/lib/graphics/sdl3/lib
    /lilyspark/usr/local/lib/video/codec/lib
    /lilyspark/usr/local/lib/video/ffmpeg/lib
    /lilyspark/usr/local/lib/video/formats/lib
    /lilyspark/usr/local/lib/video/hardware/lib
    /lilyspark/usr/local/lib/audio/codec/lib
    /lilyspark/usr/local/lib/audio/formats/lib
    /lilyspark/usr/local/lib/python/lib
)

target_link_libraries(lilyspark-alpha 
    ${SDL3_LIBRARIES}
    ${SDL3_TTF_LIBRARIES}
    ${SDL3_IMAGE_LIBRARIES}
    
    ${LIBAVCODEC_LIBRARIES}
    ${LIBAVFORMAT_LIBRARIES}
    ${LIBAVUTIL_LIBRARIES}
    ${LIBSWSCALE_LIBRARIES}
    ${LIBSWRESAMPLE_LIBRARIES}
    
    ${SQLITE3_LIBRARIES}
    ${PYTHON3_LIBRARIES}
    OpenGL::GL
    vulkan
    
    dl
    pthread
    m
)

# Compile Definitions
target_compile_definitions(lilyspark-alpha PRIVATE
    SDL_VIDEO_OPENGL=1
    GL_GLEXT_PROTOTYPES=1
    HAS_VULKAN=1
    $<$<BOOL:${LIBAVCODEC_FOUND}>:HAS_FFMPEG=1>
)

# FINAL CHECK!!!!!
message(STATUS "=== BUILD CONFIGURATION ===")
message(STATUS "SDL3: ${SDL3_LIBRARIES}")
message(STATUS "SDL3_ttf: ${SDL3_TTF_LIBRARIES}")
message(STATUS "SDL3_image: ${SDL3_IMAGE_LIBRARIES}")
message(STATUS "FFmpeg: ${LIBAVCODEC_LIBRARIES}")
message(STATUS "SQLite3: ${SQLITE3_LIBRARIES}")
#message(STATUS "Using clean linking without mpg123 dependencies")
message(STATUS "Python3: ${PYTHON3_LIBRARIES}")
message(STATUS "Pandas: Available as Python package")