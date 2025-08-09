cmake_minimum_required(VERSION 3.10)
project(simplehttpserver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(APPLE)
    set(NATIVE_MACOS_BUILD TRUE)
else()
    set(NATIVE_MACOS_BUILD FALSE)
endif()

get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)

if(NOT SDL3_INSTALL_DIR)
    set(SDL3_INSTALL_DIR "${PROJECT_ROOT}/build/deps/install")
endif()
get_filename_component(SDL3_INSTALL_DIR "${SDL3_INSTALL_DIR}" ABSOLUTE)

list(PREPEND CMAKE_PREFIX_PATH "${SDL3_INSTALL_DIR}")
list(PREPEND CMAKE_INCLUDE_PATH "${SDL3_INSTALL_DIR}/include")
list(PREPEND CMAKE_LIBRARY_PATH "${SDL3_INSTALL_DIR}/lib")

set(ENV{PKG_CONFIG_PATH} "${SDL3_INSTALL_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

find_package(Boost REQUIRED COMPONENTS program_options)

if(NATIVE_MACOS_BUILD)
    find_package(PkgConfig QUIET)
    set(SDL3_FOUND FALSE)

    if(PkgConfig_FOUND)
        pkg_check_modules(SDL3_PKGCONFIG QUIET sdl3)
        if(SDL3_PKGCONFIG_FOUND)
            set(SDL3_INCLUDE_DIRS ${SDL3_PKGCONFIG_INCLUDE_DIRS})
            set(SDL3_LIBRARIES ${SDL3_PKGCONFIG_LIBRARIES})
            # Try to resolve a full library path so the linker can find it
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
        file(GLOB LIB_FILES RELATIVE "${SDL3_INSTALL_DIR}/lib" "${SDL3_INSTALL_DIR}/lib/*")
        foreach(LIB_FILE ${LIB_FILES})
            message(STATUS "  ${SDL3_INSTALL_DIR}/lib/${LIB_FILE}")
        endforeach()
        file(GLOB INCLUDE_DIRS RELATIVE "${SDL3_INSTALL_DIR}/include" "${SDL3_INSTALL_DIR}/include/*")
        foreach(INC ${INCLUDE_DIRS})
            message(STATUS "  ${SDL3_INSTALL_DIR}/include/${INC}")
        endforeach()
        message(FATAL_ERROR "SDL3 not found in ${SDL3_INSTALL_DIR}. Please ensure SDL3 was built/installed there.")
    endif()

    find_package(OpenGL REQUIRED)
    set(OPENGL_LIBRARIES ${OPENGL_LIBRARIES})
    set(OPENGL_INCLUDE_DIRS ${OPENGL_INCLUDE_DIR})

else()
    find_package(SDL3 REQUIRED CONFIG)
    find_library(OSMESA_LIBRARY NAMES OSMesa)
    find_path(OSMESA_INCLUDE_DIR NAMES GL/osmesa.h)
    if (NOT OSMESA_LIBRARY OR NOT OSMESA_INCLUDE_DIR)
        message(FATAL_ERROR "OSMesa not found in Docker environment.")
    endif()
    set(OPENGL_LIBRARIES ${OSMESA_LIBRARY})
    set(OPENGL_INCLUDE_DIRS ${OSMESA_INCLUDE_DIR})
endif()

add_executable(simplehttpserver
    ${PROJECT_ROOT}/main.cpp
    ${PROJECT_ROOT}/main.hpp 
)

# Associate header explicitly
target_sources(simplehttpserver PRIVATE
    ${PROJECT_ROOT}/main.hpp
)

# Ensure both main.cpp and main.hpp have proper includes
target_include_directories(simplehttpserver PRIVATE
    "${Boost_INCLUDE_DIRS}"
    "${SDL3_INCLUDE_DIRS}"
    "${OPENGL_INCLUDE_DIRS}"
)


if(NATIVE_MACOS_BUILD)
    if(SDL3_LIBRARY_DIRS)
        target_link_directories(simplehttpserver PRIVATE "${SDL3_LIBRARY_DIRS}")
    endif()

    target_link_libraries(simplehttpserver
        PRIVATE
            ${Boost_LIBRARIES}
            ${SDL3_LIBRARIES}
            ${OPENGL_LIBRARIES}
            "-framework Cocoa"
            "-framework CoreVideo"
            "-framework IOKit"
            "-framework CoreAudio"
            "-framework AudioToolbox"
            "-framework AVFoundation"
            "-framework Foundation"
    )

    target_include_directories(simplehttpserver PRIVATE
        "${Boost_INCLUDE_DIRS}"
        "${SDL3_INCLUDE_DIRS}"
        "${OPENGL_INCLUDE_DIRS}"
    )

    target_compile_definitions(simplehttpserver PRIVATE
        NATIVE_MACOS_BUILD=1
        SDL_VIDEO_DRIVER_COCOA=1
    )

    set_target_properties(simplehttpserver PROPERTIES
        INSTALL_RPATH "${SDL3_INSTALL_DIR}/lib"
        BUILD_WITH_INSTALL_RPATH TRUE
        MACOSX_RPATH TRUE
        BUILD_RPATH "${SDL3_INSTALL_DIR}/lib"
    )

else()
    target_link_libraries(simplehttpserver
        PRIVATE
            ${Boost_LIBRARIES}
            SDL3::SDL3-static
            ${OPENGL_LIBRARIES}
    )

    target_include_directories(simplehttpserver PRIVATE
        "${Boost_INCLUDE_DIRS}"
        "${OPENGL_INCLUDE_DIRS}"
    )

    target_compile_definitions(simplehttpserver PRIVATE
        DOCKER_BUILD=1
        SDL_VIDEO_DRIVER_X11=1
    )
endif()

add_custom_command(TARGET simplehttpserver POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${PROJECT_ROOT}/.vscode/compile_commands.json
)

install(TARGETS simplehttpserver
    RUNTIME DESTINATION ${PROJECT_ROOT}/bin
    LIBRARY DESTINATION ${PROJECT_ROOT}/lib
    ARCHIVE DESTINATION ${PROJECT_ROOT}/lib/static
)
