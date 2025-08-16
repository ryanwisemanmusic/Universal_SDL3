cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Detect build environment
if(APPLE)
    set(NATIVE_MACOS_BUILD TRUE)
    message(STATUS "Building for native macOS")
else()
    set(NATIVE_MACOS_BUILD FALSE)
    if(EXISTS "/etc/alpine-release")
        set(ALPINE_LINUX_BUILD TRUE)
        message(STATUS "Building for Alpine Linux")
    else()
        set(ALPINE_LINUX_BUILD FALSE)
        message(STATUS "Building for generic Linux")
    endif()
endif()

get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)

# SDL3 configuration
if(NOT SDL3_INSTALL_DIR)
    if(ALPINE_LINUX_BUILD)
        set(SDL3_INSTALL_DIR "/usr/local")
    else()
        set(SDL3_INSTALL_DIR "${PROJECT_ROOT}/build/deps/install")
    endif()
endif()
get_filename_component(SDL3_INSTALL_DIR "${SDL3_INSTALL_DIR}" ABSOLUTE)

list(PREPEND CMAKE_PREFIX_PATH "${SDL3_INSTALL_DIR}")
list(PREPEND CMAKE_INCLUDE_PATH "${SDL3_INSTALL_DIR}/include")
list(PREPEND CMAKE_LIBRARY_PATH "${SDL3_INSTALL_DIR}/lib")

set(ENV{PKG_CONFIG_PATH} "${SDL3_INSTALL_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

if(NATIVE_MACOS_BUILD)
    # macOS-specific SDL3 finding
    find_package(PkgConfig QUIET)
    set(SDL3_FOUND FALSE)

    if(PkgConfig_FOUND)
        pkg_check_modules(SDL3_PKGCONFIG QUIET sdl3)
        if(SDL3_PKGCONFIG_FOUND)
            set(SDL3_INCLUDE_DIRS ${SDL3_PKGCONFIG_INCLUDE_DIRS})
            set(SDL3_LIBRARIES ${SDL3_PKGCONFIG_LIBRARIES})
            find_library(SDL3_LIBRARY_PATH
                NAMES SDL3 libSDL3.dylib libSDL3.a
                PATHS "${SDL3_INSTALL_DIR}/lib" "${SDL3_INSTALL_DIR}/lib64"
                NO_DEFAULT_PATH
            )
            if(SDL3_LIBRARY_PATH)
                set(SDL3_LIBRARIES "${SDL3_LIBRARY_PATH}")
                set(SDL3_LIBRARY_DIRS "${SDL3_INSTALL_DIR}/lib")
            endif()
            set(SDL3_FOUND TRUE)
        endif()
    endif()

    if(NOT SDL3_FOUND)
        find_library(SDL3_LIBRARY_PATH
            NAMES SDL3 libSDL3.dylib libSDL3.a
            PATHS "${SDL3_INSTALL_DIR}/lib" "${SDL3_INSTALL_DIR}/lib64"
            NO_DEFAULT_PATH
        )

        find_path(SDL3_INCLUDE_PATH
            NAMES SDL3/SDL.h
            PATHS "${SDL3_INSTALL_DIR}/include"
            NO_DEFAULT_PATH
        )

        if(SDL3_LIBRARY_PATH AND SDL3_INCLUDE_PATH)
            set(SDL3_LIBRARIES "${SDL3_LIBRARY_PATH}")
            set(SDL3_INCLUDE_DIRS "${SDL3_INCLUDE_PATH}")
            set(SDL3_LIBRARY_DIRS "${SDL3_INSTALL_DIR}/lib")
            set(SDL3_FOUND TRUE)
        endif()
    endif()

    if(NOT SDL3_FOUND)
        message(FATAL_ERROR "SDL3 not found in ${SDL3_INSTALL_DIR}")
    endif()

    find_package(OpenGL REQUIRED)
    set(OPENGL_LIBRARIES ${OPENGL_LIBRARIES})
    set(OPENGL_INCLUDE_DIRS ${OPENGL_INCLUDE_DIR})

    # Vulkan on macOS
    find_path(VULKAN_INCLUDE_DIR vulkan/vulkan.h
        PATHS /usr/local/include /opt/homebrew/include
        NO_DEFAULT_PATH
    )
    find_library(VULKAN_LIBRARIES vulkan
        PATHS /usr/local/lib /opt/homebrew/lib
        NO_DEFAULT_PATH
    )
    if(NOT VULKAN_INCLUDE_DIR OR NOT VULKAN_LIBRARIES)
        message(FATAL_ERROR "Vulkan SDK not found on macOS")
    endif()

else()
    # Alpine/Linux configuration
    find_package(SDL3 REQUIRED CONFIG)
    
    # Use software rendering in Alpine
    # Use software rendering in Alpine
    if(ALPINE_LINUX_BUILD)
        # Look for custom-built Mesa first, then system packages
        find_library(MESA_LIBRARY NAMES mesa
            PATHS /usr/local/lib /usr/lib
        )
        find_library(LLVMPIPE_LIBRARY NAMES llvmpipe
            PATHS /usr/local/lib /usr/lib
        )
        find_library(OSMESA_LIBRARY NAMES OSMesa
            PATHS /usr/local/lib /usr/lib
        )
        
        if(MESA_LIBRARY AND LLVMPIPE_LIBRARY)
            set(OPENGL_LIBRARIES ${MESA_LIBRARY} ${LLVMPIPE_LIBRARY})
        elseif(OSMESA_LIBRARY)
            set(OPENGL_LIBRARIES ${OSMESA_LIBRARY})
        else()
            message(FATAL_ERROR "Could not find software rendering libraries (mesa/llvmpipe/OSMesa)")
        endif()
        
        find_path(OPENGL_INCLUDE_DIRS NAMES GL/gl.h
            PATHS /usr/local/include /usr/include
        )
    else()
        # Generic Linux with hardware acceleration
        find_package(OpenGL REQUIRED)
        set(OPENGL_LIBRARIES ${OpenGL_LIBRARIES})
        set(OPENGL_INCLUDE_DIRS ${OpenGL_INCLUDE_DIR})
    endif()

    # Vulkan on Linux
    # Vulkan on Linux
    if(ALPINE_LINUX_BUILD)
        # Custom built Vulkan (headers and loader from source)
        find_path(VULKAN_INCLUDE_DIR vulkan/vulkan.h
            PATHS /usr/local/include
            NO_DEFAULT_PATH
        )
        find_library(VULKAN_LIBRARIES vulkan
            PATHS /usr/local/lib
            NO_DEFAULT_PATH
        )
    else()
        # System Vulkan for generic Linux
        find_package(Vulkan QUIET)
        if(Vulkan_FOUND)
            set(VULKAN_INCLUDE_DIR ${Vulkan_INCLUDE_DIRS})
            set(VULKAN_LIBRARIES ${Vulkan_LIBRARIES})
        else()
            # Fallback manual search
            find_path(VULKAN_INCLUDE_DIR vulkan/vulkan.h
                PATHS /usr/local/include /usr/include
            )
            find_library(VULKAN_LIBRARIES vulkan
                PATHS /usr/local/lib /usr/lib
            )
        endif()
    endif()

    if(NOT VULKAN_INCLUDE_DIR OR NOT VULKAN_LIBRARIES)
        message(FATAL_ERROR "Vulkan SDK not found on Linux")
    endif()
endif()

# Additional support for all SDL3 external libraries
if(ALPINE_LINUX_BUILD)
    find_library(SDL3_IMAGE_LIBRARY NAMES SDL3_image
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_library(SDL3_MIXER_LIBRARY NAMES SDL3_mixer
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_library(SDL3_TTF_LIBRARY NAMES SDL3_ttf
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    
    find_path(SDL3_IMAGE_INCLUDE_DIR NAMES SDL3/SDL_image.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
    find_path(SDL3_MIXER_INCLUDE_DIR NAMES SDL3/SDL_mixer.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
    find_path(SDL3_TTF_INCLUDE_DIR NAMES SDL3/SDL_ttf.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
endif()

# SPIRV-Tools and Shaderc (built from source in Alpine)
# This should hopefuly clear up some of my warning flags, which
# have been a problem for the past week as this project has gotten HUGEEEEE
if(ALPINE_LINUX_BUILD)
    find_library(SPIRV_TOOLS_LIBRARY NAMES SPIRV-Tools
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_path(SPIRV_TOOLS_INCLUDE_DIR NAMES spirv-tools/libspirv.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
    
    find_library(SHADERC_LIBRARY NAMES shaderc_shared shaderc
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_path(SHADERC_INCLUDE_DIR NAMES shaderc/shaderc.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
endif()

# GBM stuff
if(ALPINE_LINUX_BUILD)
    find_library(GBM_LIBRARY NAMES gbm
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_path(GBM_INCLUDE_DIR NAMES gbm.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
endif()

# Mesa libraries (built from source in Alpine)
if(ALPINE_LINUX_BUILD)
    find_library(EGL_LIBRARY NAMES EGL
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_path(EGL_INCLUDE_DIR NAMES EGL/egl.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
endif()

# SQLite3 (built from source in Alpine)
if(ALPINE_LINUX_BUILD)
    find_library(SQLITE3_LIBRARY NAMES sqlite3
        PATHS /usr/local/lib
        NO_DEFAULT_PATH
    )
    find_path(SQLITE3_INCLUDE_DIR NAMES sqlite3.h
        PATHS /usr/local/include
        NO_DEFAULT_PATH
    )
endif()

# Main executable
add_executable(simplehttpserver
    ${PROJECT_ROOT}/main.cpp
    ${PROJECT_ROOT}/main.hpp 
)

target_sources(simplehttpserver PRIVATE
    ${PROJECT_ROOT}/main.hpp
)

set(EXTRA_INCLUDE_DIRS "")
if(ALPINE_LINUX_BUILD)
    if(SDL3_IMAGE_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SDL3_IMAGE_INCLUDE_DIR})
    endif()
    if(SDL3_MIXER_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SDL3_MIXER_INCLUDE_DIR})
    endif()
    if(SDL3_TTF_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SDL3_TTF_INCLUDE_DIR})
    endif()
    if(SPIRV_TOOLS_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SPIRV_TOOLS_INCLUDE_DIR})
    endif()
    if(SHADERC_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SHADERC_INCLUDE_DIR})
    endif()
    if(GBM_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${GBM_INCLUDE_DIR})
    endif()
    #EGL Directories were missing, and incomplete
    if(EGL_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${EGL_INCLUDE_DIR})
    endif()
    if(SQLITE3_INCLUDE_DIR)
        list(APPEND EXTRA_INCLUDE_DIRS ${SQLITE3_INCLUDE_DIR})
    endif()
    # Add custom built library paths
    list(APPEND EXTRA_INCLUDE_DIRS "/usr/local/include")
    list(APPEND EXTRA_INCLUDE_DIRS "/usr/local/include/xorg")
endif()


target_include_directories(simplehttpserver PRIVATE
    "${SDL3_INCLUDE_DIRS}"
    "${OPENGL_INCLUDE_DIRS}"
    "${VULKAN_INCLUDE_DIR}"
    ${EXTRA_INCLUDE_DIRS}
)

if(NATIVE_MACOS_BUILD)
    # macOS linking
    if(SDL3_LIBRARY_DIRS)
        target_link_directories(simplehttpserver PRIVATE "${SDL3_LIBRARY_DIRS}")
    endif()

    target_link_libraries(simplehttpserver
        PRIVATE
            ${SDL3_LIBRARIES}
            ${OPENGL_LIBRARIES}
            ${VULKAN_LIBRARIES}
            "-framework Cocoa"
            "-framework CoreVideo"
            "-framework IOKit"
            "-framework CoreAudio"
            "-framework AudioToolbox"
            "-framework AVFoundation"
            "-framework Foundation"
    )

    target_compile_definitions(simplehttpserver PRIVATE
        NATIVE_MACOS_BUILD=1
        SDL_VIDEO_DRIVER_COCOA=1
        USE_VULKAN=1
    )

    set_target_properties(simplehttpserver PROPERTIES
        INSTALL_RPATH "${SDL3_INSTALL_DIR}/lib"
        BUILD_WITH_INSTALL_RPATH TRUE
        MACOSX_RPATH TRUE
        BUILD_RPATH "${SDL3_INSTALL_DIR}/lib"
    )

else()
    # Alpine/Linux linking
    set(ALPINE_EXTRA_LIBS "")
    if(ALPINE_LINUX_BUILD)
        if(SDL3_IMAGE_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SDL3_IMAGE_LIBRARY})
        endif()
        if(SDL3_MIXER_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SDL3_MIXER_LIBRARY})
        endif()
        if(SDL3_TTF_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SDL3_TTF_LIBRARY})
        endif()
        if(SPIRV_TOOLS_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SPIRV_TOOLS_LIBRARY})
        endif()
        if(SHADERC_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SHADERC_LIBRARY})
        endif()
        if(GBM_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${GBM_LIBRARY})
        endif()
        if(EGL_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${EGL_LIBRARY})
        endif()
        if(OSMESA_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${OSMESA_LIBRARY})
        endif()
        if(SQLITE3_LIBRARY)
            list(APPEND ALPINE_EXTRA_LIBS ${SQLITE3_LIBRARY})
        endif()
    endif()

    target_link_libraries(simplehttpserver
        PRIVATE
            SDL3::SDL3-static
            ${OPENGL_LIBRARIES}
            ${VULKAN_LIBRARIES}
            ${ALPINE_EXTRA_LIBS}
    )

    if(ALPINE_LINUX_BUILD)
        target_compile_definitions(simplehttpserver PRIVATE
            ALPINE_LINUX_BUILD=1
            SDL_VIDEO_DRIVER_X11=1
            SDL_VIDEO_OPENGL=1
            GLX_ALWAYS_SOFTWARE=1
            USE_VULKAN=1
        )
        
        # Ensure software rendering is used
        set_target_properties(simplehttpserver PROPERTIES
            LINK_FLAGS "-Wl,--no-as-needed"
        )
    else()
        target_compile_definitions(simplehttpserver PRIVATE
            DOCKER_BUILD=1
            SDL_VIDEO_DRIVER_X11=1
            USE_VULKAN=1
        )
    endif()
endif()

# Generate compile_commands.json for tooling
add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${PROJECT_ROOT}/.vscode/compile_commands.json
)

# Installation
install(TARGETS simplehttpserver
    RUNTIME DESTINATION ${PROJECT_ROOT}/bin
    LIBRARY DESTINATION ${PROJECT_ROOT}/lib
    ARCHIVE DESTINATION ${PROJECT_ROOT}/lib/static
)
